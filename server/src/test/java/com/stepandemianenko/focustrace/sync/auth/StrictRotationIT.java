package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/**
 * D08 with the reuse grace set to zero: strict RFC 9700 rotation. Any presentation
 * of a consumed token - including the loser of a concurrent race - revokes the
 * session. That is the documented behaviour of this configuration, not a regression.
 */
@TestPropertySource(properties = "focustrace.auth.session.reuse-grace=PT0S")
class StrictRotationIT extends SessionTestSupport {

    @Test
    void concurrentRefreshRotatesOnceThenRevokesTheSession() {
        int overlapped = 0;
        for (int round = 0; round < 10; round++) {
            String token = newSession().string("refreshToken");

            Race race = raceRefresh(token);
            List<Response> results = race.results();
            overlapped += race.overlapped() ? 1 : 0;

            assertThat(results).extracting(Response::status).as("round %d", round).containsExactlyInAnyOrder(200, 401);
            String winner = results.stream().filter(r -> r.status() == 200).findFirst().orElseThrow().string("refreshToken");

            assertThat(sessionOf(winner).get("revoked_reason")).isEqualTo("token_reuse");
            assertThat(liveTokens(winner)).isZero();
            assertThat(refresh(winner).status()).isEqualTo(401);
        }
        assertThat(overlapped).as("rounds where both requests overlapped").isPositive();
    }

    @Test
    void immediateSequentialReplayRevokesTheSession() {
        String first = newSession().string("refreshToken");
        String second = refresh(first).string("refreshToken");

        assertThat(refresh(first).status()).isEqualTo(401);

        assertThat(sessionOf(second).get("revoked_reason")).isEqualTo("token_reuse");
        assertThat(refresh(second).status()).isEqualTo(401);
    }
}
