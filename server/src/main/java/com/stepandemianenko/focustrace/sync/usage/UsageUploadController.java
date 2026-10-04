package com.stepandemianenko.focustrace.sync.usage;

import com.stepandemianenko.focustrace.sync.auth.AuthRateLimiter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * Architecture section 9.1/9.2 usage upload; authenticated. The owner is always
 * the token's {@code sub}; the body carries no owner field and unknown JSON
 * properties are a 400. Per-field bounds are Bean Validation; request-wide
 * invariants are checked in {@link UsageDays#upload} before its first write.
 */
@RestController
class UsageUploadController {

    // Only what persistence and deterministic retries require: no NUL (PostgreSQL
    // text cannot hold it) and no unpaired UTF-16 surrogate (the driver would store
    // '?', so a retry would compare unequal). Other control characters are data.
    static final String STORABLE = "[^\\x{0}\\p{Cs}]*";

    private final UsageDays usageDays;

    UsageUploadController(UsageDays usageDays) {
        this.usageDays = usageDays;
    }

    record UploadRequest(
            @NotNull UUID deviceId,
            @NotNull @Size(min = 1, max = UsageDays.MAX_DAYS) List<@NotNull @Valid Day> days) {
    }

    record Day(
            @NotNull LocalDate localDate,
            @NotBlank @Size(max = 64) String timezoneId,
            @NotNull @Positive Long snapshotVersion,
            // 'unavailable' is local-only and never uploaded (architecture 6).
            @NotNull @Pattern(regexp = "partial|reconciled|imported") String sourceStatus,
            @NotNull @Size(max = UsageDays.MAX_APPS_PER_DAY) List<@NotNull @Valid App> apps) {
    }

    record App(
            @NotBlank @Size(max = 255) @Pattern(regexp = STORABLE) String appKey,
            @NotBlank @Size(max = 200) @Pattern(regexp = STORABLE) String appName,
            // 90,000 = a 25-hour DST fall-back day; matches the V3 CHECK.
            @NotNull @Min(0) @Max(90_000) Integer durationSeconds,
            @NotNull @Min(0) Integer launchCount) {
    }

    record UploadResponse(List<UsageDays.DayResult> results) {
    }

    @PutMapping("/api/v1/sync/usage-days")
    @AuthRateLimiter.PerUser(AuthRateLimiter.Bucket.UPLOAD_PER_USER)
    UploadResponse upload(@Valid @RequestBody UploadRequest request, @AuthenticationPrincipal Jwt principal) {
        return new UploadResponse(usageDays.upload(UUID.fromString(principal.getSubject()), request));
    }
}
