package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * Baseline section 18 "Refresh token"; plan criteria 4, 16, 16d; D05, D06, D08.
 * Default configuration: reuse grace 10 s. {@code StrictRotationIT} covers grace 0.
 */
class RefreshTokenIT extends SessionTestSupport {

    @Test
    void refreshRotatesAndReturnsANewPair() {
        Response login = newSession();
        String first = login.string("refreshToken");

        Response rotated = refresh(first);

        assertThat(rotated.status()).isEqualTo(200);
        assertThat(rotated.json()).containsOnlyKeys("accessToken", "expiresIn", "refreshToken");
        assertThat(rotated.string("refreshToken")).isNotEqualTo(first);
        assertThat(rotated.string("accessToken")).isNotEqualTo(login.string("accessToken"));
        assertThat(get("/api/v1/test/whoami", rotated.string("accessToken")).status()).isEqualTo(200);
    }

    @Test
    void predecessorIsUnusableAfterRotationAndSuccessorKeepsWorking() {
        String first = newSession().string("refreshToken");
        String second = refresh(first).string("refreshToken");

        assertThat(refresh(first).status()).isEqualTo(401);
        // Within grace, successor unused: a duplicate, not theft - the successor survives.
        Response third = refresh(second);
        assertThat(third.status()).isEqualTo(200);
        assertThat(sessionOf(third.string("refreshToken")).get("revoked_reason")).isNull();
    }

