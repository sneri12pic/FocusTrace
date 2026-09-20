package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;

/**
 * Concurrent uploads against real PostgreSQL: true parallel HTTP requests released
 * by one latch, repeated for several rounds. Proves the guarded upsert and the
 * equal-version read under contention, not just in sequence (architecture 7.3).
 */
class UsageConcurrencyIT extends UsageTestSupport {

    private static final int ROUNDS = 8;
    private static final LocalDate DAY = LocalDate.of(2026, 9, 10);

    @Test
    void newerVersionAlwaysWinsAgainstOlder() {
        Account a = newAccount();
        for (int round = 0; round < ROUNDS; round++) {
            UUID device = newDevice(a);
            List<Map<String, Object>> older = List.of(day(DAY, 1, apps("old", 3)));
            List<Map<String, Object>> newer = List.of(day(DAY, 2, apps("new", 2)));

            List<Response> responses = race(() -> upload(a, device, older), () -> upload(a, device, newer));

            assertThat(outcomesOf(responses.get(0))).containsAnyOf("APPLIED", "STALE");
            assertThat(outcomesOf(responses.get(1))).containsExactly("APPLIED");
            assertThat(dayRow(device, DAY)).containsEntry("snapshot_version", 2L);
            assertThat(appKeys(device, DAY)).containsExactly("new0", "new1");
        }
    }

    @Test
    void equalIdenticalUploadsApplyOnceAndDuplicateOnce() {
        Account a = newAccount();
        for (int round = 0; round < ROUNDS; round++) {
            UUID device = newDevice(a);
            List<Map<String, Object>> days = List.of(day(DAY, 7, apps("same", 4)));

            List<Response> responses = race(() -> upload(a, device, days), () -> upload(a, device, days));

            assertThat(responses.stream().flatMap(r -> outcomesOf(r).stream()))
                    .containsExactlyInAnyOrder("APPLIED", "DUPLICATE");
            assertThat(appKeys(device, DAY)).containsExactly("same0", "same1", "same2", "same3");
        }
    }

    @Test
    void equalDifferingUploadsPersistOneAndConflictTheOther() {
        Account a = newAccount();
        for (int round = 0; round < ROUNDS; round++) {
            UUID device = newDevice(a);
            List<Map<String, Object>> first = List.of(day(DAY, 7, apps("first", 3)));
            List<Map<String, Object>> second = List.of(day(DAY, 7, apps("second", 2)));

            List<Response> responses = race(() -> upload(a, device, first), () -> upload(a, device, second));

            List<String> outcomes = responses.stream().map(r -> outcomesOf(r).get(0)).toList();
            assertThat(outcomes).containsExactlyInAnyOrder("APPLIED", "CONFLICT");
            List<String> expected = outcomes.get(0).equals("APPLIED")
                    ? List.of("first0", "first1", "first2")
                    : List.of("second0", "second1");
            assertThat(appKeys(device, DAY)).containsExactlyElementsOf(expected);
        }
    }

    /**
     * Four requests over the same ten days, half in ascending and half in
     * descending JSON order. Without the server's internal sort these lock rows in
     * opposite orders and deadlock (a 500).
     */
    @Test
    void overlappingBatchesInOpposingOrderNeitherDeadlockNorMix() {
        Account a = newAccount();
        for (int round = 0; round < ROUNDS; round++) {
            UUID device = newDevice(a);
            List<Supplier<Response>> calls = new ArrayList<>();
            for (int version = 1; version <= 4; version++) {
                List<Map<String, Object>> days = new ArrayList<>();
                for (int d = 0; d < 10; d++) {
                    days.add(day(DAY.plusDays(d), version, apps("v" + version + "-", version)));
                }
                if (version % 2 == 0) {
                    days = days.reversed();
                }
                List<Map<String, Object>> batch = days;
                calls.add(() -> upload(a, device, batch));
            }

            race(calls.toArray(Supplier[]::new));

            for (int d = 0; d < 10; d++) {
                LocalDate date = DAY.plusDays(d);
                long version = (Long) dayRow(device, date).get("snapshot_version");
                // Highest version wins, and its app set is complete and unmixed.
                assertThat(version).isEqualTo(4L);
                assertThat(appKeys(device, date)).containsExactly("v4-0", "v4-1", "v4-2", "v4-3");
            }
            assertThat(appCount(device)).isEqualTo(40);
        }
    }
}
