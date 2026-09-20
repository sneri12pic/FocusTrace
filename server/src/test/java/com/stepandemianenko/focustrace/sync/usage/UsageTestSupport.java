package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
import org.springframework.test.context.bean.override.convention.TestBean;

/** Helpers for usage-upload tests. The server clock is pinned so date bounds are deterministic. */
abstract class UsageTestSupport extends IntegrationTest {

    static final String UPLOAD = "/api/v1/sync/usage-days";

    /** Server "now": UTC date 2026-09-19, so the newest accepted localDate is 2026-09-20. */
    static final LocalDate TODAY = LocalDate.of(2026, 9, 19);

    @TestBean
    Clock clock;

    static Clock clock() {
        return Clock.fixed(Instant.parse("2026-09-19T12:00:00Z"), ZoneOffset.UTC);
    }

    record Account(UUID id, String token) {
    }

    Account newAccount() {
        String email = uniqueEmail();
        Response registered = register(email, STRONG_PASSWORD);
        assertThat(registered.status()).isEqualTo(201);
        return new Account(UUID.fromString(registered.string("userId")),
                loggedIn(email, STRONG_PASSWORD).string("accessToken"));
    }

    UUID newDevice(Account account) {
        return newDevice(account, "Phone");
    }

    /** History responses carry the device name, so isolation tests need distinguishable ones. */
    UUID newDevice(Account account, String displayName) {
        UUID deviceId = UUID.randomUUID();
        Response response = post("/api/v1/devices",
                Map.of("deviceId", deviceId.toString(), "displayName", displayName, "platform", "android"),
                account.token());
        assertThat(response.status()).as(response.body()).isEqualTo(201);
        return deviceId;
    }

    // --- request builders (maps keep field order for readability) ----------------

    static Map<String, Object> app(String key, int durationSeconds) {
        return app(key, "Name " + key, durationSeconds, 1);
    }

    static Map<String, Object> app(String key, String name, int durationSeconds, int launchCount) {
        Map<String, Object> app = new LinkedHashMap<>();
        app.put("appKey", key);
        app.put("appName", name);
        app.put("durationSeconds", durationSeconds);
        app.put("launchCount", launchCount);
        return app;
    }

    static Map<String, Object> day(LocalDate date, long version, List<Map<String, Object>> apps) {
        return day(date, version, "reconciled", apps);
    }

    static Map<String, Object> day(LocalDate date, long version, String status, List<Map<String, Object>> apps) {
        Map<String, Object> day = new LinkedHashMap<>();
        day.put("localDate", date.toString());
        day.put("timezoneId", "Europe/London");
        day.put("snapshotVersion", version);
        day.put("sourceStatus", status);
        day.put("apps", apps);
        return day;
    }

    /** {@code count} distinct apps. */
    static List<Map<String, Object>> apps(String prefix, int count) {
        List<Map<String, Object>> apps = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            apps.add(app(prefix + i, i));
        }
        return apps;
    }

    static Map<String, Object> body(UUID deviceId, List<Map<String, Object>> days) {
        return Map.of("deviceId", deviceId.toString(), "days", days);
    }

    Response upload(Account account, UUID deviceId, List<Map<String, Object>> days) {
        return upload(account.token(), body(deviceId, days));
    }

    Response upload(String token, Object body) {
        return putJson(UPLOAD, JSON.writeValueAsString(body), token);
    }

    /** Uploads and asserts 200; returns the per-day outcomes in response order. */
    @SuppressWarnings("unchecked")
    List<String> outcomes(Account account, UUID deviceId, List<Map<String, Object>> days) {
        Response response = upload(account, deviceId, days);
        assertThat(response.status()).as(response.body()).isEqualTo(200);
        return ((List<Map<String, Object>>) response.json().get("results")).stream()
                .map(r -> (String) r.get("outcome"))
                .toList();
    }

    // --- database readers --------------------------------------------------------

    Map<String, Object> dayRow(UUID deviceId, LocalDate date) {
        return jdbc.queryForMap("SELECT * FROM usage_days WHERE device_id = ? AND local_date = ?", deviceId, date);
    }

    List<Map<String, Object>> appRows(UUID deviceId, LocalDate date) {
        return jdbc.queryForList(
                "SELECT app_key, app_name, duration_seconds, launch_count FROM usage_day_apps "
                        + "WHERE device_id = ? AND local_date = ? ORDER BY app_key",
                deviceId, date);
    }

    List<String> appKeys(UUID deviceId, LocalDate date) {
        return jdbc.queryForList("SELECT app_key FROM usage_day_apps WHERE device_id = ? AND local_date = ? "
                + "ORDER BY app_key", String.class, deviceId, date);
    }

    int dayCount(UUID deviceId) {
        return jdbc.queryForObject("SELECT count(*) FROM usage_days WHERE device_id = ?", Integer.class, deviceId);
    }

    int appCount(UUID deviceId) {
        return jdbc.queryForObject("SELECT count(*) FROM usage_day_apps WHERE device_id = ?", Integer.class, deviceId);
    }

    // --- concurrency ---------------------------------------------------------------

    /** Runs every call at once, released by one latch. No 5xx allowed. */
    @SafeVarargs
    static List<Response> race(Supplier<Response>... calls) {
        CountDownLatch start = new CountDownLatch(1);
        try (ExecutorService pool = Executors.newFixedThreadPool(calls.length)) {
            List<CompletableFuture<Response>> futures = new ArrayList<>();
            for (Supplier<Response> call : calls) {
                futures.add(CompletableFuture.supplyAsync(() -> {
                    try {
                        start.await();
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        throw new IllegalStateException(e);
                    }
                    return call.get();
                }, pool));
            }
            start.countDown();
            List<Response> responses = futures.stream().map(CompletableFuture::join).toList();
            assertThat(responses).allSatisfy(r -> assertThat(r.status()).as(r.body()).isEqualTo(200));
            return responses;
        }
    }

    @SuppressWarnings("unchecked")
    static List<String> outcomesOf(Response response) {
        return ((List<Map<String, Object>>) response.json().get("results")).stream()
                .map(r -> (String) r.get("outcome"))
                .toList();
    }
}