    @Test
    void storedValueIsSha256AndNeverThePlaintext() throws Exception {
        String token = newSession().string("refreshToken");
        String rotated = refresh(token).string("refreshToken");

        for (String plaintext : List.of(token, rotated)) {
            byte[] raw = plaintext.getBytes(StandardCharsets.UTF_8);
            assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE token_hash = ?", Integer.class, raw))
                    .isZero();
            assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE position(? in token_hash) > 0",
                    Integer.class, raw)).isZero();
            assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE token_hash = ?", Integer.class,
                    java.security.MessageDigest.getInstance("SHA-256").digest(raw))).isOne();
        }
        assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE length(token_hash) <> 32", Integer.class))
                .isZero();
    }

    @Test
    void rotationLeavesExactlyOneCurrentTokenPerSession() {
        String token = newSession().string("refreshToken");
        for (int i = 0; i < 5; i++) {
            token = refresh(token).string("refreshToken");
        }
        UUID session = (UUID) sessionOf(token).get("id");

        assertThat(jdbc.queryForObject(
                "SELECT count(*) FROM refresh_tokens WHERE session_id = ? AND revoked_at IS NULL", Integer.class, session))
                .isOne();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE session_id = ?", Integer.class, session))
                .isEqualTo(6);
    }

    /** Replay once the successor has been used: theft. Kills that session and only that session. */
    @Test
    void replayAfterSuccessorUseRevokesOnlyThatSession() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);
        String stolen = loggedIn(email, STRONG_PASSWORD).string("refreshToken");
        String otherInstallation = loggedIn(email, STRONG_PASSWORD).string("refreshToken");

        String successor = refresh(stolen).string("refreshToken");
        String latest = refresh(successor).string("refreshToken");

        assertThat(refresh(stolen).status()).isEqualTo(401);
        assertThat(sessionOf(latest).get("revoked_reason")).isEqualTo("token_reuse");
        assertThat(refresh(latest).status()).isEqualTo(401);
        assertThat(liveTokens(latest)).isZero();

        assertThat(refresh(otherInstallation).status()).isEqualTo(200);
    }

    /** Replay after the grace window, even with the successor unused: theft. */
    @Test
    void replayOutsideGraceRevokesTheSession() {
        String first = newSession().string("refreshToken");
        String second = refresh(first).string("refreshToken");
        // Simulate the passage of time beyond the 10 s grace.
        jdbc.update("UPDATE refresh_tokens SET revoked_at = revoked_at - interval '1 minute' WHERE token_hash = ?",
                (Object) AuthSessions.sha256(first));

        assertThat(refresh(first).status()).isEqualTo(401);

        assertThat(sessionOf(second).get("revoked_reason")).isEqualTo("token_reuse");
        assertThat(refresh(second).status()).isEqualTo(401);
    }

    @Test
    void unknownAndRevokedTokensGetTheSameGeneric401() {
        String first = newSession().string("refreshToken");
        refresh(first);

        Response unknown = refresh("definitely-not-a-token");
        Response replayed = refresh(first);

        assertThat(unknown.status()).isEqualTo(401);
        assertThat(replayed.body()).isEqualTo(unknown.body());
    }

    @Test
    void expiredTokenFailsWithoutRevokingTheSession() {
        String token = newSession().string("refreshToken");
        jdbc.update("UPDATE refresh_tokens SET expires_at = now() - interval '1 second' WHERE token_hash = ?",
                (Object) AuthSessions.sha256(token));

        assertThat(refresh(token).status()).isEqualTo(401);
        assertThat(sessionOf(token).get("revoked_at")).isNull();
    }

    /** D06: a token's expiry is issuance + 30 days, capped by the session's absolute expiry. */
    @Test
    void tokenExpiryIsTheInactivityWindow() {
        String token = newSession().string("refreshToken");

        Map<String, Object> row = jdbc.queryForMap(
                "SELECT extract(epoch FROM t.expires_at - t.issued_at)::bigint AS lifetime, "
                        + "extract(epoch FROM s.absolute_expires_at - s.created_at)::bigint AS absolute "
                        + "FROM refresh_tokens t JOIN auth_sessions s ON s.id = t.session_id WHERE t.token_hash = ?",
                (Object) AuthSessions.sha256(token));

        assertThat(row.get("lifetime")).isEqualTo(30L * 24 * 3600);
        assertThat(row.get("absolute")).isEqualTo(90L * 24 * 3600);
    }

    /** Inactivity: a token not used within its window fails (expires_at passed). */
    @Test
    void refreshAfterInactivityWindowFails() {
        String token = newSession().string("refreshToken");
        jdbc.update("UPDATE refresh_tokens SET issued_at = issued_at - interval '31 days', "
                        + "expires_at = expires_at - interval '31 days' WHERE token_hash = ?",
                (Object) AuthSessions.sha256(token));

        assertThat(refresh(token).status()).isEqualTo(401);
    }

    /** D05: rotation never extends a session; past its absolute expiry it fails even under continuous use. */
    @Test
    void absoluteExpiryCapsRotationAndThenEndsTheSession() {
        String token = newSession().string("refreshToken");
        UUID session = (UUID) sessionOf(token).get("id");
        jdbc.update("UPDATE auth_sessions SET absolute_expires_at = now() + interval '1 hour' WHERE id = ?", session);

        String rotated = refresh(token).string("refreshToken");
        Boolean capped = jdbc.queryForObject(
                "SELECT t.expires_at = s.absolute_expires_at FROM refresh_tokens t "
                        + "JOIN auth_sessions s ON s.id = t.session_id WHERE t.token_hash = ?",
                Boolean.class, (Object) AuthSessions.sha256(rotated));
        assertThat(capped).isTrue();

        jdbc.update("UPDATE auth_sessions SET absolute_expires_at = now() - interval '1 second' WHERE id = ?", session);
        assertThat(refresh(rotated).status()).isEqualTo(401);
        assertThat(sessionOf(rotated).get("revoked_at")).isNull();
    }

    /**
     * Plan criterion 16d, D08 required concurrency test: two threads, one token, real
     * PostgreSQL. Repeated so the requests genuinely contend on the row lock.
     */
    @Test
    void concurrentRefreshWithOneTokenRotatesExactlyOnceAndSparesTheSuccessor() {
        int overlapped = 0;
        for (int round = 0; round < 15; round++) {
            String token = newSession().string("refreshToken");
            UUID session = (UUID) sessionOf(token).get("id");

            Race race = raceRefresh(token);
            List<Response> results = race.results();
            overlapped += race.overlapped() ? 1 : 0;

            assertThat(results).extracting(Response::status).as("round %d", round).containsExactlyInAnyOrder(200, 401);
            String winner = results.stream().filter(r -> r.status() == 200).findFirst().orElseThrow().string("refreshToken");

            assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE session_id = ?", Integer.class, session))
                    .isEqualTo(2);
            assertThat(jdbc.queryForObject(
                    "SELECT count(*) FROM refresh_tokens WHERE session_id = ? AND revoked_at IS NULL AND token_hash = ?",
                    Integer.class, session, AuthSessions.sha256(winner))).isOne();
            assertThat(sessionOf(winner).get("revoked_at")).isNull();

            // The within-grace loser did not invalidate the successor.
            assertThat(refresh(winner).status()).isEqualTo(200);
        }
        // Not a sequential approximation: the requests were genuinely in flight together.
        assertThat(overlapped).as("rounds where both requests overlapped").isPositive();
    }
}
