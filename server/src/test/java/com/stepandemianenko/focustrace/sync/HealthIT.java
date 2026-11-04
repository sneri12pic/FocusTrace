package com.stepandemianenko.focustrace.sync;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.http.HttpRequest;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Architecture 9.6: one public probe that reports status and nothing else. */
class HealthIT extends IntegrationTest {

    private static final String HEALTH = "/api/v1/health";

    @Test
    void healthIsPublicAndReportsStatusOnly() {
        Response response = get(HEALTH, null);

        assertThat(response.status()).as(response.body()).isEqualTo(200);
        assertThat(response.json()).isEqualTo(Map.of("status", "UP"));
    }

    /** Public endpoints never read the Authorization header, so a stale token cannot fail the probe. */
    @Test
    void aBadBearerTokenDoesNotMatter() {
        assertThat(get(HEALTH, "not-a-jwt").status()).isEqualTo(200);
    }

    @Test
    void noOtherActuatorSurfaceIsReachable() {
        for (String path : new String[] {"/api/v1/health/db", "/api/v1/health/diskSpace", "/api/v1/info",
                "/api/v1/env", "/api/v1/metrics", "/api/v1", "/actuator", "/actuator/health"}) {
            Response response = get(path, null);
            assertThat(response.status()).as(path).isIn(401, 404);
            assertThat(response.body()).as(path).doesNotContain("\"UP\"");
        }
        Response post = send(request(HEALTH, null, Map.of()).POST(HttpRequest.BodyPublishers.noBody()).build());
        assertThat(post.status()).isIn(401, 405);
    }
}
