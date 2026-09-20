package com.stepandemianenko.focustrace.sync.usage;

import com.stepandemianenko.focustrace.sync.common.ApiException;
import com.stepandemianenko.focustrace.sync.usage.UsageUploadController.App;
import com.stepandemianenko.focustrace.sync.usage.UsageUploadController.Day;
import com.stepandemianenko.focustrace.sync.usage.UsageUploadController.UploadRequest;
import java.time.Clock;
import java.time.DateTimeException;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Usage snapshot upload (architecture sections 7 and 9.1-9.2). One request is one
 * transaction; each {@code (device_id, local_date)} is replaced wholesale when the
 * incoming {@code snapshot_version} is higher, and otherwise left untouched.
 *
 * <p>Relies on PostgreSQL READ COMMITTED (not overridden anywhere): the guarded
 * upsert locks the conflicting row even when its {@code WHERE} is false, and the
 * next statement sees the latest committed version of that locked row.
 */
@Component
class UsageDays {

    static final int MAX_DAYS = 31;
    static final int MAX_APPS_PER_DAY = 500;
    static final int MAX_APP_ROWS = 1000;
    /** No FocusTrace data predates 2026 (first commit 2026-06-30); bounds per-device storage. */
    static final LocalDate MIN_DATE = LocalDate.of(2026, 1, 1);

    enum Outcome { APPLIED, DUPLICATE, STALE, CONFLICT }

    /** {@code storedVersion} is the version the server holds after this request. */
    record DayResult(LocalDate localDate, Outcome outcome, long storedVersion) {
    }

    private record StoredDay(long version, String timezoneId, String sourceStatus) {
    }

    private final JdbcClient jdbc;
    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    UsageDays(JdbcClient jdbc, JdbcTemplate jdbcTemplate, Clock clock) {
        this.jdbc = jdbc;
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
    }

    /** Results are in request order, one per submitted day. */
    @Transactional
    List<DayResult> upload(UUID userId, UploadRequest request) {
        UUID deviceId = request.deviceId();
        // D16: ownership is the query predicate; foreign and unknown are the same 404
        // and nothing is written. KEY SHARE keeps the device from being deleted under
        // this transaction without blocking other uploads to it.
        boolean owned = jdbc.sql("SELECT 1 FROM devices WHERE id = :id AND user_id = :userId FOR KEY SHARE")
                .param("id", deviceId)
                .param("userId", userId)
                .query(Integer.class)
                .optional()
                .isPresent();
        if (!owned) {
            throw ApiException.notFound();
        }
        validate(request.days());

        // Ascending date order is a total lock order across concurrent requests,
        // so overlapping batches cannot deadlock.
        Map<LocalDate, DayResult> results = new HashMap<>();
        request.days().stream()
                .sorted(Comparator.comparing(Day::localDate))
                .forEach(day -> results.put(day.localDate(), write(userId, deviceId, day)));
        return request.days().stream().map(day -> results.get(day.localDate())).toList();
    }

    /** Request-wide invariants, all checked before the first write. */
    private void validate(List<Day> days) {
        LocalDate maxDate = LocalDate.ofInstant(clock.instant(), ZoneOffset.UTC).plusDays(1);
        Set<LocalDate> dates = new HashSet<>();
        int appRows = 0;
        for (int i = 0; i < days.size(); i++) {
            Day day = days.get(i);
            String at = "days[" + i + "]";
            if (!dates.add(day.localDate())) {
                throw ApiException.invalidField(at + ".localDate", "Duplicate localDate in request.");
            }
            if (day.localDate().isBefore(MIN_DATE) || day.localDate().isAfter(maxDate)) {
                throw ApiException.invalidField(at + ".localDate",
                        "Must be between " + MIN_DATE + " and the current UTC date plus one day.");
            }
            try {
                ZoneId.of(day.timezoneId());
            } catch (DateTimeException e) {
                throw ApiException.invalidField(at + ".timezoneId", "Must be a resolvable time-zone ID.");
            }
            Set<String> appKeys = new HashSet<>();
            for (App app : day.apps()) {
                if (!appKeys.add(app.appKey())) {
                    throw ApiException.invalidField(at + ".apps", "Duplicate appKey within a day.");
                }
            }
            appRows += day.apps().size();
        }
        if (appRows > MAX_APP_ROWS) {
            throw ApiException.invalidField("days", "At most " + MAX_APP_ROWS + " app rows per request.");
        }
    }

