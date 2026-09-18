package com.stepandemianenko.focustrace.sync;

import java.util.Map;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Test-only protected endpoints, picked up by component scanning of the test
 * classpath. Step 2 has no protected business endpoint yet (devices are Step 3),
 * so these stand in to prove the authentication boundary. Not shipped.
 */
@RestController
public class TestEndpoints {

    public static final String INTERNAL_DETAIL = "internal-detail-7f3c-must-not-leak";

    @GetMapping("/api/v1/test/whoami")
    Map<String, String> whoami(@AuthenticationPrincipal Jwt principal) {
        return Map.of("sub", principal.getSubject());
    }

    @GetMapping("/api/v1/test/boom")
    Map<String, String> boom() {
        throw new IllegalStateException(INTERNAL_DETAIL);
    }
}
