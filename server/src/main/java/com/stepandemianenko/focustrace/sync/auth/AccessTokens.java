package com.stepandemianenko.focustrace.sync.auth;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.stereotype.Component;

/** Issues access JWTs (D04, D07). Verification lives in {@link SecurityConfig#jwtDecoder}. */
@Component
public class AccessTokens {

    private final JwtEncoder encoder;
    private final AuthProperties.Jwt config;

    AccessTokens(SecretKey jwtSigningKey, AuthProperties properties) {
        // D09: no kid. NimbusJwtEncoder.withSecretKey(...) would publish the JWK
        // thumbprint as kid, which for an HMAC key is a value derived from the secret.
        // ImmutableSecret's key has no id, so no kid header is written.
        this.encoder = new NimbusJwtEncoder(new ImmutableSecret<>(jwtSigningKey));
        this.config = properties.jwt();
    }

    /** Claims exactly iss, aud, sub, iat, exp, jti. No email, no device, no roles. */
    String issue(UUID userId) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(config.issuer())
                .audience(List.of(config.audience()))
                .subject(userId.toString())
                .issuedAt(now)
                .expiresAt(now.plus(config.accessTokenTtl()))
                .id(UUID.randomUUID().toString())
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }

    long lifetimeSeconds() {
        return config.accessTokenTtl().toSeconds();
    }
}
