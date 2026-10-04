package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.entry;

import com.stepandemianenko.focustrace.sync.common.SyncLimits;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Phase 1 Step 5: {@code GET /api/v1/usage} against PostgreSQL (architecture 9.3).
 * Closes plan criterion 11's history half and criterion 13's usage-read half.
 */
class UsageHistoryIT extends UsageTestSupport {

    @Autowired
    SyncLimits limits;

    private static final String HISTORY = "/api/v1/usage";

    private static final LocalDate DAY_1 = TODAY.minusDays(3);
    private static final LocalDate DAY_2 = TODAY.minusDays(2);
    private static final LocalDate DAY_3 = TODAY.minusDays(1);

    // --- helpers ----------------------------------------------------------------

    private static String range(LocalDate from, LocalDate to) {
        return HISTORY + "?from=" + from + "&to=" + to;
    }

    private Response read(Account account, String path) {
        return get(path, account.token());
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> daysOf(Response response) {
        assertThat(response.status()).as(response.body()).isEqualTo(200);
        return (List<Map<String, Object>>) response.json().get("days");
    }

    /** Every day the account holds, across every device. */
    private List<Map<String, Object>> allDays(Account account) {
        return daysOf(read(account, range(UsageDays.MIN_DATE, TODAY.plusDays(2))));
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> apps(Map<String, Object> day) {
        return (List<Map<String, Object>>) day.get("apps");
    }

    private static LocalDate dateOf(Map<String, Object> day) {
        return LocalDate.parse((String) day.get("localDate"));
    }

    // --- authentication ------------------------------------------------------------

    @Test
    void requestWithoutAnAccessTokenIsUnauthorized() {
        assertThat(get(range(DAY_1, DAY_3), null).status()).isEqualTo(401);
    }

    @Test
    void requestWithAnInvalidAccessTokenIsUnauthorized() {
        assertThat(get(range(DAY_1, DAY_3), "not.a.token").status()).isEqualTo(401);
    }

    // --- date range ------------------------------------------------------------------

    @Test
    void returnsEveryFieldOfTheStoredDay() {
        Account account = newAccount();
        UUID device = newDevice(account, "Galaxy A36");
        assertThat(outcomes(account, device,
                        List.of(day(DAY_2, 1_758_124_800_123L, List.of(
                                app("com.b.app", "Bee", 2840, 12),
                                app("com.a.app", "Ay", 60, 1))))))
                .containsExactly("APPLIED");

        List<Map<String, Object>> days = daysOf(read(account, range(DAY_2, DAY_3)));

        assertThat(days).hasSize(1);
        Map<String, Object> only = days.getFirst();
        assertThat(only).contains(
                entry("deviceId", device.toString()),
                entry("deviceName", "Galaxy A36"),
                entry("localDate", DAY_2.toString()),
                entry("timezoneId", "Europe/London"));
        assertThat(((Number) only.get("snapshotVersion")).longValue()).isEqualTo(1_758_124_800_123L);
        // Ordered by appKey, so a stored day always reads back the same way.
        assertThat(apps(only)).containsExactly(
                Map.of("appKey", "com.a.app", "appName", "Ay", "durationSeconds", 60, "launchCount", 1),
                Map.of("appKey", "com.b.app", "appName", "Bee", "durationSeconds", 2840, "launchCount", 12));
    }

    @Test
    void fromIsInclusiveAndToIsExclusive() {
        Account account = newAccount();
        UUID device = newDevice(account);
        assertThat(outcomes(account, device, List.of(
                        day(DAY_1, 10, List.of(app("com.one", 1))),
                        day(DAY_2, 10, List.of(app("com.two", 2))),
                        day(DAY_3, 10, List.of(app("com.three", 3))))))
                .containsExactly("APPLIED", "APPLIED", "APPLIED");

        assertThat(daysOf(read(account, range(DAY_2, DAY_3))))
                .extracting(UsageHistoryIT::dateOf)
                .containsExactly(DAY_2);
        // Ascending date order is contract, not an accident of insertion order.
        assertThat(daysOf(read(account, range(DAY_1, DAY_3.plusDays(1)))))
                .extracting(UsageHistoryIT::dateOf)
                .containsExactly(DAY_1, DAY_2, DAY_3);
        assertThat(daysOf(read(account, range(DAY_3, DAY_3.plusDays(1)))))
                .extracting(UsageHistoryIT::dateOf)
                .containsExactly(DAY_3);
    }

    @Test
    void malformedDatesAreRejected() {
        Account account = newAccount();
        assertThat(read(account, HISTORY + "?from=yesterday&to=" + DAY_3).status()).isEqualTo(400);
        assertThat(read(account, HISTORY + "?from=" + DAY_1 + "&to=2026-13-01").status()).isEqualTo(400);
        assertThat(read(account, HISTORY + "?from=" + DAY_1 + "&to=2026-02-30").status()).isEqualTo(400);
    }

    @Test
    void missingRangeParametersAreRejected() {
        Account account = newAccount();
        assertThat(read(account, HISTORY).status()).isEqualTo(400);
        assertThat(read(account, HISTORY + "?from=" + DAY_1).status()).isEqualTo(400);
        assertThat(read(account, HISTORY + "?to=" + DAY_3).status()).isEqualTo(400);
    }

    @Test
    void emptyAndReversedRangesAreRejected() {
        Account account = newAccount();
        // to is exclusive, so to == from asks for nothing. Both are client bugs, not empty results.
        assertThat(read(account, range(DAY_2, DAY_2)).status()).isEqualTo(400);
        assertThat(read(account, range(DAY_3, DAY_1)).status()).isEqualTo(400);
    }

    /**
     * Architecture 9.3 at the production default, not a test-sized bound: 40 days of
     * 500 apps is exactly 20,000 rows and returns whole; one more stored day without
     * apps is row 20,001, and the request is refused. Rows are inserted directly -
     * uploading them would take 20 requests and prove nothing more.
     */
    @Test
    @SuppressWarnings("unchecked")
    void theProductionBoundAccepts20000RowsAndRefusesThe20001st() {
        assertThat(limits.maxHistoryRows()).isEqualTo(20_000);
        Account account = newAccount();
        UUID device = newDevice(account);
        LocalDate first = TODAY.minusDays(60);
        jdbc.update("""
                INSERT INTO usage_days (device_id, local_date, snapshot_version, timezone_id, source_status)
                SELECT ?, CAST(? AS date) + d, 1, 'Europe/London', 'reconciled' FROM generate_series(0, 39) d""",
                device, first);
        jdbc.update("""
                INSERT INTO usage_day_apps (device_id, local_date, app_key, app_name, duration_seconds, launch_count)
                SELECT ?, CAST(? AS date) + d, 'app' || lpad(a::text, 3, '0'), 'App', 60, 1
                  FROM generate_series(0, 39) d, generate_series(1, 500) a""",
                device, first);
        String path = range(first, TODAY);

        List<Map<String, Object>> days = daysOf(read(account, path));
        assertThat(days).hasSize(40);
        assertThat(days.stream().mapToInt(day -> apps(day).size()).sum()).isEqualTo(20_000);

        jdbc.update("""
                INSERT INTO usage_days (device_id, local_date, snapshot_version, timezone_id, source_status)
                VALUES (?, ?, 1, 'Europe/London', 'reconciled')""", device, first.plusDays(40));
        Response refused = read(account, path);

        assertThat(refused.status()).isEqualTo(400);
        assertThat(refused.json()).doesNotContainKey("days");
        assertThat(refused.body()).contains("20000");
    }

    @Test
    void theMaximumRangeIsAcceptedAndOneDayMoreIsRejected() {
        Account account = newAccount();
        LocalDate from = UsageDays.MIN_DATE;
        assertThat(read(account, range(from, from.plusDays(UsageDays.MAX_HISTORY_DAYS))).status()).isEqualTo(200);
        assertThat(read(account, range(from, from.plusDays(UsageDays.MAX_HISTORY_DAYS + 1))).status()).isEqualTo(400);
    }

    @Test
    void aMalformedDeviceIdIsRejected() {
        Account account = newAccount();
        assertThat(read(account, range(DAY_1, DAY_3) + "&deviceId=not-a-uuid").status()).isEqualTo(400);
    }

    // --- device isolation (criterion 11 history half, criterion 13 read half) ---------

    @Test
    void ownDevicesAreReturnedSeparatelyAndOtherAccountsAreNeverVisible() {
        Account userA = newAccount();
        UUID deviceA = newDevice(userA, "Phone A");
        UUID deviceB = newDevice(userA, "Tablet B");
        Account userB = newAccount();
        UUID deviceC = newDevice(userB, "Phone C");

        // The same date on all three devices: no merge anywhere, no leak between accounts.
        outcomes(userA, deviceA, List.of(day(DAY_2, 10, List.of(app("com.shared", "Shared", 100, 1)))));
        outcomes(userA, deviceB, List.of(day(DAY_2, 10, List.of(app("com.shared", "Shared", 999, 9)))));
        outcomes(userB, deviceC, List.of(day(DAY_2, 10, List.of(app("com.shared", "Shared", 777, 7)))));

        List<Map<String, Object>> aDays = allDays(userA);
        assertThat(aDays).hasSize(2);
        assertThat(aDays).extracting(d -> d.get("deviceId"))
                .containsExactlyInAnyOrder(deviceA.toString(), deviceB.toString());
        assertThat(aDays).extracting(d -> d.get("deviceName"))
                .containsExactlyInAnyOrder("Phone A", "Tablet B");
        assertThat(aDays).extracting(UsageHistoryIT::dateOf).containsOnly(DAY_2);
        // Two independent rows, each with its own measurement: nothing is summed.
        assertThat(aDays).extracting(d -> apps(d).getFirst().get("durationSeconds"))
                .containsExactlyInAnyOrder(100, 999);

        List<Map<String, Object>> bDays = allDays(userB);
        assertThat(bDays).hasSize(1);
        assertThat(bDays.getFirst()).contains(entry("deviceId", deviceC.toString()), entry("deviceName", "Phone C"));
        assertThat(apps(bDays.getFirst()).getFirst()).contains(entry("durationSeconds", 777));
    }

    @Test
    void theDeviceFilterNarrowsToThatDevice() {
        Account account = newAccount();
        UUID deviceA = newDevice(account, "Phone A");
        UUID deviceB = newDevice(account, "Tablet B");
        outcomes(account, deviceA, List.of(day(DAY_2, 10, List.of(app("com.a", 1)))));
        outcomes(account, deviceB, List.of(day(DAY_2, 10, List.of(app("com.b", 2)))));

        assertThat(daysOf(read(account, range(DAY_2, DAY_3) + "&deviceId=" + deviceA)))
                .singleElement()
                .satisfies(d -> assertThat(d).contains(entry("deviceId", deviceA.toString())))
                .satisfies(d -> assertThat(apps(d)).singleElement().satisfies(
                        a -> assertThat(a).contains(entry("appKey", "com.a"))));
        assertThat(daysOf(read(account, range(DAY_2, DAY_3) + "&deviceId=" + deviceB)))
                .singleElement()
                .satisfies(d -> assertThat(d).contains(entry("deviceId", deviceB.toString())))
                .satisfies(d -> assertThat(apps(d)).singleElement().satisfies(
                        a -> assertThat(a).contains(entry("appKey", "com.b"))));
    }

    @Test
    void aForeignDeviceFilterIsIndistinguishableFromAnUnknownOneAndWritesNothing() {
        Account userA = newAccount();
        UUID deviceA = newDevice(userA, "Phone A");
        Account userB = newAccount();
        UUID deviceC = newDevice(userB, "Phone C");
        outcomes(userA, deviceA, List.of(day(DAY_2, 10, List.of(app("com.a", 1)))));
        outcomes(userB, deviceC, List.of(day(DAY_2, 10, List.of(app("com.c", 3)))));

        Map<String, Object> beforeRow = dayRow(deviceC, DAY_2);
        List<Map<String, Object>> beforeApps = appRows(deviceC, DAY_2);

        Response unknown = read(userA, range(DAY_2, DAY_3) + "&deviceId=" + UUID.randomUUID());
        Response foreign = read(userA, range(DAY_2, DAY_3) + "&deviceId=" + deviceC);

        // D16: a collection filters. Foreign and unknown produce the same body, byte for byte.
        assertThat(foreign.status()).isEqualTo(unknown.status()).isEqualTo(200);
        assertThat(foreign.body()).isEqualTo(unknown.body());
        assertThat(daysOf(foreign)).isEmpty();
        // No side effect on the owner's rows, and the owner still reads them.
        assertThat(dayRow(deviceC, DAY_2)).isEqualTo(beforeRow);
        assertThat(appRows(deviceC, DAY_2)).isEqualTo(beforeApps);
        assertThat(daysOf(read(userB, range(DAY_2, DAY_3) + "&deviceId=" + deviceC))).hasSize(1);
    }

    /** Plan criterion 13, usage-read half. */
    @Test
    void anAuthenticatedUserCannotReadAnotherUsersUsage() {
        Account userA = newAccount();
        Account userB = newAccount();
        UUID deviceB = newDevice(userB, "Phone B");
        outcomes(userB, deviceB, List.of(
                day(DAY_1, 10, List.of(app("com.private", "Private", 4242, 4))),
                day(DAY_2, 10, List.of(app("com.private", "Private", 4243, 4)))));

        assertThat(allDays(userA)).isEmpty();
        assertThat(daysOf(read(userA, range(DAY_1, DAY_3) + "&deviceId=" + deviceB))).isEmpty();
        assertThat(read(userA, range(DAY_1, DAY_3)).body()).doesNotContain("com.private", deviceB.toString());
        assertThat(allDays(userB)).hasSize(2);
    }

    // --- app data --------------------------------------------------------------------

    @Test
    void appRowsStayWithTheirOwnDeviceAndDate() {
        Account account = newAccount();
        UUID deviceA = newDevice(account, "Phone A");
        UUID deviceB = newDevice(account, "Tablet B");
        outcomes(account, deviceA, List.of(
                day(DAY_1, 10, List.of(app("com.a.one", 11))),
                day(DAY_2, 10, List.of(app("com.a.two", 22)))));
        outcomes(account, deviceB, List.of(day(DAY_1, 10, List.of(app("com.b.one", 33)))));

        assertThat(allDays(account))
                .hasSize(3)
                .allSatisfy(d -> assertThat(apps(d)).hasSize(1))
                .extracting(d -> d.get("deviceId") + "/" + d.get("localDate") + "/" + apps(d).getFirst().get("appKey"))
                .containsExactlyInAnyOrder(
                        deviceA + "/" + DAY_1 + "/com.a.one",
                        deviceA + "/" + DAY_2 + "/com.a.two",
                        deviceB + "/" + DAY_1 + "/com.b.one");
    }

    @Test
    void aDayWithNoAppsIsReturnedWithAnEmptyAppArray() {
        Account account = newAccount();
        UUID device = newDevice(account);
        assertThat(outcomes(account, device, List.of(
                        day(DAY_2, 10, List.of(app("com.gone", 5))),
                        day(DAY_3, 10, List.of()))))
                .containsExactly("APPLIED", "APPLIED");
        // A newer empty snapshot replaces a non-empty one; the read must show that.
        assertThat(outcomes(account, device, List.of(day(DAY_2, 11, List.of())))).containsExactly("APPLIED");

        assertThat(allDays(account))
                .hasSize(2)
                .allSatisfy(d -> assertThat(apps(d)).isEmpty());
        assertThat(read(account, range(DAY_2, DAY_3)).body()).contains("\"apps\":[]");
    }

    @Test
    void theReadReflectsTheStoredSnapshotAfterASupersede() {
        Account account = newAccount();
        UUID device = newDevice(account);
        outcomes(account, device, List.of(day(DAY_2, 10, "partial",
                List.of(app("com.old", "Old", 5, 1), app("com.dropped", "Dropped", 7, 1)))));
        outcomes(account, device, List.of(day(DAY_2, 11, "reconciled", List.of(app("com.old", "New", 9, 2)))));

        Map<String, Object> day = daysOf(read(account, range(DAY_2, DAY_3))).getFirst();
        assertThat(((Number) day.get("snapshotVersion")).longValue()).isEqualTo(11L);
        assertThat(apps(day)).containsExactly(
                Map.of("appKey", "com.old", "appName", "New", "durationSeconds", 9, "launchCount", 2));
    }
}
