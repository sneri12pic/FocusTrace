package com.stepandemianenko.focustrace.sync.auth;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Duration;
import org.hibernate.validator.constraints.time.DurationMin;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Authentication values the architecture marks as <b>configuration</b> (section 5.1).
 * Values marked <b>policy</b> - Argon2id parameters, password bounds, the HS256
 * algorithm, zero clock skew - are deliberately not here.
 *
 * <p>Every field is required: application.yml supplies the documented defaults,
 * except the signing secret, which has no default anywhere (D09).
 */
@Validated
@ConfigurationProperties("focustrace.auth")
public record AuthProperties(@Valid @NotNull Jwt jwt, @Valid @NotNull Session session, @Valid @NotNull RateLimit rateLimit) {

    /** D04, D07, D09. */
    public record Jwt(
            @NotBlank String secret,
            @NotBlank String issuer,
            @NotBlank String audience,
            @NotNull @DurationMin(seconds = 1) Duration accessTokenTtl) {

        @Override
        public String toString() {
            return "Jwt[secret=<redacted>, issuer=" + issuer + ", audience=" + audience
                    + ", accessTokenTtl=" + accessTokenTtl + "]";
        }
    }

    /** D05, D06, D08. A reuse grace of zero is supported and means strict rotation. */
    public record Session(
            @NotNull @DurationMin(seconds = 1) Duration absoluteLifetime,
            @NotNull @DurationMin(seconds = 1) Duration inactivityLifetime,
            @NotNull @DurationMin(seconds = 0) Duration reuseGrace) {
    }

    /** D15; the three per-user limits are D18. */
    public record RateLimit(
            @Positive int maxEntriesPerLimiter,
            @Valid @NotNull Limit registerPerSource,
            @Valid @NotNull Limit loginPerSource,
            @Valid @NotNull Limit loginPerAccount,
            @Valid @NotNull Limit refreshPerSource,
            @Valid @NotNull Limit deviceRegisterPerUser,
            @Valid @NotNull Limit uploadPerUser,
            @Valid @NotNull Limit historyPerUser) {
    }

    /** {@code capacity} requests per {@code period}, refilled continuously. */
    public record Limit(@Positive int capacity, @NotNull @DurationMin(seconds = 1) Duration period) {
    }
}
