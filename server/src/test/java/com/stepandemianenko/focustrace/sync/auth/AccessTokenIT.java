package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.PlainJWT;
import com.nimbusds.jwt.SignedJWT;
import com.stepandemianenko.focustrace.sync.IntegrationTest;
import com.stepandemianenko.focustrace.sync.TestEndpoints;
import java.security.KeyPairGenerator;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.UnaryOperator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidationException;

/** Baseline section 18 "Access JWT"; plan criteria 3 and 14; D04, D07. */
class AccessTokenIT extends IntegrationTest {

    private static final String WHOAMI = "/api/v1/test/whoami";

    @Autowired
    private JwtDecoder jwtDecoder;

    private String userId;
    private String issuedToken;

    @BeforeEach
    void account() {
        Response login = newSession();
        issuedToken = login.string("accessToken");
        userId = get(WHOAMI, issuedToken).string("sub");
    }

    @Test
    void issuedTokenIsAccepted() {
        Response response = get(WHOAMI, issuedToken);

        assertThat(response.status()).isEqualTo(200);
        assertThat(response.string("sub")).isEqualTo(userId);
    }

    /** Positive control: the minting helper below produces tokens the server accepts. */
    @Test
    void correctlyMintedTokenIsAccepted() {
        assertThat(get(WHOAMI, hs256(TEST_SECRET_BYTES, claims -> claims)).status()).isEqualTo(200);
    }

    @Test
    void missingTokenIs401() {
        assertUnauthorized(get(WHOAMI, null));
    }

    @Test
    void malformedTokensAre401() {
        for (String token : List.of("abc", "a.b.c", "a.b", issuedToken + "x", "..", "e30.e30.")) {
            assertUnauthorized(get(WHOAMI, token));
        }
    }

    @Test
    void tamperedPayloadIs401() {
        String[] parts = issuedToken.split("\\.");
        String otherUser = newSession().string("accessToken");
        String forged = parts[0] + "." + otherUser.split("\\.")[1] + "." + parts[2];

        assertUnauthorized(get(WHOAMI, forged));
    }

