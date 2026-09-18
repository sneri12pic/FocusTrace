package com.stepandemianenko.focustrace.sync.auth;

import com.stepandemianenko.focustrace.sync.common.ApiException;
import jakarta.servlet.DispatcherType;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtAudienceValidator;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.web.servlet.HandlerExceptionResolver;

import static org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher.pathPattern;

/**
 * The only source of HTTP authorization rules (baseline section 13). Stateless
 * bearer-JWT authentication; three public endpoints; everything else authenticated.
 */
@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(AuthProperties.class)
public class SecurityConfig {

    private static final Logger securityLog = LoggerFactory.getLogger("focustrace.security");

    /** The complete public allow-list. Making anything else public is a visible diff here. */
    static final RequestMatcher PUBLIC_ENDPOINTS = new OrRequestMatcher(
            pathPattern(HttpMethod.POST, "/api/v1/auth/register"),
            pathPattern(HttpMethod.POST, "/api/v1/auth/login"),
            pathPattern(HttpMethod.POST, "/api/v1/auth/refresh"));

    static final int MIN_SECRET_BYTES = 32;

    @Bean
    SecurityFilterChain apiSecurity(
            HttpSecurity http,
            JwtDecoder jwtDecoder,
            UserRepository users,
            @Qualifier("handlerExceptionResolver") HandlerExceptionResolver errors) {

        // Every 401 goes through ApiExceptionHandler: one body, no decoder detail in the
        // response or in WWW-Authenticate. The token itself is never logged.
        AuthenticationEntryPoint unauthorized = (request, response, ex) -> {
            if (ex instanceof OAuth2AuthenticationException) {
                securityLog.info("event=access_token_rejected type={}", ex.getClass().getSimpleName());
            }
            errors.resolveException(request, response, null, ApiException.unauthorized());
        };

        http
                // CSRF: credentials travel in the Authorization header, never ambiently in a
                // cookie, and there is no server-side session. Reassess if cookies ever appear.
                .csrf(csrf -> csrf.disable())
                // CORS: the only client is native Android. Stays off until a browser client exists.
                .cors(cors -> cors.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .httpBasic(basic -> basic.disable())
                .formLogin(form -> form.disable())
                .logout(logout -> logout.disable())
                .requestCache(cache -> cache.disable())
                .authorizeHttpRequests(auth -> auth
                        // Container error rendering only; a client cannot request this dispatch type.
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
                        .requestMatchers(PUBLIC_ENDPOINTS).permitAll()
                        .anyRequest().authenticated())
                .oauth2ResourceServer(resourceServer -> resourceServer
                        .bearerTokenResolver(ignoringPublicEndpoints())
                        .authenticationEntryPoint(unauthorized)
                        .jwt(jwt -> jwt.decoder(jwtDecoder).jwtAuthenticationConverter(existingAccountsOnly(users))))
                .exceptionHandling(exceptions -> exceptions.authenticationEntryPoint(unauthorized));
        return http.build();
    }

    /**
     * D09: base64-encoded, at least 32 decoded bytes, no fallback in any profile.
     * Messages name the property, never the value. This establishes encoding and
     * length only - not entropy, which is an operational requirement (generate with
     * {@code openssl rand -base64 32}).
     */
    @Bean
    SecretKey jwtSigningKey(AuthProperties properties) {
        String secret = properties.jwt().secret();
        if (secret.startsWith("${")) {
            // Binding leaves an unresolvable placeholder as its literal text.
            throw new IllegalStateException("focustrace.auth.jwt.secret (FOCUSTRACE_JWT_SECRET) is not set");
        }
        byte[] key;
        try {
            key = Base64.getDecoder().decode(secret);
        } catch (IllegalArgumentException e) {
            // The decoder's message quotes the offending character: do not chain it.
            throw new IllegalStateException("focustrace.auth.jwt.secret (FOCUSTRACE_JWT_SECRET) is not valid base64");
        }
        if (key.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("focustrace.auth.jwt.secret (FOCUSTRACE_JWT_SECRET) must decode to at least "
                    + MIN_SECRET_BYTES + " bytes; generate it with: openssl rand -base64 32");
        }
        return new SecretKeySpec(key, "HmacSHA256");
    }

    /**
     * D07 verification. The algorithm is fixed here to HS256: a token whose header
     * asks for anything else, including {@code none}, is rejected before any
     * signature check - the header never selects the verification path.
     */
    @Bean
    JwtDecoder jwtDecoder(SecretKey jwtSigningKey, AuthProperties properties) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withSecretKey(jwtSigningKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        // D04: zero clock skew (policy) - one process issues and verifies.
        JwtTimestampValidator timestamps = new JwtTimestampValidator(Duration.ZERO);
        timestamps.setAllowEmptyExpiryClaim(false);
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                timestamps,
                new JwtIssuerValidator(properties.jwt().issuer()),
                new JwtAudienceValidator(properties.jwt().audience()),
                new JwtClaimValidator<String>(JwtClaimNames.SUB, SecurityConfig::isUuid),
                // jti required: baseline section 6 reserves it for a future denylist.
                // iat is not: D07 fixes the claims of *issued* tokens, and neither D07's
                // verification list nor baseline section 6 requires iat on acceptance.
                // (A presence check here would also be inert - Spring synthesises a
                // missing iat as exp - 1 s before validators run; see AccessTokenIT.)
                new JwtClaimValidator<String>(JwtClaimNames.JTI, Objects::nonNull)));
        return decoder;
    }

    /** Baseline section 6: {@code sub} must resolve to an existing account. */
    private static Converter<Jwt, AbstractAuthenticationToken> existingAccountsOnly(UserRepository users) {
        return jwt -> {
            if (!users.existsById(UUID.fromString(jwt.getSubject()))) {
                throw new InvalidBearerTokenException("Unknown subject");
            }
            return new JwtAuthenticationToken(jwt, List.of(), jwt.getSubject());
        };
    }

    /**
     * Public endpoints never read the Authorization header, so a client that attaches
     * an expired access token to its refresh call still reaches the refresh endpoint.
     */
    private static BearerTokenResolver ignoringPublicEndpoints() {
        DefaultBearerTokenResolver header = new DefaultBearerTokenResolver();
        return request -> PUBLIC_ENDPOINTS.matches(request) ? null : header.resolve(request);
    }

    private static boolean isUuid(String value) {
        if (value == null) {
            return false;
        }
        try {
            return UUID.fromString(value).toString().equals(value);
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
}
