package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Baseline section 18 "Login"; D02 (NFC, spaces), D07 (claim set), D11 (non-disclosure). */
class LoginIT extends IntegrationTest {

    @Test
    void correctCredentialsReturnUsableTokens() {
        String email = uniqueEmail();
        String userId = register(email, STRONG_PASSWORD).string("userId");

        Response login = loggedIn(email, STRONG_PASSWORD);

        assertThat(login.json()).containsOnlyKeys("accessToken", "expiresIn", "refreshToken");
        assertThat(login.json().get("expiresIn")).isEqualTo(900);
        assertThat(get("/api/v1/test/whoami", login.string("accessToken")).string("sub")).isEqualTo(userId);
    }

    @Test
    void accessTokenCarriesExactlyTheDocumentedClaims() {
        String email = uniqueEmail();
        String userId = register(email, STRONG_PASSWORD).string("userId");
        String[] parts = loggedIn(email, STRONG_PASSWORD).string("accessToken").split("\\.");

        Map<String, Object> header = readMap(parts[0]);
        Map<String, Object> claims = readMap(parts[1]);

        // D09: no kid (it would be a thumbprint of the HMAC secret).
        assertThat(header).containsOnlyKeys("alg").containsEntry("alg", "HS256");
        assertThat(claims).containsOnlyKeys("iss", "aud", "sub", "iat", "exp", "jti");
        assertThat(claims.get("iss")).isEqualTo("focustrace-sync");
        // A single audience serialises as a string (RFC 7519 section 4.1.3 allows either form).
        assertThat(claims.get("aud")).isEqualTo("focustrace-app");
        assertThat(claims.get("sub")).isEqualTo(userId);
        assertThat(((Number) claims.get("exp")).longValue() - ((Number) claims.get("iat")).longValue()).isEqualTo(900);
        assertThat(new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8)).doesNotContain(email);
    }

    @Test
    void unknownAccountAndWrongPasswordAreIndistinguishable() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);

        Response wrongPassword = login(email, STRONG_PASSWORD + "!");
        Response unknownAccount = login(uniqueEmail(), STRONG_PASSWORD);
        Response invalidIdentifier = login("\t" + email, STRONG_PASSWORD);

        for (Response response : List.of(wrongPassword, unknownAccount, invalidIdentifier)) {
            assertThat(response.status()).isEqualTo(401);
            assertThat(response.body()).isEqualTo(wrongPassword.body());
            assertThat(response.header("Content-Type")).isEqualTo(wrongPassword.header("Content-Type"));
            assertThat(response.header("WWW-Authenticate")).isEqualTo("Bearer");
        }
        assertThat(wrongPassword.body()).doesNotContain(email, "password", "exist");
    }

    @Test
    void malformedLoginIsSafe4xx() {
        for (String body : List.of("{", "{\"email\":\"a@example.com\"}", "{\"password\":\"x\"}", "[]")) {
            Response response = postJson("/api/v1/auth/login", body, null, Map.of());
            assertThat(response.status()).as(body).isEqualTo(400);
            assertThat(response.body()).doesNotContain("Exception", "at com.", "at org.");
        }
        // Scalars are coerced to strings, so this parses as a login attempt: D11's generic 401.
        assertThat(postJson("/api/v1/auth/login", "{\"email\":1,\"password\":2}", null, Map.of()).status())
                .isEqualTo(401);
    }

    @Test
    void precomposedAndDecomposedFormsAuthenticateTheSameAccount() {
        String precomposed = "Café-Crème-Brûlée-Olé";
        String decomposed = "Café-Crème-Brûlée-Olé";
        assertThat(precomposed).isNotEqualTo(decomposed);

        String registeredPrecomposed = uniqueEmail();
        register(registeredPrecomposed, precomposed);
        assertThat(login(registeredPrecomposed, decomposed).status()).isEqualTo(200);
        assertThat(login(registeredPrecomposed, precomposed).status()).isEqualTo(200);

        String registeredDecomposed = uniqueEmail();
        register(registeredDecomposed, decomposed);
        assertThat(login(registeredDecomposed, precomposed).status()).isEqualTo(200);
    }

    @Test
    void leadingAndTrailingSpacesAreSignificant() {
        String email = uniqueEmail();
        String spaced = "  " + STRONG_PASSWORD + " ";
        assertThat(register(email, spaced).status()).isEqualTo(201);

        assertThat(login(email, STRONG_PASSWORD).status()).isEqualTo(401);
        assertThat(login(email, spaced.strip() + " ").status()).isEqualTo(401);
        assertThat(login(email, spaced).status()).isEqualTo(200);
    }

    @Test
    void passwordIsCaseSensitive() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);

        assertThat(login(email, STRONG_PASSWORD.toLowerCase()).status()).isEqualTo(401);
    }

    @Test
    void publicEndpointsIgnoreAnAttachedBearerToken() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);

        Response response = postJson("/api/v1/auth/login",
                JSON.writeValueAsString(Map.of("email", email, "password", STRONG_PASSWORD)),
                "expired.or.garbage", Map.of());

        assertThat(response.status()).isEqualTo(200);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> readMap(String base64Url) {
        return JSON.readValue(Base64.getUrlDecoder().decode(base64Url), Map.class);
    }

    /** Review finding: a lone surrogate (JSON "\\ud800") reached Argon2 and produced a 500. */
    @Test
    void loneSurrogatePasswordIsTheGeneric401NotA500() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);
        Response wrongPassword = login(email, STRONG_PASSWORD + "!");

        for (String account : List.of(email, uniqueEmail())) {
            Response response = postJson("/api/v1/auth/login",
                    "{\"email\":\"" + account + "\",\"password\":\"aaaaaaaaaaaaaaa\\ud800\"}", null, Map.of());
            assertThat(response.status()).isEqualTo(401);
            assertThat(response.body()).isEqualTo(wrongPassword.body());
        }
    }

    /**
     * D17 is an admission check ("checked at registration"); login never re-runs it.
     * A blocklisted password on an unknown account is just a failed login: same 401.
     */
    @Test
    void blocklistedPasswordOnUnknownAccountIsTheGeneric401() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);
        Response wrongPassword = login(email, STRONG_PASSWORD + "!");

        Response blocklisted = login(uniqueEmail(), "PasswordPassword");

        assertThat(blocklisted.status()).isEqualTo(401);
        assertThat(blocklisted.body()).isEqualTo(wrongPassword.body());
        assertThat(blocklisted.header("WWW-Authenticate")).isEqualTo(wrongPassword.header("WWW-Authenticate"));
    }

    /**
     * D17 (enforcement scope): updating the blocklist has no retroactive effect. An
     * account whose password was admitted and later appears in a newer bundled list
     * still authenticates normally.
     */
    @Test
    void existingAccountWhosePasswordLaterJoinedTheBlocklistStillLogsIn() {
        String email = uniqueEmail();
        String password = "PasswordPassword"; // on the v1 list
        jdbc.update("INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)", java.util.UUID.randomUUID(), email,
                PasswordProcessor.createEncoder().encode(PasswordProcessor.normalize(password)));

        assertThat(login(email, password).status()).isEqualTo(200);
    }
}
