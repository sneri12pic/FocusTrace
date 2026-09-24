package com.stepandemianenko.focustrace.sync.auth;

import com.stepandemianenko.focustrace.sync.auth.AuthRateLimiter.Bucket;
import com.stepandemianenko.focustrace.sync.common.ApiException;
import java.util.Optional;
import java.util.UUID;
import org.hibernate.exception.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/**
 * Registration, login, refresh and logout. Rate limiting is applied here, where
 * both the source and the canonical account identifier are known (D15).
 *
 * <p>Deliberately not {@code @Transactional}: the user insert must fail and roll
 * back on its own so the unique-constraint violation can be translated (D11), and
 * the session work is transactional inside {@link AuthSessions}.
 */
@Service
public class AuthService {

    private static final Logger securityLog = LoggerFactory.getLogger("focustrace.security");
    private static final String EMAIL_UNIQUE_CONSTRAINT = "users_email_key";

    private final UserRepository users;
    private final PasswordProcessor passwords;
    private final AuthSessions sessions;
    private final AccessTokens accessTokens;
    private final AuthRateLimiter rateLimiter;

    AuthService(UserRepository users, PasswordProcessor passwords, AuthSessions sessions,
            AccessTokens accessTokens, AuthRateLimiter rateLimiter) {
        this.users = users;
        this.passwords = passwords;
        this.sessions = sessions;
        this.accessTokens = accessTokens;
        this.rateLimiter = rateLimiter;
    }

    public record Tokens(String accessToken, long expiresIn, String refreshToken) {
        @Override
        public String toString() {
            return "Tokens[accessToken=<redacted>, expiresIn=" + expiresIn + ", refreshToken=<redacted>]";
        }
    }

    /**
     * D11: a duplicate discloses with 409. The unique index is the authority; there
     * is no pre-insert existence check to lose a race.
     */
    public UUID register(String rawEmail, String password, String source) {
        rateLimiter.acquire(Bucket.REGISTER_PER_SOURCE, source);
        // Already validated at the REST boundary; re-checked because identity depends on it.
        String email = EmailAddresses.canonicalize(rawEmail)
                .orElseThrow(() -> ApiException.invalidField("email", "must be a valid email address"));
        if (passwords.isTooCommon(password, email)) {
            throw ApiException.invalidField("password", "is too common; choose a different password");
        }
        try {
            UUID userId = users.saveAndFlush(new User(email, passwords.hash(password))).getId();
            securityLog.info("event=account_registered userId={}", userId);
            return userId;
        } catch (DataIntegrityViolationException e) {
            if (!violates(e, EMAIL_UNIQUE_CONSTRAINT)) {
                throw e;
            }
            securityLog.info("event=registration_rejected reason=duplicate_email");
            throw ApiException.conflict("An account with this email address already exists.");
        }
    }

    /**
     * D11: unknown account, wrong password and an identifier that is not a valid
     * address all end in the same 401, and all cost one Argon2id verification.
     */
    public Tokens login(String rawEmail, String password, String source) {
        rateLimiter.acquire(Bucket.LOGIN_PER_SOURCE, source);
        Optional<String> email = EmailAddresses.canonicalize(rawEmail);
        // Keyed on the canonical identifier whether or not an account exists, so the
        // 429 behaves identically for both.
        email.ifPresent(e -> rateLimiter.acquire(Bucket.LOGIN_PER_ACCOUNT, e));

        Optional<User> user = email.flatMap(users::findByEmail);
        if (user.isEmpty()) {
            passwords.matchDummy(password);
            securityLog.info("event=login_failed reason=unknown_account");
            throw ApiException.unauthorized();
        }
        if (!passwords.matches(password, user.get().getPasswordHash())) {
            securityLog.info("event=login_failed reason=wrong_password userId={}", user.get().getId());
            throw ApiException.unauthorized();
        }
        return tokensFor(sessions.start(user.get().getId()));
    }

    /** D08. Every rejection is the same generic 401; the log records which kind it was. */
    public Tokens refresh(String refreshToken, String source) {
        rateLimiter.acquire(Bucket.REFRESH_PER_SOURCE, source);
        return sessions.rotate(refreshToken)
                .map(this::tokensFor)
                .orElseThrow(ApiException::unauthorized);
    }

    /**
     * D19: deletes the caller's account and everything it owns, after re-verifying
     * the current password. The Argon2id verification runs before any lock is taken;
     * the deletion itself is one statement. A wrong password is a 403, not a 401: the
     * bearer token is valid, and a 401 would make a client refresh and resend.
     */
    public void deleteAccount(UUID userId, String password) {
        User user = users.findById(userId).orElseThrow(ApiException::unauthorized);
        if (!passwords.matches(password, user.getPasswordHash())) {
            securityLog.info("event=account_delete_rejected reason=wrong_password userId={}", userId);
            throw ApiException.forbidden("Password confirmation failed.");
        }
        if (!sessions.deleteAccount(userId)) {
            // Deleted concurrently by another request of this account.
            throw ApiException.unauthorized();
        }
        securityLog.info("event=account_deleted userId={}", userId);
    }

    /** D10: revokes the caller's session named by the token; always succeeds. */
    public void logout(String refreshToken, UUID userId) {
        sessions.logout(refreshToken, userId);
    }

    private Tokens tokensFor(AuthSessions.Issued issued) {
        return new Tokens(accessTokens.issue(issued.userId()), accessTokens.lifetimeSeconds(), issued.refreshToken());
    }

    private static boolean violates(Throwable e, String constraint) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof ConstraintViolationException cve && constraint.equals(cve.getConstraintName())) {
                return true;
            }
        }
        return false;
    }
}
