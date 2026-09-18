package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/** Baseline section 18 "Registration"; D01, D02, D03, D11, D17. */
class RegistrationIT extends IntegrationTest {

    @Test
    void registrationCreatesExactlyOneAccountAndReturnsOnlyItsId() {
        String email = uniqueEmail();

        Response response = register(email, STRONG_PASSWORD);

        assertThat(response.status()).isEqualTo(201);
        assertThat(response.json()).containsOnlyKeys("userId");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE email = ?", Integer.class, email)).isOne();
        assertThat(jdbc.queryForObject("SELECT id::text FROM users WHERE email = ?", String.class, email))
                .isEqualTo(response.string("userId"));
    }

    @Test
    void storedHashIsArgon2idWithDocumentedParametersAndVerifies() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);

        String stored = storedHash(email);

        assertThat(stored).isNotEqualTo(STRONG_PASSWORD).doesNotContain(STRONG_PASSWORD);
        assertThat(stored).startsWith("{argon2}$argon2id$v=19$m=19456,t=2,p=1$");
        assertThat(PasswordProcessor.createEncoder().matches(STRONG_PASSWORD, stored)).isTrue();
        assertThat(PasswordProcessor.createEncoder().matches(STRONG_PASSWORD + "x", stored)).isFalse();
    }

    @Test
    void canonicalSpellingsAreOneIdentity() {
        String local = "canon-" + UUID.randomUUID();
        String canonical = local + "@example.com";

        assertThat(register(canonical, STRONG_PASSWORD).status()).isEqualTo(201);
        Response mixedCase = register(local.toUpperCase() + "@Example.COM", STRONG_PASSWORD);
        Response padded = register("  " + canonical + " ", STRONG_PASSWORD);

        assertThat(mixedCase.status()).isEqualTo(409);
        assertThat(padded.status()).isEqualTo(409);
        assertThat(mixedCase.header("Content-Type")).startsWith("application/problem+json");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE lower(email) = ?", Integer.class, canonical))
                .isOne();

        String userId = jdbc.queryForObject("SELECT id::text FROM users WHERE email = ?", String.class, canonical);
        for (String spelling : List.of(canonical, local.toUpperCase() + "@Example.COM", " " + canonical + " ")) {
            Response login = loggedIn(spelling, STRONG_PASSWORD);
            assertThat(get("/api/v1/test/whoami", login.string("accessToken")).string("sub")).isEqualTo(userId);
        }
    }

    /** The unique index, not a pre-check, decides a race; the loser gets 409, never 500. */
    @Test
    void concurrentDuplicateRegistrationYieldsOneAccountAnd409() throws Exception {
        String email = uniqueEmail();
        CountDownLatch start = new CountDownLatch(1);
        List<CompletableFuture<Integer>> results = new ArrayList<>();
        try (ExecutorService pool = Executors.newFixedThreadPool(4)) {
            for (int i = 0; i < 4; i++) {
                results.add(CompletableFuture.supplyAsync(() -> {
                    await(start);
                    return register(email, STRONG_PASSWORD).status();
                }, pool));
            }
            start.countDown();
        }

        assertThat(results.stream().map(CompletableFuture::join).sorted().toList())
                .containsExactly(201, 409, 409, 409);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE email = ?", Integer.class, email)).isOne();
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "\tuser@example.com",
        "user@example.com\n",
        " user@example.com",
        "us er@example.com",
        "user@exämple.com",
        "not-an-email",
        "@example.com",
        "user@",
        "user@@example.com",
        ""
    })
    void invalidEmailIsRejectedWith400(String email) {
        Response response = register(email, STRONG_PASSWORD);

        assertThat(response.status()).isEqualTo(400);
        assertThat(response.json().get("errors")).asString().contains("email");
    }

    @Test
    void tabIsInvalidInputNotStripped() {
        String canonical = uniqueEmail();

        Response response = register("\t" + canonical, STRONG_PASSWORD);

        assertThat(response.status()).isEqualTo(400);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE email = ?", Integer.class, canonical)).isZero();
    }

    @Test
    void passwordLengthBoundsAreCodePointsAfterNfc() {
        assertRejected(repeat("a1B", 5).substring(0, 14), "at least 15");
        assertAccepted(uniquePassword(15));
        assertAccepted(uniquePassword(128));
        assertRejected(uniquePassword(129), "at most 128");

        // 15 astral code points = 30 UTF-16 units; a String.length() rule would misjudge both ways.
        assertAccepted("😀".repeat(3) + "🌋".repeat(3) + "🐙".repeat(3)
                + "🦊".repeat(3) + "🌵".repeat(3));
        assertRejected("😀".repeat(14), "at least 15");

        // 15 decomposed e+U+0301 pairs: 30 code points on the wire, 15 after NFC -> accepted.
        String decomposed15 = uniqueDecomposed(15);
        assertThat(decomposed15.codePointCount(0, decomposed15.length())).isEqualTo(30);
        assertAccepted(decomposed15);
        // 14 after NFC -> rejected even though 28 code points arrived.
        assertRejected(uniqueDecomposed(14), "at least 15");
    }

    @Test
    void blocklistedPasswordsAreRejectedCaseInsensitively() {
        assertRejected("123456789987654321", "too common");   // in the SecLists-derived list
        assertRejected("PasswordPassword", "too common");     // listed lower-case
        assertRejected("FocusTracePassword", "too common");   // FocusTrace-specific entry
    }

    @Test
    void passwordEqualToEmailLocalPartIsRejected() {
        String local = "localpart" + UUID.randomUUID().toString().substring(0, 8);
        Response response = register(local + "@example.com", local.toUpperCase());

        assertThat(response.status()).isEqualTo(400);
        assertThat(response.body()).contains("too common");
    }

    @Test
    void strongFifteenCharacterPasswordIsAccepted() {
        assertAccepted("Tq7#vLm2@xR9pWz");
    }

    @Test
    void unexpectedPropertiesCannotSetServerControlledFields() {
        String email = uniqueEmail();
        UUID chosenId = UUID.randomUUID();
        String body = JSON.writeValueAsString(Map.of(
                "email", email, "password", STRONG_PASSWORD,
                "id", chosenId.toString(), "createdAt", "2000-01-01T00:00:00Z", "role", "admin"));

        Response response = postJson("/api/v1/auth/register", body, null, Map.of());

        assertThat(response.status()).isEqualTo(400);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE email = ? OR id = ?", Integer.class, email, chosenId))
                .isZero();
    }

    @Test
    void malformedRegistrationIsSafe4xx() {
        for (String body : List.of("{", "[]", "{\"email\": 5}", "{\"email\":\"a@example.com\"}", "null")) {
            Response response = postJson("/api/v1/auth/register", body, null, Map.of());
            assertThat(response.status()).as(body).isEqualTo(400);
            assertThat(response.header("Content-Type")).startsWith("application/problem+json");
            assertThat(response.body()).doesNotContain("Exception", "at com.", "at org.", "jackson");
        }
    }

    @Test
    void validationErrorsNeverEchoThePassword() {
        String tooShort = "Secret-Short!";
        Response response = register(uniqueEmail(), tooShort);

        assertThat(response.status()).isEqualTo(400);
        assertThat(response.body()).doesNotContain(tooShort);
    }

    // --- helpers ---------------------------------------------------------------

    private void assertAccepted(String password) {
        Response response = register(uniqueEmail(), password);
        assertThat(response.status()).as(response.body()).isEqualTo(201);
    }

    private void assertRejected(String password, String reason) {
        String email = uniqueEmail();
        Response response = register(email, password);
        assertThat(response.status()).isEqualTo(400);
        assertThat(response.body()).contains("password").contains(reason);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE email = ?", Integer.class, email)).isZero();
    }

    private String storedHash(String email) {
        return jdbc.queryForObject("SELECT password_hash FROM users WHERE email = ?", String.class, email);
    }

    private static String uniquePassword(int codePoints) {
        return repeat(UUID.randomUUID().toString().replace("-", ""), 5).substring(0, codePoints);
    }

    /** Letters that each have a precomposed acute form, so NFC turns every pair into one code point. */
    private static String uniqueDecomposed(int characters) {
        String letters = "aeiouycnszrwlgkmpAEIOUYCNSZRWLGKMP";
        java.util.Random random = new java.util.Random();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < characters; i++) {
            sb.append(letters.charAt(random.nextInt(letters.length()))).append('́');
        }
        String nfc = java.text.Normalizer.normalize(sb, java.text.Normalizer.Form.NFC);
        assertThat(nfc.codePointCount(0, nfc.length())).isEqualTo(characters);
        return sb.toString();
    }

    private static String repeat(String s, int times) {
        return s.repeat(times);
    }

    private static void await(CountDownLatch latch) {
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
    }

    /** Review finding: a lone surrogate (JSON "\\ud800") reached Argon2 and produced a 500. */
    @Test
    void loneSurrogatePasswordIsRejectedWith400() {
        String email = uniqueEmail();
        Response response = postJson("/api/v1/auth/register",
                "{\"email\":\"" + email + "\",\"password\":\"aaaaaaaaaaaaaaa\\ud800\"}", null, Map.of());

        assertThat(response.status()).isEqualTo(400);
        assertThat(response.body()).contains("valid Unicode");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE email = ?", Integer.class, email)).isZero();
    }
}
