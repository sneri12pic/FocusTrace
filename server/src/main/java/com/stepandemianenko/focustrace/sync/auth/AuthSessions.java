package com.stepandemianenko.focustrace.sync.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Login sessions and their refresh tokens (D05, D06, D08, D10).
 *
 * <p>Refresh tokens are 256 random bits from {@link SecureRandom}, handed to the
 * client once and stored only as SHA-256 of the token string. All timestamps are
 * database time, so expiry is decided in one clock.
 *
 * <p>Control flow never relies on an exception: rotation returns an outcome, so
 * a detected replay's session revocation commits even though the caller answers 401.
 */
@Component
public class AuthSessions {

    private static final Logger securityLog = LoggerFactory.getLogger("focustrace.security");
    private static final SecureRandom RANDOM = new SecureRandom();

    private final JdbcClient jdbc;
    private final AuthProperties.Session config;

    AuthSessions(JdbcClient jdbc, AuthProperties properties) {
        this.jdbc = jdbc;
        this.config = properties.session();
    }

    /** A plaintext refresh token plus the identity it belongs to. The plaintext exists only to be returned. */
    public record Issued(UUID userId, UUID sessionId, String refreshToken) {
        @Override
        public String toString() {
            return "Issued[userId=" + userId + ", sessionId=" + sessionId + ", refreshToken=<redacted>]";
        }
    }

    /** Opens a session for a freshly authenticated user and issues its first refresh token. */
    @Transactional
    public Issued start(UUID userId) {
        UUID sessionId = UUID.randomUUID();
        jdbc.sql("""
                        INSERT INTO auth_sessions (id, user_id, absolute_expires_at)
                        VALUES (:id, :userId, now() + :absoluteMs * interval '1 millisecond')
                        """)
                .param("id", sessionId)
                .param("userId", userId)
                .param("absoluteMs", config.absoluteLifetime().toMillis())
                .update();
        Issued issued = new Issued(userId, sessionId, issueToken(sessionId));
        securityLog.info("event=session_started userId={} sessionId={}", userId, sessionId);
        return issued;
    }

    /**
     * D08 rotation. The presented token is claimed by one conditional UPDATE whose
     * affected-row count is the decision: of two concurrent callers exactly one sees
     * a row, because the loser blocks on the row lock and re-evaluates
     * {@code revoked_at IS NULL} against the winner's committed version. Only after a
     * successful claim is the successor inserted, in the same transaction.
     */
    @Transactional
    public Optional<Issued> rotate(String presentedToken) {
        byte[] hash = sha256(presentedToken);
        Optional<Claimed> claimed = jdbc.sql("""
                        UPDATE refresh_tokens t
                           SET revoked_at = now()
                          FROM auth_sessions s
                         WHERE t.token_hash = :hash
                           AND t.revoked_at IS NULL
                           AND t.expires_at > now()
                           AND s.id = t.session_id
                           AND s.revoked_at IS NULL
                           AND s.absolute_expires_at > now()
                        RETURNING t.session_id, t.user_id
                        """)
                .param("hash", hash)
                .query((rs, n) -> new Claimed(rs.getObject("session_id", UUID.class), rs.getObject("user_id", UUID.class)))
                .optional();
        if (claimed.isPresent()) {
            Claimed c = claimed.get();
            securityLog.info("event=refresh_rotated userId={} sessionId={}", c.userId(), c.sessionId());
            return Optional.of(new Issued(c.userId(), c.sessionId(), issueToken(c.sessionId())));
        }
        handleRejected(hash);
        return Optional.empty();
    }

    /**
     * D10 logout: revokes the session the token belongs to, only if that session is
     * the caller's. Unknown, foreign and already-revoked tokens are silently ignored,
     * so the endpoint is idempotent and is not an oracle.
     */
    @Transactional
    public void logout(String presentedToken, UUID userId) {
        jdbc.sql("SELECT session_id FROM refresh_tokens WHERE token_hash = :hash AND user_id = :userId")
                .param("hash", sha256(presentedToken))
                .param("userId", userId)
                .query(UUID.class)
                .optional()
                .ifPresent(sessionId -> {
                    if (revokeSession(sessionId, "logout")) {
                        securityLog.info("event=session_revoked reason=logout userId={} sessionId={}", userId, sessionId);
                    }
                });
    }

