package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Architecture 6.4 against real PostgreSQL: the retention purge deletes only rows
 * that can no longer change an outcome, and only once they have been dead longer
 * than the retention (7 days by default). Ageing is done by moving timestamps back
 * in SQL; the purge is global, so assertions name this test's rows only.
 */
class AuthRetentionIT extends SessionTestSupport {

    private static final String LONG_AGO = "now() - interval '8 days'";

    @Autowired
    AuthRetention retention;

    private int tokenRows(Object sessionId) {
        return jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE session_id = ?", Integer.class, sessionId);
    }

    private int sessionRows(Object sessionId) {
        return jdbc.queryForObject("SELECT count(*) FROM auth_sessions WHERE id = ?", Integer.class, sessionId);
    }

    private boolean tokenExists(String token) {
        return jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE token_hash = ?", Integer.class,
                (Object) AuthSessions.sha256(token)) == 1;
    }

    /** Logs in, rotates twice; returns the three refresh tokens oldest first. */
    private String[] rotatedTwice() {
        String first = newSession().string("refreshToken");
        Response second = refresh(first);
        assertThat(second.status()).isEqualTo(200);
        Response third = refresh(second.string("refreshToken"));
        assertThat(third.status()).isEqualTo(200);
        return new String[] {first, second.string("refreshToken"), third.string("refreshToken")};
    }

    @Test
    void aLiveSessionAndItsRecentTokensAreKept() {
        String[] tokens = rotatedTwice();
        Object sessionId = sessionOf(tokens[2]).get("id");

        retention.purge();

        assertThat(sessionRows(sessionId)).isEqualTo(1);
        assertThat(tokenRows(sessionId)).isEqualTo(3);
        assertThat(refresh(tokens[2]).status()).isEqualTo(200);
    }

    /**
     * The claim the purge rests on: an expired token is rejected without any replay
     * action whether or not its row still exists, so deleting it changes nothing.
     */
    @Test
    void longExpiredTokensGoAndTheirReplayStillLeavesTheSessionAlive() {
        String[] tokens = rotatedTwice();
        Object sessionId = sessionOf(tokens[2]).get("id");
        jdbc.update("UPDATE refresh_tokens SET expires_at = " + LONG_AGO + " WHERE token_hash IN (?, ?)",
                AuthSessions.sha256(tokens[0]), AuthSessions.sha256(tokens[1]));

        AuthRetention.Result result = retention.purge();

        assertThat(result.tokens()).isGreaterThanOrEqualTo(2);
        assertThat(tokenExists(tokens[0])).isFalse();
        assertThat(tokenExists(tokens[1])).isFalse();
        assertThat(sessionRows(sessionId)).isEqualTo(1);

        assertThat(refresh(tokens[0]).status()).isEqualTo(401);
        assertThat(jdbc.queryForMap("SELECT revoked_at FROM auth_sessions WHERE id = ?", sessionId))
                .containsEntry("revoked_at", null);
        assertThat(refresh(tokens[2]).status()).isEqualTo(200);
    }

    @Test
    void aSessionRevokedLongAgoGoesWithItsTokensButARecentOneStays() {
        String old = newSession().string("refreshToken");
        String recent = newSession().string("refreshToken");
        Object oldSession = sessionOf(old).get("id");
        Object recentSession = sessionOf(recent).get("id");
        jdbc.update("UPDATE auth_sessions SET revoked_at = " + LONG_AGO + ", revoked_reason = 'logout' WHERE id = ?",
                oldSession);
        jdbc.update("UPDATE auth_sessions SET revoked_at = now(), revoked_reason = 'logout' WHERE id = ?",
                recentSession);

        retention.purge();

        assertThat(sessionRows(oldSession)).isZero();
        assertThat(tokenRows(oldSession)).isZero();
        assertThat(sessionRows(recentSession)).isEqualTo(1);
        assertThat(refresh(old).status()).isEqualTo(401);
        assertThat(refresh(recent).status()).isEqualTo(401);
    }

    @Test
    void aSessionPastItsAbsoluteExpiryLongAgoGoes() {
        String token = newSession().string("refreshToken");
        Object sessionId = sessionOf(token).get("id");
        jdbc.update("UPDATE auth_sessions SET created_at = now() - interval '100 days', absolute_expires_at = "
                + LONG_AGO + " WHERE id = ?", sessionId);

        retention.purge();

        assertThat(sessionRows(sessionId)).isZero();
        assertThat(tokenRows(sessionId)).isZero();
    }

    /** D06 inactivity: no token valid within the retention means the session can never refresh again. */
    @Test
    void anInactiveSessionGoesOnceItsLastTokenIsLongExpired() {
        String token = newSession().string("refreshToken");
        Object sessionId = sessionOf(token).get("id");
        jdbc.update("UPDATE auth_sessions SET created_at = now() - interval '40 days' WHERE id = ?", sessionId);
        jdbc.update("UPDATE refresh_tokens SET expires_at = " + LONG_AGO + " WHERE session_id = ?", sessionId);

        retention.purge();

        assertThat(sessionRows(sessionId)).isZero();
        assertThat(refresh(token).status()).isEqualTo(401);
    }

    @Test
    void theAccountItselfIsNeverTouched() {
        Response login = newSession();
        String token = login.string("refreshToken");
        Map<String, Object> session = sessionOf(token);
        UUID userId = (UUID) session.get("user_id");
        jdbc.update("UPDATE auth_sessions SET revoked_at = " + LONG_AGO + ", revoked_reason = 'logout' WHERE id = ?",
                session.get("id"));

        retention.purge();

        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE id = ?", Integer.class, userId)).isEqualTo(1);
    }
}