    @Test
    void expiredTokenIs401() {
        Instant past = Instant.now().minusSeconds(5);
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c
                .issueTime(Date.from(past.minusSeconds(900))).expirationTime(Date.from(past)))));
    }

    @Test
    void wrongIssuerOrAudienceIs401() {
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.issuer("someone-else"))));
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.audience("another-service"))));
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.issuer(null))));
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.audience((String) null))));
    }

    @Test
    void missingRequiredClaimsAre401() {
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.expirationTime(null))));
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.jwtID(null))));
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.subject(null))));
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.subject("not-a-uuid"))));
    }

    /**
     * D07 fixes the claim set of issued tokens; acceptance is defined by D07's
     * verification list and baseline section 6, which require neither iat nor jti.
     * jti is required anyway because baseline section 6 reserves it for a future
     * denylist. A missing iat is accepted, and this pins what Spring actually does
     * with it: MappedJwtClaimSetConverter synthesises iat = exp - 1 s.
     */
    @Test
    void missingIatIsAcceptedWithSynthesisedValueWhileMissingJtiIsRejected() {
        String noIat = hs256(TEST_SECRET_BYTES, c -> c.issueTime(null));

        Jwt decoded = jwtDecoder.decode(noIat);

        assertThat(decoded.getIssuedAt()).isEqualTo(decoded.getExpiresAt().minusSeconds(1));
        assertThat(get(WHOAMI, noIat).status()).isEqualTo(200);
        assertThatThrownBy(() -> jwtDecoder.decode(hs256(TEST_SECRET_BYTES, c -> c.jwtID(null))))
                .isInstanceOf(JwtValidationException.class)
                .hasMessageContaining("jti");
    }

    @Test
    void validlySignedTokenForNonexistentAccountIs401() {
        assertUnauthorized(get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.subject(UUID.randomUUID().toString()))));
    }

    @Test
    void unsignedTokenIs401() {
        String none = new PlainJWT(claims().build()).serialize();
        assertUnauthorized(get(WHOAMI, none));
        // Same, with a trailing fake signature segment.
        assertUnauthorized(get(WHOAMI, none + "c2ln"));
    }

    @Test
    void unexpectedAlgorithmsAre401() throws Exception {
        // HS512 with the *correct* secret: rejected because of the algorithm, not the key.
        SignedJWT hs512 = new SignedJWT(new JWSHeader(JWSAlgorithm.HS512), claims().build());
        hs512.sign(new MACSigner(TEST_SECRET_BYTES));
        assertUnauthorized(get(WHOAMI, hs512.serialize()));

        KeyPairGenerator rsa = KeyPairGenerator.getInstance("RSA");
        rsa.initialize(2048);
        SignedJWT rs256 = new SignedJWT(new JWSHeader(JWSAlgorithm.RS256), claims().build());
        rs256.sign(new RSASSASigner(rsa.generateKeyPair().getPrivate()));
        assertUnauthorized(get(WHOAMI, rs256.serialize()));
    }

    /** A token asserting another user's identity, signed with anything but the server key, grants nothing. */
    @Test
    void foreignKeyTokenAssertingAnotherUserGrantsNothing() {
        assertUnauthorized(get(WHOAMI, hs256(randomBytes(32), c -> c)));
    }

    @Test
    void unauthorizedBodyIsGenericProblemDetail() {
        Response response = get(WHOAMI, hs256(TEST_SECRET_BYTES, c -> c.issuer("someone-else")));

        assertThat(response.header("Content-Type")).startsWith("application/problem+json");
        assertThat(response.json()).containsEntry("status", 401).containsEntry("detail", "Authentication failed.");
        assertThat(response.header("WWW-Authenticate")).isEqualTo("Bearer");
        assertThat(response.body()).doesNotContainIgnoringCase("iss").doesNotContain("Jwt", "claim", "Exception");
    }

    @Test
    void onlyTheThreeAuthEndpointsArePublic() {
        assertUnauthorized(get(WHOAMI, null));
        assertUnauthorized(post("/api/v1/auth/logout", Map.of("refreshToken", "x")));
        assertUnauthorized(get("/api/v1/auth/login", null));
        assertUnauthorized(get("/api/v1/auth/register", null));
        assertUnauthorized(post("/api/v1/devices", Map.of()));
        assertUnauthorized(get("/api/v1/usage", null));
        assertUnauthorized(get("/", null));
        assertUnauthorized(get("/error", null));
        assertUnauthorized(get("/actuator/env", null));

        assertThat(post("/api/v1/auth/register", Map.of()).status()).isEqualTo(400);
        assertThat(post("/api/v1/auth/login", Map.of()).status()).isEqualTo(400);
        assertThat(post("/api/v1/auth/refresh", Map.of()).status()).isEqualTo(400);
    }

    @Test
    void noHttpSessionIsCreated() {
        Response response = get(WHOAMI, issuedToken);

        assertThat(response.headers().allValues("Set-Cookie")).isEmpty();
    }

    @Test
    void forcedInternalFailureIsGeneric500() {
        Response response = get("/api/v1/test/boom", issuedToken);

        assertThat(response.status()).isEqualTo(500);
        assertThat(response.header("Content-Type")).startsWith("application/problem+json");
        assertThat(response.json()).containsKeys("correlationId").containsEntry("detail", "Internal error.");
        assertThat(response.body()).doesNotContain(TestEndpoints.INTERNAL_DETAIL, "IllegalStateException",
                "at com.", "trace");
    }

    // --- minting ---------------------------------------------------------------

    private JWTClaimsSet.Builder claims() {
        Instant now = Instant.now();
        return new JWTClaimsSet.Builder()
                .issuer("focustrace-sync")
                .audience("focustrace-app")
                .subject(userId)
                .issueTime(Date.from(now))
                .expirationTime(Date.from(now.plusSeconds(300)))
                .jwtID(UUID.randomUUID().toString());
    }

    private String hs256(byte[] secret, UnaryOperator<JWTClaimsSet.Builder> customize) {
        try {
            SignedJWT jwt = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), customize.apply(claims()).build());
            jwt.sign(new MACSigner(secret));
            return jwt.serialize();
        } catch (JOSEException e) {
            throw new IllegalStateException(e);
        }
    }

    private static void assertUnauthorized(Response response) {
        assertThat(response.status()).as(response.body()).isEqualTo(401);
        assertThat(response.body()).doesNotContain("Exception", "at com.", "at org.");
    }
}