    /** Classifies a token that could not be claimed, and applies the D08 replay rule. */
    private void handleRejected(byte[] hash) {
        // clock_timestamp(), not now(): the grace comparison must use real time, not
        // this transaction's start, which can precede the winner's revocation.
        Optional<Presented> presented = jdbc.sql("""
                        SELECT t.session_id,
                               t.user_id,
                               t.revoked_at IS NOT NULL                                   AS consumed,
                               t.expires_at <= now()                                      AS token_expired,
                               s.revoked_at IS NOT NULL OR s.absolute_expires_at <= now() AS session_ended,
                               t.revoked_at > clock_timestamp() - :graceMs * interval '1 millisecond'
                                                                                          AS within_grace,
                               NOT EXISTS (SELECT 1 FROM refresh_tokens n
                                            WHERE n.session_id = t.session_id
                                              AND n.revoked_at > t.revoked_at)            AS successor_unused
                          FROM refresh_tokens t
                          JOIN auth_sessions s ON s.id = t.session_id
                         WHERE t.token_hash = :hash
                        """)
                .param("hash", hash)
                .param("graceMs", config.reuseGrace().toMillis())
                .query((rs, n) -> new Presented(
                        rs.getObject("session_id", UUID.class),
                        rs.getObject("user_id", UUID.class),
                        rs.getBoolean("consumed"),
                        rs.getBoolean("token_expired"),
                        rs.getBoolean("session_ended"),
                        rs.getBoolean("within_grace"),
                        rs.getBoolean("successor_unused")))
                .optional();

        if (presented.isEmpty()) {
            securityLog.warn("event=refresh_rejected reason=unknown_token");
            return;
        }
        Presented p = presented.get();
        if (p.sessionEnded() || p.tokenExpired() || !p.consumed()) {
            securityLog.info("event=refresh_rejected reason={} userId={} sessionId={}",
                    p.sessionEnded() ? "session_ended" : p.tokenExpired() ? "token_expired" : "not_current",
                    p.userId(), p.sessionId());
            return;
        }
        if (p.withinGrace() && p.successorUnused()) {
            // Two requests racing from one client: one 401, no revocation (D08).
            securityLog.info("event=refresh_rejected reason=duplicate_within_grace userId={} sessionId={}",
                    p.userId(), p.sessionId());
            return;
        }
        if (revokeSession(p.sessionId(), "token_reuse")) {
            securityLog.warn("event=refresh_token_reuse_detected action=session_revoked userId={} sessionId={}",
                    p.userId(), p.sessionId());
        }
    }

    /** Revokes the session and every live token in it. False when it was already revoked. */
    private boolean revokeSession(UUID sessionId, String reason) {
        int sessions = jdbc.sql("""
                        UPDATE auth_sessions SET revoked_at = now(), revoked_reason = :reason
                         WHERE id = :id AND revoked_at IS NULL
                        """)
                .param("reason", reason)
                .param("id", sessionId)
                .update();
        jdbc.sql("UPDATE refresh_tokens SET revoked_at = now() WHERE session_id = :id AND revoked_at IS NULL")
                .param("id", sessionId)
                .update();
        return sessions == 1;
    }

    /**
     * Inserts the session's new current token. Its user is taken from the session row,
     * and it expires at the earlier of the inactivity window and the session's
     * absolute expiry (D05/D06), so rotation can never extend a session.
     */
    private String issueToken(UUID sessionId) {
        byte[] random = new byte[32];
        RANDOM.nextBytes(random);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        int inserted = jdbc.sql("""
                        INSERT INTO refresh_tokens (id, user_id, session_id, token_hash, expires_at)
                        SELECT :id, s.user_id, s.id, :hash,
                               LEAST(now() + :inactivityMs * interval '1 millisecond', s.absolute_expires_at)
                          FROM auth_sessions s
                         WHERE s.id = :sessionId
                        """)
                .param("id", UUID.randomUUID())
                .param("hash", sha256(token))
                .param("inactivityMs", config.inactivityLifetime().toMillis())
                .param("sessionId", sessionId)
                .update();
        if (inserted != 1) {
            throw new IllegalStateException("Session " + sessionId + " vanished while issuing a refresh token");
        }
        return token;
    }

    static byte[] sha256(String token) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private record Claimed(UUID sessionId, UUID userId) {
    }

    private record Presented(
            UUID sessionId,
            UUID userId,
            boolean consumed,
            boolean tokenExpired,
            boolean sessionEnded,
            boolean withinGrace,
            boolean successorUnused) {
    }
}
