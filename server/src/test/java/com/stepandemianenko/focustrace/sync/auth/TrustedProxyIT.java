package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.test.context.TestPropertySource;

/**
 * D20 trusted-proxy mode through the real Tomcat pipeline. This test process is the
 * proxy: its loopback address is the one trusted peer, and it adds the header a
 * proxy appending the client's address would send. Login allows two attempts per
 * source here; every test uses its own documentation-range client addresses.
 */
@TestPropertySource(properties = {
    "focustrace.network.mode=trusted-proxy",
    "focustrace.network.trusted-proxies=127.0.0.1,::1",
    "focustrace.auth.rate-limit.login-per-source.capacity=2"
})
@ExtendWith(OutputCaptureExtension.class)
class TrustedProxyIT extends IntegrationTest {

    private Response loginVia(Map<String, String> headers) {
        return postJson("/api/v1/auth/login",
                JSON.writeValueAsString(Map.of("email", uniqueEmail(), "password", "Wrong-Password-x-xyz")),
                null, headers);
    }

    private Response loginFrom(String forwardedFor) {
        return loginVia(Map.of("X-Forwarded-For", forwardedFor));
    }

    @Test
    void clientsBehindTheProxyHaveTheirOwnSourceBuckets() {
        assertThat(loginFrom("198.51.100.1").status()).isEqualTo(401);
        assertThat(loginFrom("198.51.100.1").status()).isEqualTo(401);
        assertThat(loginFrom("198.51.100.1").status()).isEqualTo(429);

        // Same proxy, another client: not the proxy's shared bucket.
        assertThat(loginFrom("198.51.100.2").status()).isEqualTo(401);
    }

    /**
     * The proxy appends the address it saw, so the rightmost entry is the client and
     * anything to its left is whatever the client sent. Varying that part does not
     * change the key, and a forged address is not charged.
     */
    @Test
    void prependedEntriesCannotChooseTheKey() {
        assertThat(loginFrom("203.0.113.9, 198.51.100.3").status()).isEqualTo(401);
        assertThat(loginFrom("203.0.113.10, 198.51.100.3").status()).isEqualTo(401);
        assertThat(loginFrom("192.0.2.77, 203.0.113.11, 198.51.100.3").status()).isEqualTo(429);

        assertThat(loginFrom("203.0.113.9").status()).as("forged entries were never charged").isEqualTo(401);
    }

    /** A trusted-proxy hop in the chain is skipped; the first address that is not a proxy is the client. */
    @Test
    void aTrustedHopInTheChainIsSkipped() {
        assertThat(loginFrom("198.51.100.6, 127.0.0.1").status()).isEqualTo(401);
        assertThat(loginFrom("198.51.100.6").status()).isEqualTo(401);
        assertThat(loginFrom("198.51.100.6, 127.0.0.1").status()).isEqualTo(429);
    }

    @Test
    void otherForwardingHeadersAreNeverRead() {
        for (int i = 1; i <= 3; i++) {
            Map<String, String> headers = new LinkedHashMap<>();
            headers.put("X-Forwarded-For", "198.51.100.4");
            headers.put("Forwarded", "for=192.0.2." + i);
            headers.put("X-Real-IP", "192.0.2." + (10 + i));
            assertThat(loginVia(headers).status()).isEqualTo(i < 3 ? 401 : 429);
        }
    }

    /** The security event names the same resolved address the limiter keyed on, and nothing else. */
    @Test
    void theRateLimitedEventNamesTheResolvedClient(CapturedOutput output) {
        loginFrom("203.0.113.66, 198.51.100.5");
        loginFrom("198.51.100.5");

        Response limited = loginFrom("203.0.113.67, 198.51.100.5");

        assertThat(limited.status()).isEqualTo(429);
        assertThat(output.getAll()).contains("event=rate_limited bucket=LOGIN_PER_SOURCE source=198.51.100.5");
        assertThat(output.getAll()).doesNotContain("203.0.113.66").doesNotContain("203.0.113.67");
        assertThat(limited.body()).doesNotContain("198.51.100.5").doesNotContain("LOGIN_PER_SOURCE");
    }

    /**
     * A proxy that sends no X-Forwarded-For is misconfigured: its requests all share
     * the proxy's own bucket. Documented, not hidden.
     */
    @Test
    void withoutTheHeaderTheProxyItselfIsTheSource() {
        assertThat(loginVia(Map.of()).status()).isEqualTo(401);
        assertThat(loginVia(Map.of()).status()).isEqualTo(401);
        assertThat(loginVia(Map.of()).status()).isEqualTo(429);
    }

    @Test
    void aMalformedForwardedValueGetsTheOrdinaryGenericResponse() {
        Response response = loginFrom("not-an-address, <script>");

        assertThat(response.status()).isEqualTo(401);
        assertThat(response.body()).doesNotContain("not-an-address").doesNotContain("script")
                .doesNotContain("Exception");
    }
}
