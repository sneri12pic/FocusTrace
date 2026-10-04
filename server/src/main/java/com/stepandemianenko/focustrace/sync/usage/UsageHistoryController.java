package com.stepandemianenko.focustrace.sync.usage;

import com.stepandemianenko.focustrace.sync.auth.AuthRateLimiter;
import com.stepandemianenko.focustrace.sync.common.ApiException;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Architecture section 9.3 history read; authenticated. The caller is always the
 * token's {@code sub}, so the query has no owner parameter to supply. A malformed
 * or missing parameter is the framework's common 400.
 */
@RestController
class UsageHistoryController {

    private final UsageDays usageDays;

    UsageHistoryController(UsageDays usageDays) {
        this.usageDays = usageDays;
    }

    record HistoryResponse(List<UsageDays.HistoryDay> days) {
    }

    /**
     * {@code from} inclusive, {@code to} exclusive, mirroring the local
     * {@code getUsageHistory}. {@code deviceId} narrows the result to one device;
     * a device the caller does not own filters to nothing, exactly as an unknown
     * one does (D16), so no lookup precedes the query.
     */
    @GetMapping("/api/v1/usage")
    @AuthRateLimiter.PerUser(AuthRateLimiter.Bucket.HISTORY_PER_USER)
    HistoryResponse history(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) UUID deviceId,
            @AuthenticationPrincipal Jwt principal) {
        long days = ChronoUnit.DAYS.between(from, to);
        if (days < 1) {
            throw ApiException.invalidField("to", "Must be after from: the range is from-inclusive, to-exclusive.");
        }
        if (days > UsageDays.MAX_HISTORY_DAYS) {
            throw ApiException.invalidField("to", "At most " + UsageDays.MAX_HISTORY_DAYS + " days per request.");
        }
        return new HistoryResponse(usageDays.history(UUID.fromString(principal.getSubject()), from, to, deviceId));
    }
}
