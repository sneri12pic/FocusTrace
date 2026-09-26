package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.test.context.TestPropertySource;

/**
 * D20: trusted-proxy mode is on, but this test process connects from loopback,
 * which is not the configured proxy. It is an internet client that reached the
 * application port directly, and its forwarding headers must change nothing.
 */
@TestPropertySource(properties = {
    "focustrace.network.mode=trusted-proxy",
    "focustrace.network.trusted-proxies=192.0.2.10",
    "focustrace.auth.rate-limit.login-per-source.capacity=2"
})
@ExtendWith(OutputCaptureExtension.class)
class UntrustedPeerIT extends IntegrationTest {

    @Test
    void anUntrustedPeerIsKeyedByItsSocketAddressWhateverItClaims(CapturedOutput output) {
        String[] claimed = {"198.51.100.1", "198.51.100.2", "203.0.113.5, 198.51.100.3"};
        int[] statuses = new int[claimed.length];
        for (int i = 0; i < claimed.length; i++) {
            statuses[i] = postJson("/api/v1/auth/login",
                    JSON.writeValueAsString(Map.of("email", uniqueEmail(), "password", "Wrong-Password-x-xyz")),
                    null, Map.of("X-Forwarded-For", claimed[i], "Forwarded", "for=192.0.2.10")).status();
        }

        assertThat(statuses).containsExactly(401, 401, 429);
        assertThat(output.getAll()).containsPattern("event=rate_limited bucket=LOGIN_PER_SOURCE source=(127\\.0\\.0\\.1|0:0:0:0:0:0:0:1)");
        assertThat(output.getAll()).doesNotContain("source=198.51.100");
    }
}
