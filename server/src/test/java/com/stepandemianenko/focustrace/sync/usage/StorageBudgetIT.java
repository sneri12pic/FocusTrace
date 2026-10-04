package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/**
 * D18 stored-day budget against real PostgreSQL, set to six days per account. A
 * request that would create days beyond the budget is refused whole with 403 and
 * leaves storage byte-for-byte unchanged; anything that does not create a day is
 * unaffected by the budget.
 */
@TestPropertySource(properties = "focustrace.sync.max-stored-days=" + StorageBudgetIT.BUDGET)
class StorageBudgetIT extends UsageTestSupport {

    static final int BUDGET = 6;
    private static final LocalDate START = LocalDate.of(2026, 9, 1);

    /** {@code count} consecutive new days from {@code first}, each with two apps. */
    private static List<Map<String, Object>> days(LocalDate first, int count, long version) {
        List<Map<String, Object>> days = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            days.add(day(first.plusDays(i), version, apps("app", 2)));
        }
        return days;
    }

    private int storedDays(Account account) {
        return jdbc.queryForObject("""
                SELECT count(*) FROM usage_days d JOIN devices dev ON dev.id = d.device_id
                 WHERE dev.user_id = ?""", Integer.class, account.id());
    }

    /** Every usage row the account has, for before/after equality. */
    private List<Map<String, Object>> snapshot(Account account) {
        return jdbc.queryForList("""
                SELECT d.device_id, d.local_date, d.snapshot_version, d.received_at,
                       a.app_key, a.app_name, a.duration_seconds, a.launch_count
                  FROM usage_days d
                  JOIN devices dev ON dev.id = d.device_id
                  LEFT JOIN usage_day_apps a ON a.device_id = d.device_id AND a.local_date = d.local_date
                 WHERE dev.user_id = ?
                 ORDER BY d.device_id, d.local_date, a.app_key""", account.id());
    }

    private void assertRefused(Response response) {
        assertThat(response.status()).as(response.body()).isEqualTo(403);
        assertThat(response.header("Content-Type")).startsWith("application/problem+json");
        assertThat(response.json()).containsEntry("status", 403).doesNotContainKey("results");
    }

    @Test
    void storesUpToTheBudgetExactly() {
        Account a = newAccount();
        UUID device = newDevice(a);

        assertThat(outcomes(a, device, days(START, BUDGET - 1, 1))).containsOnly("APPLIED");
        assertThat(outcomes(a, device, days(START.plusDays(BUDGET - 1), 1, 1))).containsExactly("APPLIED");

        assertThat(storedDays(a)).isEqualTo(BUDGET);
    }

    @Test
    void aRequestThatWouldExceedTheBudgetIsRefusedWholeAndChangesNothing() {
        Account a = newAccount();
        UUID device = newDevice(a);
        outcomes(a, device, days(START, BUDGET - 2, 1));
        List<Map<String, Object>> before = snapshot(a);

        // Two replacements (would be APPLIED) plus three new days: 4 + 3 > 6.
        List<Map<String, Object>> request = new ArrayList<>(days(START, 2, 2));
        request.addAll(days(START.plusDays(BUDGET), 3, 1));
        assertRefused(upload(a, device, request));

        assertThat(snapshot(a)).isEqualTo(before);
        // The same request trimmed to fit is accepted.
        request.removeLast();
        assertThat(outcomes(a, device, request)).containsExactly("APPLIED", "APPLIED", "APPLIED", "APPLIED");
        assertThat(storedDays(a)).isEqualTo(BUDGET);
    }

    @Test
    void atTheBudgetEveryOutcomeThatCreatesNoDayIsUnaffected() {
        Account a = newAccount();
        UUID device = newDevice(a);
        outcomes(a, device, days(START, BUDGET, 5));

        assertThat(outcomes(a, device, List.of(day(START, 6, apps("newer", 3))))).containsExactly("APPLIED");
        assertThat(outcomes(a, device, List.of(day(START, 6, apps("newer", 3))))).containsExactly("DUPLICATE");
        assertThat(outcomes(a, device, List.of(day(START, 4, apps("older", 1))))).containsExactly("STALE");
        assertThat(outcomes(a, device, List.of(day(START, 6, apps("other", 1))))).containsExactly("CONFLICT");
        assertThat(appKeys(device, START)).containsExactly("newer0", "newer1", "newer2");

        List<Map<String, Object>> before = snapshot(a);
        assertRefused(upload(a, device, List.of(day(START.plusDays(BUDGET), 1, apps("app", 1)))));
        assertThat(snapshot(a)).isEqualTo(before);
    }

    @Test
    void theBudgetSpansAllOfTheAccountsDevices() {
        Account a = newAccount();
        UUID phone = newDevice(a, "Phone");
        UUID tablet = newDevice(a, "Tablet");
        outcomes(a, phone, days(START, BUDGET - 2, 1));

        assertRefused(upload(a, tablet, days(START, 3, 1)));
        assertThat(dayCount(tablet)).isZero();

        assertThat(outcomes(a, tablet, days(START, 2, 1))).containsOnly("APPLIED");
        assertThat(storedDays(a)).isEqualTo(BUDGET);
    }

    @Test
    void oneAccountAtTheBudgetDoesNotAffectAnother() {
        Account a = newAccount();
        Account b = newAccount();
        UUID aDevice = newDevice(a);
        UUID bDevice = newDevice(b);
        outcomes(a, aDevice, days(START, BUDGET, 1));
        assertRefused(upload(a, aDevice, days(START.plusDays(BUDGET), 1, 1)));

        assertThat(outcomes(b, bDevice, days(START, BUDGET, 1))).containsOnly("APPLIED");
        assertThat(storedDays(b)).isEqualTo(BUDGET);
    }

    /**
     * Four devices each race one new day into the last free slot. The test holds the
     * account row in {@code NO KEY UPDATE}, which lets each upload take its D19
     * {@code KEY SHARE} and write its day, so all four are queued at the budget check
     * at once; releasing it admits exactly one and rolls the rest back whole.
     */
    @Test
    void concurrentUploadsForTheLastSlotAdmitExactlyOne() throws Exception {
        for (int round = 0; round < 3; round++) {
            Account a = newAccount();
            UUID first = newDevice(a, "Seed");
            outcomes(a, first, days(START, BUDGET - 1, 1));
            List<UUID> racers = new ArrayList<>();
            for (int i = 0; i < 4; i++) {
                racers.add(newDevice(a, "Racer " + i));
            }
            LocalDate date = START.plusDays(BUDGET);

            List<Integer> statuses;
            try (Connection lock = lockAccount(a.id(), "FOR NO KEY UPDATE");
                    ExecutorService pool = Executors.newFixedThreadPool(4)) {
                List<CompletableFuture<Response>> requests = new ArrayList<>();
                for (UUID device : racers) {
                    requests.add(CompletableFuture.supplyAsync(
                            () -> upload(a, device, List.of(day(date, 1, apps("app", 3)))), pool));
                }
                awaitLockWaiters(4, requests);
                lock.commit();
                statuses = requests.stream().map(f -> f.join().status()).toList();
            }

            assertThat(statuses).containsExactlyInAnyOrder(200, 403, 403, 403);
            assertThat(storedDays(a)).isEqualTo(BUDGET);
            assertThat(racers.stream().mapToInt(this::appCount).sum()).isEqualTo(3);
        }
    }
}
