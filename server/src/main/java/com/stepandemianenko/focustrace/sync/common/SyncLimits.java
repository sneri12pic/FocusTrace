package com.stepandemianenko.focustrace.sync.common;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Duration;
import org.hibernate.validator.constraints.time.DurationMin;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * D18 per-account resource bounds (architecture 5.1). The existence of each bound is
 * policy; the values are initial operational defaults in application.yml.
 *
 * @param maxActiveDevices   a new installation is admitted only while the account has
 *                           fewer devices seen within {@code deviceActiveWindow}
 * @param deviceActiveWindow how long after its last registration a device keeps a slot
 * @param maxStoredDays      stored usage days, one per device per date, across the account
 */
@Validated
@ConfigurationProperties("focustrace.sync")
public record SyncLimits(
        @Positive int maxActiveDevices,
        @NotNull @DurationMin(days = 1) Duration deviceActiveWindow,
        @Positive int maxStoredDays) {
}
