package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;

/**
 * Plan criterion 15, baseline section 15/18 "Information leakage": drives every auth
 * flow, including the failure and replay paths, then checks that no credential
 * appears in any response it does not belong in, or anywhere in the log output.
 */
@ExtendWith(OutputCaptureExtension.class)
class CredentialLeakageIT extends IntegrationTest {

    @Test
    void noCredentialReachesLogsOrUnintendedResponses(CapturedOutput output) {
        String email = uniqueEmail();
        String password = "Leak-Canary-Password-" + System.nanoTime();
        List<Response> responses = new ArrayList<>();
        List<String> credentials = new ArrayList<>(List.of(password, TEST_SECRET));

        Response registered = register(email, password);
        responses.add(registered);
        responses.add(register(email, password));                     // 409 duplicate
        responses.add(register(uniqueEmail(), "short" + password.substring(0, 5))); // 400
        responses.add(login(email, password + "-wrong"));              // 401
        responses.add(login(uniqueEmail(), password));                 // 401 unknown

        Response login = login(email, password);
        Response rotated = refresh(login.string("refreshToken"));
        Response second = refresh(rotated.string("refreshToken"));
        responses.add(refresh(login.string("refreshToken")));          // replay -> session revoked
        Response other = login(email, password);
        responses.add(post("/api/v1/auth/logout", Map.of("refreshToken", other.string("refreshToken")),
                other.string("accessToken")));
        responses.add(get("/api/v1/test/whoami", login.string("accessToken") + "tampered"));
        responses.add(get("/api/v1/test/boom", other.string("accessToken")));

        for (Response tokens : List.of(login, rotated, second, other)) {
            credentials.add(tokens.string("accessToken"));
            credentials.add(tokens.string("refreshToken"));
        }
        String storedHash = jdbc.queryForObject("SELECT password_hash FROM users WHERE email = ?", String.class, email);
        credentials.add(storedHash);
        credentials.add(storedHash.substring(storedHash.lastIndexOf('$') + 1)); // raw hash segment

        // Responses: credentials appear only where they are the payload.
        assertThat(registered.json()).containsOnlyKeys("userId");
        for (Response r : List.of(login, rotated, second, other)) {
            assertThat(r.json()).containsOnlyKeys("accessToken", "expiresIn", "refreshToken");
        }
        for (Response r : responses) {
            for (String credential : credentials) {
                assertThat(r.body()).doesNotContain(credential);
            }
            assertThat(r.body()).doesNotContain("argon2", "token_hash", "password_hash", "Exception", "at com.");
        }

        // Logs: the events happened (so this is not vacuous) and carried no credential.
        String log = output.getAll();
        assertThat(log).contains("event=login_failed", "event=refresh_token_reuse_detected",
                "event=session_revoked reason=logout", "event=access_token_rejected", "Unhandled exception, correlationId=");
        for (String credential : credentials) {
            assertThat(log).doesNotContain(credential);
        }
        assertThat(log).doesNotContain("Bearer ey", "Using generated security password", email);
    }
}
