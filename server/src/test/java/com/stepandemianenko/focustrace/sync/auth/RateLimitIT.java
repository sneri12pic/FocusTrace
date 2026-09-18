package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.TestPropertySource;

/**
 * Plan criterion 16b; D15. Every test gets a fresh context so its buckets start
 * full: all requests here share one source, the loopback socket peer.
 */
@TestPropertySource(properties = {
    "focustrace.auth.rate-limit.register-per-source.capacity=2",
    "focustrace.auth.rate-limit.login-per-source.capacity=10",
    "focustrace.auth.rate-limit.login-per-account.capacity=3",
    "focustrace.auth.rate-limit.refresh-per-source.capacity=2"
})
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_EACH_TEST_METHOD)
class RateLimitIT extends IntegrationTest {

    @Test
    void registrationPastTheSourceLimitIs429WithRetryAfter() {
        assertThat(register(uniqueEmail(), STRONG_PASSWORD).status()).isEqualTo(201);
        assertThat(register(uniqueEmail(), STRONG_PASSWORD).status()).isEqualTo(201);

        Response limited = register(uniqueEmail(), STRONG_PASSWORD);

        assertThat(limited.status()).isEqualTo(429);
        assertThat(Long.parseLong(limited.header("Retry-After"))).isPositive();
        assertThat(limited.header("Content-Type")).startsWith("application/problem+json");
        assertThat(limited.json()).containsEntry("status", 429);
    }

    @Test
    void exhaustedAccountDoesNotLockOutAnotherAccountFromTheSameSource() {
        String victim = uniqueEmail();
        for (int i = 0; i < 3; i++) {
            assertThat(login(victim, "Wrong-Password-" + i + "-xyz").status()).isEqualTo(401);
        }
        assertThat(login(victim, "Wrong-Password-4-xyz").status()).isEqualTo(429);
        // Also covers canonical spellings: they are one account bucket.
        assertThat(login(" " + victim.toUpperCase(), "Wrong-Password-5-xyz").status()).isEqualTo(429);

        assertThat(login(uniqueEmail(), "Wrong-Password-x-xyz").status()).isEqualTo(401);
    }

    @Test
    void sourceLimitTripsIndependentlyOfAccounts() {
        for (int i = 0; i < 10; i++) {
            assertThat(login(uniqueEmail(), "Wrong-Password-x-xyz").status()).isEqualTo(401);
        }

        assertThat(login(uniqueEmail(), "Wrong-Password-x-xyz").status()).isEqualTo(429);
    }

    /** The 429 must not reveal the dimension or whether the account exists. */
    @Test
    void limitedResponseIsIdenticalForExistingAndUnknownAccounts() {
        // Registration budget is separate from login budget.
        String existing = uniqueEmail();
        assertThat(register(existing, STRONG_PASSWORD).status()).isEqualTo(201);
        String unknown = uniqueEmail();

        Response existingLimited = exhaustLogin(existing);
        Response unknownLimited = exhaustLogin(unknown);

        assertThat(existingLimited.status()).isEqualTo(429);
        assertThat(unknownLimited.status()).isEqualTo(429);
        assertThat(existingLimited.body()).isEqualTo(unknownLimited.body());
        assertThat(existingLimited.body()).doesNotContain("account", "source", "email", "ACCOUNT", "SOURCE", existing);
    }

    @Test
    void forwardedHeadersDoNotChangeTheSourceBucket() {
        assertThat(refreshFrom("203.0.113.1").status()).isEqualTo(401);
        assertThat(refreshFrom("203.0.113.2").status()).isEqualTo(401);

        Response limited = refreshFrom("203.0.113.3");

        assertThat(limited.status()).isEqualTo(429);
    }

    /**
     * The source key is the peer IP only: each request below uses a fresh TCP
     * connection (so a different ephemeral client port) plus different spoofed
     * forwarding headers, and all three still share one bucket.
     */
    @Test
    void freshConnectionsFromTheSameIpShareOneSourceBucket() throws Exception {
        java.util.Set<Integer> clientPorts = new java.util.HashSet<>();
        List<Integer> statuses = new java.util.ArrayList<>();
        for (int i = 1; i <= 3; i++) {
            try (java.net.Socket socket = new java.net.Socket("127.0.0.1", port)) {
                clientPorts.add(socket.getLocalPort());
                String body = "{\"refreshToken\":\"unknown\"}";
                String request = "POST /api/v1/auth/refresh HTTP/1.1\r\n"
                        + "Host: localhost\r\nContent-Type: application/json\r\nConnection: close\r\n"
                        + "X-Forwarded-For: 198.51.100." + i + "\r\nForwarded: for=198.51.100." + i + "\r\n"
                        + "Content-Length: " + body.length() + "\r\n\r\n" + body;
                socket.getOutputStream().write(request.getBytes(java.nio.charset.StandardCharsets.US_ASCII));
                String statusLine = new java.io.BufferedReader(new java.io.InputStreamReader(
                        socket.getInputStream(), java.nio.charset.StandardCharsets.US_ASCII)).readLine();
                statuses.add(Integer.parseInt(statusLine.split(" ")[1]));
            }
        }

        assertThat(clientPorts).hasSize(3);
        assertThat(statuses).containsExactly(401, 401, 429);
    }

    @Test
    void refreshPastTheSourceLimitIs429EvenForAValidToken() {
        String token = newSessionUnderLimits();
        token = refresh(token).string("refreshToken");
        refresh("unknown-token");

        assertThat(refresh(token).status()).isEqualTo(429);
    }

    private Response exhaustLogin(String email) {
        for (int i = 0; i < 3; i++) {
            login(email, "Wrong-Password-" + i + "-xyz");
        }
        return login(email, "Wrong-Password-9-xyz");
    }

    private Response refreshFrom(String spoofedAddress) {
        return postJson("/api/v1/auth/refresh", JSON.writeValueAsString(Map.of("refreshToken", "unknown")), null,
                Map.of("X-Forwarded-For", spoofedAddress, "Forwarded", "for=" + spoofedAddress, "X-Real-IP", spoofedAddress));
    }

    private String newSessionUnderLimits() {
        String email = uniqueEmail();
        assertThat(register(email, STRONG_PASSWORD).status()).isEqualTo(201);
        return loggedIn(email, STRONG_PASSWORD).string("refreshToken");
    }
}