    /** Every statement carries {@code userId} (D16), not only the gate above. */
    private DayResult write(UUID userId, UUID deviceId, Day day) {
        Optional<Long> applied = jdbc.sql("""
                        INSERT INTO usage_days (device_id, local_date, snapshot_version, timezone_id, source_status)
                        SELECT id, :localDate, :version, :timezoneId, :sourceStatus
                          FROM devices
                         WHERE id = :deviceId AND user_id = :userId
                        ON CONFLICT (device_id, local_date) DO UPDATE
                           SET snapshot_version = EXCLUDED.snapshot_version,
                               timezone_id      = EXCLUDED.timezone_id,
                               source_status    = EXCLUDED.source_status,
                               received_at      = now()
                         WHERE usage_days.snapshot_version < EXCLUDED.snapshot_version
                        RETURNING snapshot_version""")
                .param("deviceId", deviceId)
                .param("localDate", day.localDate())
                .param("version", day.snapshotVersion())
                .param("timezoneId", day.timezoneId())
                .param("sourceStatus", day.sourceStatus())
                .param("userId", userId)
                .query(Long.class)
                .optional();
        if (applied.isPresent()) {
            replaceApps(userId, deviceId, day);
            return new DayResult(day.localDate(), Outcome.APPLIED, day.snapshotVersion());
        }

        // The stored version is >= incoming, and the upsert holds the row lock until
        // commit, so this read is the committed state and nobody can change it now.
        StoredDay stored = jdbc.sql("""
                        SELECT d.snapshot_version, d.timezone_id, d.source_status
                          FROM usage_days d
                          JOIN devices dev ON dev.id = d.device_id
                         WHERE dev.user_id = :userId AND d.device_id = :deviceId AND d.local_date = :localDate""")
                .param("userId", userId)
                .param("deviceId", deviceId)
                .param("localDate", day.localDate())
                .query((rs, row) -> new StoredDay(
                        rs.getLong("snapshot_version"), rs.getString("timezone_id"), rs.getString("source_status")))
                .single();
        if (stored.version() > day.snapshotVersion()) {
            return new DayResult(day.localDate(), Outcome.STALE, stored.version());
        }
        boolean same = stored.timezoneId().equals(day.timezoneId())
                && stored.sourceStatus().equals(day.sourceStatus())
                // Apps are a keyed set (appKey unique on both sides): order is irrelevant.
                && new HashSet<>(storedApps(userId, deviceId, day.localDate())).equals(new HashSet<>(day.apps()));
        return new DayResult(day.localDate(), same ? Outcome.DUPLICATE : Outcome.CONFLICT, stored.version());
    }

    /** Whole-day replace, never merge: durations are totals, not deltas. */
    private void replaceApps(UUID userId, UUID deviceId, Day day) {
        jdbc.sql("""
                        DELETE FROM usage_day_apps a
                         USING devices dev
                         WHERE dev.id = a.device_id AND dev.user_id = :userId
                           AND a.device_id = :deviceId AND a.local_date = :localDate""")
                .param("userId", userId)
                .param("deviceId", deviceId)
                .param("localDate", day.localDate())
                .update();
        if (day.apps().isEmpty()) {
            return;
        }
        // Unscoped only because the owner-scoped upsert just returned this day's row.
        jdbcTemplate.batchUpdate("""
                        INSERT INTO usage_day_apps
                            (device_id, local_date, app_key, app_name, duration_seconds, launch_count)
                        VALUES (?, ?, ?, ?, ?, ?)""",
                day.apps().stream()
                        .map(app -> new Object[] {deviceId, day.localDate(), app.appKey(), app.appName(),
                            app.durationSeconds(), app.launchCount()})
                        .toList());
    }

    private List<App> storedApps(UUID userId, UUID deviceId, LocalDate localDate) {
        return jdbc.sql("""
                        SELECT a.app_key, a.app_name, a.duration_seconds, a.launch_count
                          FROM usage_day_apps a
                          JOIN devices dev ON dev.id = a.device_id
                         WHERE dev.user_id = :userId AND a.device_id = :deviceId AND a.local_date = :localDate""")
                .param("userId", userId)
                .param("deviceId", deviceId)
                .param("localDate", localDate)
                .query((rs, row) -> new App(rs.getString("app_key"), rs.getString("app_name"),
                        rs.getInt("duration_seconds"), rs.getInt("launch_count")))
                .list();
    }
}
