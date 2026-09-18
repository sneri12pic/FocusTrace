package com.stepandemianenko.focustrace.sync;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpHeaders;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.json.JsonMapper;

/**
 * Base for integration tests: a real server on a random port, real HTTP, and one
 * PostgreSQL container shared by the whole suite (architecture section 12).
 *
 * <p>The container is started once and never stopped by JUnit, so cached Spring
 * contexts keep pointing at a live database. Tests use unique emails instead of
 * cleaning tables.
 *
 * <p>Rate limits are effectively off here; {@code RateLimitIT} tests them with low
 * values in its own context. The JWT secret is generated per JVM run, so no
 * secret-looking value is committed.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
            "focustrace.auth.rate-limit.register-per-source.capacity=1000000",
            "focustrace.auth.rate-limit.login-per-source.capacity=1000000",
            "focustrace.auth.rate-limit.login-per-account.capacity=1000000",
            "focustrace.auth.rate-limit.refresh-per-source.capacity=1000000"
        })
public abstract class IntegrationTest {

    @ServiceConnection
    public static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16-alpine");

    static {
        POSTGRES.start();
    }

    /** 64 bytes so tests can also sign HS512 with the same secret (algorithm pinning). */
    public static final byte[] TEST_SECRET_BYTES = randomBytes(64);
    public static final String TEST_SECRET = Base64.getEncoder().encodeToString(TEST_SECRET_BYTES);

    /** Not on the blocklist, 26 code points. */
    public static final String STRONG_PASSWORD = "Violet-Quarry-Lantern-8214";

    protected static final JsonMapper JSON = JsonMapper.builder().build();
    private static final HttpClient HTTP = HttpClient.newHttpClient();

    @DynamicPropertySource
    static void jwtSecret(DynamicPropertyRegistry registry) {
        registry.add("focustrace.auth.jwt.secret", () -> TEST_SECRET);
    }

    @LocalServerPort
    protected int port;

    @Autowired
    protected JdbcTemplate jdbc;

    public static byte[] randomBytes(int length) {
        byte[] bytes = new byte[length];
        new SecureRandom().nextBytes(bytes);
        return bytes;
    }

    protected static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }

    // --- HTTP ---------------------------------------------------------------

    public record Response(int status, String body, HttpHeaders headers) {

        @SuppressWarnings("unchecked")
        public Map<String, Object> json() {
            return JSON.readValue(body, Map.class);
        }

        public String string(String field) {
            return (String) json().get(field);
        }

        public String header(String name) {
            return headers.firstValue(name).orElse(null);
        }
    }

    protected Response post(String path, Object body) {
        return post(path, body, null);
    }

    protected Response post(String path, Object body, String bearer) {
        return postJson(path, JSON.writeValueAsString(body), bearer, Map.of());
    }

    protected Response postJson(String path, String json, String bearer, Map<String, String> headers) {
        HttpRequest.Builder request = request(path, bearer, headers)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json));
        return send(request.build());
    }

    protected Response get(String path, String bearer) {
        return send(request(path, bearer, Map.of()).GET().build());
    }

    private HttpRequest.Builder request(String path, String bearer, Map<String, String> headers) {
        HttpRequest.Builder request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path));
        if (bearer != null) {
            request.header("Authorization", "Bearer " + bearer);
        }
        headers.forEach(request::header);
        return request;
    }

    private static Response send(HttpRequest request) {
        try {
            HttpResponse<String> response = HTTP.send(request, HttpResponse.BodyHandlers.ofString());
            return new Response(response.statusCode(), response.body(), response.headers());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
    }

    // --- auth flows -----------------------------------------------------------

    protected Response register(String email, String password) {
        return post("/api/v1/auth/register", Map.of("email", email, "password", password));
    }

    protected Response login(String email, String password) {
        return post("/api/v1/auth/login", Map.of("email", email, "password", password));
    }

    protected Response refresh(String refreshToken) {
        return post("/api/v1/auth/refresh", Map.of("refreshToken", refreshToken));
    }

    /** Registers and logs in a fresh account; returns the login response (asserted 200). */
    protected Response newSession() {
        String email = uniqueEmail();
        assertThat(register(email, STRONG_PASSWORD).status()).isEqualTo(201);
        return loggedIn(email, STRONG_PASSWORD);
    }

    protected Response loggedIn(String email, String password) {
        Response response = login(email, password);
        assertThat(response.status()).as(response.body()).isEqualTo(200);
        return response;
    }
}
