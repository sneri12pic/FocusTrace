package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.ByteArrayInputStream;
import java.math.BigInteger;
import java.net.http.HttpRequest;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;

/**
 * Phase 1 Step 4 against real PostgreSQL: the upload contract (architecture 9.1/9.2),
 * version outcomes (7.3), request-wide validation with zero writes, D16 ownership,
 * rollback, and the Jackson document-length bound.
 */
class UsageUploadIT extends UsageTestSupport {

    private static final LocalDate D1 = LocalDate.of(2026, 9, 1);
    private static final LocalDate D2 = LocalDate.of(2026, 9, 2);
    private static final LocalDate D3 = LocalDate.of(2026, 9, 3);

    // --- contract and version outcomes -----------------------------------------

    @Test
    void newDayIsAppliedAndPersistedExactly() {
        Account a = newAccount();
        UUID device = newDevice(a);

        Response response = upload(a, device, List.of(day(D1, 5, "partial", List.of(
                app("com.example.a", "Example A", 2840, 12), app("com.example.b", "Example B", 90_000, 0)))));

        assertThat(response.status()).as(response.body()).isEqualTo(200);
        assertThat(response.json()).containsOnlyKeys("results");
        assertThat(response.json().get("results")).isEqualTo(
                List.of(Map.of("localDate", "2026-09-01", "outcome", "APPLIED", "storedVersion", 5)));
        assertThat(dayRow(device, D1)).containsEntry("snapshot_version", 5L)
                .containsEntry("timezone_id", "Europe/London")
                .containsEntry("source_status", "partial");
        assertThat(appRows(device, D1)).containsExactly(
                Map.of("app_key", "com.example.a", "app_name", "Example A", "duration_seconds", 2840, "launch_count", 12),
                Map.of("app_key", "com.example.b", "app_name", "Example B", "duration_seconds", 90_000, "launch_count", 0));
    }

    @Test
    void unsortedRequestIsAnsweredInRequestOrder() {
        // Processed internally in ascending date order (lock order); answered in request order.
        Account a = newAccount();
        UUID device = newDevice(a);
        LocalDate sep8 = LocalDate.of(2026, 9, 8);
        LocalDate sep9 = LocalDate.of(2026, 9, 9);
        LocalDate sep10 = LocalDate.of(2026, 9, 10);
        outcomes(a, device, List.of(day(sep8, 5, List.of(app("kept", 1)))));

        Response response = upload(a, device, List.of(
                day(sep10, 3, List.of(app("ten", 10))),
                day(sep8, 4, List.of(app("stale", 8))),
                day(sep9, 2, List.of(app("nine", 9)))));

        assertThat(response.status()).as(response.body()).isEqualTo(200);
        assertThat(response.json().get("results")).isEqualTo(List.of(
                Map.of("localDate", "2026-09-10", "outcome", "APPLIED", "storedVersion", 3),
                Map.of("localDate", "2026-09-08", "outcome", "STALE", "storedVersion", 5),
                Map.of("localDate", "2026-09-09", "outcome", "APPLIED", "storedVersion", 2)));
        assertThat(appKeys(device, sep8)).containsExactly("kept");
        assertThat(appKeys(device, sep9)).containsExactly("nine");
        assertThat(appKeys(device, sep10)).containsExactly("ten");
        assertThat(dayRow(device, sep10)).containsEntry("snapshot_version", 3L);
    }

    @Test
    void higherVersionReplacesTheWholeDay() {
        Account a = newAccount();
        UUID device = newDevice(a);
        outcomes(a, device, List.of(day(D1, 1, List.of(app("old.a", 100), app("old.b", 200)))));

        assertThat(outcomes(a, device, List.of(day(D1, 2, "partial", List.of(app("new.c", 300))))))
                .containsExactly("APPLIED");

        assertThat(dayRow(device, D1)).containsEntry("snapshot_version", 2L).containsEntry("source_status", "partial");
        assertThat(appKeys(device, D1)).containsExactly("new.c");
        assertThat(appCount(device)).isEqualTo(1);
    }

    @Test
    void newerEmptySnapshotReplacesOlderNonEmptyOne() {
        Account a = newAccount();
        UUID device = newDevice(a);
        outcomes(a, device, List.of(day(D1, 1, apps("a", 3))));

        assertThat(outcomes(a, device, List.of(day(D1, 2, List.of())))).containsExactly("APPLIED");

        assertThat(dayRow(device, D1)).containsEntry("snapshot_version", 2L);
        assertThat(appCount(device)).isZero();
    }

    @Test
    void lowerVersionIsStaleAndWritesNothing() {
        Account a = newAccount();
        UUID device = newDevice(a);
        outcomes(a, device, List.of(day(D1, 2, List.of(app("kept", 100)))));
        Map<String, Object> before = dayRow(device, D1);

        Response response = upload(a, device, List.of(day(D1, 1, List.of(app("lost", 1)))));

        assertThat(response.json().get("results")).isEqualTo(
                List.of(Map.of("localDate", "2026-09-01", "outcome", "STALE", "storedVersion", 2)));
        assertThat(dayRow(device, D1)).isEqualTo(before);
        assertThat(appKeys(device, D1)).containsExactly("kept");
    }

    @Test
    void equalVersionSameContentIsDuplicateRegardlessOfAppOrder() {
        Account a = newAccount();
        UUID device = newDevice(a);
        List<Map<String, Object>> apps = List.of(app("a", "A", 10, 1), app("b", "B", 20, 2), app("c", "C", 30, 3));
        outcomes(a, device, List.of(day(D1, 2, apps)));
        Map<String, Object> dayBefore = dayRow(device, D1);
        List<Map<String, Object>> appsBefore = appRows(device, D1);

        List<Map<String, Object>> reordered = List.of(apps.get(2), apps.get(0), apps.get(1));
        Response response = upload(a, device, List.of(day(D1, 2, reordered)));

        assertThat(response.json().get("results")).isEqualTo(
                List.of(Map.of("localDate", "2026-09-01", "outcome", "DUPLICATE", "storedVersion", 2)));
        assertThat(dayRow(device, D1)).isEqualTo(dayBefore); // received_at included
        assertThat(appRows(device, D1)).isEqualTo(appsBefore);
    }

    @Test
    void equalVersionDifferentContentIsConflictAndWritesNothing() {
        Account a = newAccount();
        UUID device = newDevice(a);
        List<Map<String, Object>> apps = List.of(app("a", "A", 10, 1), app("b", "B", 20, 2));
        outcomes(a, device, List.of(day(D1, 2, apps)));
        Map<String, Object> dayBefore = dayRow(device, D1);
        List<Map<String, Object>> appsBefore = appRows(device, D1);

        List<Map<String, Object>> variants = new ArrayList<>();
        variants.add(day(D1, 2, List.of(app("a", "A", 11, 1), app("b", "B", 20, 2))));       // duration
        variants.add(day(D1, 2, List.of(app("a", "A", 10, 9), app("b", "B", 20, 2))));       // launchCount
        variants.add(day(D1, 2, List.of(app("a", "A2", 10, 1), app("b", "B", 20, 2))));      // appName
        variants.add(day(D1, 2, List.of(app("a", "A", 10, 1))));                             // app removed
        variants.add(day(D1, 2, List.of(app("a", "A", 10, 1), app("b", "B", 20, 2), app("c", 0)))); // app added
        variants.add(day(D1, 2, List.of(app("a", "A", 10, 1), app("x", "B", 20, 2))));       // appKey
        variants.add(day(D1, 2, List.of()));                                                 // emptied
        variants.add(day(D1, 2, "partial", apps));                                           // sourceStatus
        Map<String, Object> otherZone = new HashMap<>(day(D1, 2, apps));
        otherZone.put("timezoneId", "Europe/Paris");
        variants.add(otherZone);                                                             // timezoneId

        for (Map<String, Object> variant : variants) {
            Response response = upload(a, device, List.of(variant));
            assertThat(response.json().get("results")).as(variant.toString()).isEqualTo(
                    List.of(Map.of("localDate", "2026-09-01", "outcome", "CONFLICT", "storedVersion", 2)));
        }
        assertThat(dayRow(device, D1)).isEqualTo(dayBefore);
        assertThat(appRows(device, D1)).isEqualTo(appsBefore);
    }

    @Test
    void outcomesAreIndependentWithinOneRequest() {
        Account a = newAccount();
        UUID device = newDevice(a);
        LocalDate d4 = LocalDate.of(2026, 9, 4);
        outcomes(a, device, List.of(
                day(D1, 5, List.of(app("x", 1))), day(D2, 5, List.of(app("x", 1))), day(D3, 5, List.of(app("x", 1)))));

        List<String> outcomes = outcomes(a, device, List.of(
                day(D1, 4, List.of(app("y", 1))),   // older
                day(D2, 5, List.of(app("x", 1))),   // same
                day(D3, 5, List.of(app("y", 1))),   // same version, different
                day(d4, 1, List.of(app("y", 1))))); // new

        assertThat(outcomes).containsExactly("STALE", "DUPLICATE", "CONFLICT", "APPLIED");
        assertThat(appKeys(device, D1)).containsExactly("x");
        assertThat(appKeys(device, D3)).containsExactly("x");
        assertThat(appKeys(device, d4)).containsExactly("y");
    }

    // --- request limits: accepted boundaries -------------------------------------

    @Test
    void acceptsEveryUpperAndLowerBoundary() {
        Account a = newAccount();

        List<Map<String, Object>> days31 = new ArrayList<>();
        for (int i = 0; i < 31; i++) {
            days31.add(day(D1.minusDays(i), 1, apps("a", 1)));
        }
        assertThat(outcomes(a, newDevice(a), days31)).hasSize(31).containsOnly("APPLIED");

        UUID device500 = newDevice(a);
        outcomes(a, device500, List.of(day(D1, 1, apps("a", 500))));
        assertThat(appCount(device500)).isEqualTo(500);

        UUID device1000 = newDevice(a);
        outcomes(a, device1000, List.of(day(D1, 1, apps("a", 500)), day(D2, 1, apps("a", 500))));
        assertThat(appCount(device1000)).isEqualTo(1000);

        UUID edges = newDevice(a);
        assertThat(outcomes(a, edges, List.of(
                day(LocalDate.of(2026, 1, 1), 1, List.of(app("zero", 0), app("max", 90_000))),
                day(TODAY.plusDays(1), 1, List.of(app("k".repeat(255), "n".repeat(200), 1, Integer.MAX_VALUE))),
                day(TODAY, Long.MAX_VALUE, "imported", List.of()))))
                .containsExactly("APPLIED", "APPLIED", "APPLIED");
        assertThat(dayRow(edges, TODAY)).containsEntry("snapshot_version", Long.MAX_VALUE);
    }

    // --- request limits: every rejection is a 400 with zero writes ----------------

    @Test
    void rejectsCountLimits() {
        List<Map<String, Object>> days32 = new ArrayList<>();
        for (int i = 0; i < 32; i++) {
            days32.add(day(D1.minusDays(i), 1, apps("a", 1)));
        }
        assertRejected(days32);
        assertRejected(List.of(day(D1, 1, apps("a", 501))));
        assertRejected(List.of(day(D1, 1, apps("a", 500)), day(D2, 1, apps("a", 500)), day(D3, 1, apps("a", 1))));
        assertRejected(List.of());
    }

    @Test
    @SuppressWarnings("unchecked")
    void rejectsOutOfRangeNumbers() {
        assertRejected(List.of(day(D1, 1, List.of(app("a", 90_001)))));
        assertRejected(List.of(day(D1, 1, List.of(app("a", -1)))));
        assertRejected(List.of(day(D1, 1, List.of(app("a", "A", 1, -1)))));
        assertRejected(List.of(day(D1, 0, apps("a", 1))));
        assertRejected(List.of(day(D1, -1, apps("a", 1))));
        assertRejectedDay(d -> ((Map<String, Object>) ((List<?>) d.get("apps")).get(0)).put("launchCount", 2_147_483_648L));
        assertRejectedDay(d -> d.put("snapshotVersion", new BigInteger("9223372036854775808")));
    }

    @Test
    void rejectsDatesOutsideTheSyncRange() {
        // A valid earlier day in the same batch proves validation precedes every write.
        assertRejected(List.of(day(D1, 1, apps("a", 1)), day(LocalDate.of(2025, 12, 31), 1, apps("a", 1))));
        assertRejected(List.of(day(D1, 1, apps("a", 1)), day(TODAY.plusDays(2), 1, apps("a", 1))));
        assertRejectedDay(d -> d.put("localDate", "2026-02-30"));
        assertRejectedDay(d -> d.put("localDate", "20260901"));
        assertRejectedDay(d -> d.remove("localDate"));
    }

    @Test
    void rejectsDuplicates() {
        assertRejected(List.of(day(D1, 1, apps("a", 1)), day(D1, 2, apps("b", 1))));
        assertRejected(List.of(day(D1, 1, List.of(app("same", 1), app("other", 2), app("same", 1)))));
    }

    @Test
    void rejectsBadTimezoneAndStatus() {
        assertRejectedDay(d -> d.put("timezoneId", "Mars/Olympus_Mons"));
        assertRejectedDay(d -> d.put("timezoneId", ""));
        assertRejectedDay(d -> d.put("timezoneId", "Europe/London" + " ".repeat(52))); // 65 units
        assertRejectedDay(d -> d.remove("timezoneId"));
        assertRejectedDay(d -> d.put("sourceStatus", "unavailable"));
        assertRejectedDay(d -> d.put("sourceStatus", "Reconciled"));
        assertRejectedDay(d -> d.put("sourceStatus", null));
    }

    @Test
    void rejectsBadStrings() {
        assertRejected(List.of(day(D1, 1, List.of(app("k".repeat(256), 1)))));
        assertRejected(List.of(day(D1, 1, List.of(app("a", "n".repeat(201), 1, 1)))));
        assertRejected(List.of(day(D1, 1, List.of(app(" ", 1)))));
        assertRejected(List.of(day(D1, 1, List.of(app("a", "", 1, 1)))));
        assertRejected(List.of(day(D1, 1, List.of(app("a", "Nul\u0000Name", 1, 1)))));
        assertRejected(List.of(day(D1, 1, List.of(app("key\u0000", 1)))));
        // Sent as JSON escapes: a Java client would never serialize a lone surrogate.
        assertRejected(List.of(day(D1, 1, List.of(app("a", "Lone @@ surrogate", 1, 1)))), "\\ud800");
        assertRejected(List.of(day(D1, 1, List.of(app("lone@@", 1)))), "\\udc00");
        assertRejected(List.of(day(D1, 1, List.of(app("a", "Nul@@", 1, 1)))), "\\u0000");
    }

    /** Only NUL and lone surrogates are refused; other control characters are stored verbatim. */
    @Test
    void storesOtherControlCharactersExactlyAndRetriesAsDuplicate() {
        Account a = newAccount();
        UUID device = newDevice(a);
        List<Map<String, Object>> days = List.of(day(D1, 1, List.of(
                app("key\twith\u007fcontrols", "Line one\nline two\r\u001b", 1, 1),
                app("emoji-😀", "Paired 😀 surrogates", 2, 1))));

        assertThat(outcomes(a, device, days)).containsExactly("APPLIED");
        assertThat(appRows(device, D1)).extracting(r -> r.get("app_key"), r -> r.get("app_name")).containsExactly(
                org.assertj.core.groups.Tuple.tuple("emoji-😀", "Paired 😀 surrogates"),
                org.assertj.core.groups.Tuple.tuple("key\twith\u007fcontrols", "Line one\nline two\r\u001b"));
        assertThat(outcomes(a, device, days)).containsExactly("DUPLICATE");
    }

    @Test
    @SuppressWarnings("unchecked")
    void rejectsMissingOrUnknownFields() {
        assertRejectedDay(d -> d.put("apps", null));
        assertRejectedDay(d -> ((List<Object>) d.get("apps")).add(null));
        assertRejectedDay(d -> d.put("ownerId", UUID.randomUUID().toString()));

        Account a = newAccount();
        UUID device = newDevice(a);
        Map<String, Object> withUser = new HashMap<>(body(device, List.of(day(D1, 1, apps("a", 1)))));
        withUser.put("userId", UUID.randomUUID().toString());
        assertThat(upload(a.token(), withUser).status()).isEqualTo(400);
        assertThat(upload(a.token(), Map.of("days", List.of(day(D1, 1, apps("a", 1))))).status()).isEqualTo(400);
        assertThat(putJson(UPLOAD, "{\"deviceId\":", a.token()).status()).isEqualTo(400);
        assertThat(dayCount(device)).isZero();
    }

    /** One otherwise-valid day, mutated. */
    @SuppressWarnings("unchecked")
    private void assertRejectedDay(Consumer<Map<String, Object>> mutation) {
        Map<String, Object> day = new HashMap<>(day(D1, 1, new ArrayList<>(List.of(new HashMap<>(app("a", 1))))));
        mutation.accept(day);
        assertRejected(List.of(day));
    }

    private void assertRejected(List<Map<String, Object>> days) {
        assertRejected(days, "@@");
    }

    /** {@code @@} in any string is replaced by {@code rawJson} after serialization. */
    private void assertRejected(List<Map<String, Object>> days, String rawJson) {
        Account a = newAccount();
        UUID device = newDevice(a);
        Response response = putJson(UPLOAD, JSON.writeValueAsString(body(device, days)).replace("@@", rawJson),
                a.token());
        assertThat(response.status()).as(response.body()).isEqualTo(400);
        assertThat(response.body()).doesNotContain("Exception").doesNotContain("at com.");
        assertThat(dayCount(device)).isZero();
        assertThat(appCount(device)).isZero();
    }

    // --- authorization (D16) -------------------------------------------------------

    @Test
    void unauthenticatedUploadIsRejectedWithoutSideEffect() {
        Account a = newAccount();
        UUID device = newDevice(a);
        Map<String, Object> body = body(device, List.of(day(D1, 1, apps("a", 1))));

        assertThat(upload((String) null, body).status()).isEqualTo(401);
        assertThat(upload("not-a-jwt", body).status()).isEqualTo(401);
        assertThat(dayCount(device)).isZero();
    }

    @Test
    void foreignDeviceIsIndistinguishableFromUnknownAndUntouched() {
        Account a = newAccount();
        Account b = newAccount();
        UUID aDevice = newDevice(a);
        outcomes(a, aDevice, List.of(day(D1, 5, List.of(app("mine", 100)))));
        Map<String, Object> deviceBefore = jdbc.queryForMap("SELECT * FROM devices WHERE id = ?", aDevice);
        Map<String, Object> dayBefore = dayRow(aDevice, D1);
        List<Map<String, Object>> appsBefore = appRows(aDevice, D1);

        // A higher version and a new date: both would apply if ownership were not enforced.
        List<Map<String, Object>> attack = List.of(day(D1, 9, List.of(app("theirs", 1))), day(D2, 1, apps("t", 1)));
        Response foreign = upload(b, aDevice, attack);
        Response unknown = upload(b, UUID.randomUUID(), attack);

        assertThat(foreign.status()).isEqualTo(404);
        assertThat(foreign.body()).isEqualTo(unknown.body());
        assertThat(foreign.header("Content-Type")).isEqualTo(unknown.header("Content-Type"));
        assertThat(foreign.body()).doesNotContain(aDevice.toString()).doesNotContain(a.id().toString());
        assertThat(jdbc.queryForMap("SELECT * FROM devices WHERE id = ?", aDevice)).isEqualTo(deviceBefore);
        assertThat(dayRow(aDevice, D1)).isEqualTo(dayBefore);
        assertThat(appRows(aDevice, D1)).isEqualTo(appsBefore);
        assertThat(dayCount(aDevice)).isEqualTo(1);

        // A still owns and reaches it.
        assertThat(outcomes(a, aDevice, List.of(day(D1, 6, apps("m", 1))))).containsExactly("APPLIED");
    }

    @Test
    void sameDateStaysIndependentAcrossDevicesAndAccounts() {
        Account a = newAccount();
        Account b = newAccount();
        UUID a1 = newDevice(a);
        UUID a2 = newDevice(a);
        UUID b1 = newDevice(b);

        outcomes(a, a1, List.of(day(D1, 1, List.of(app("app", 100)))));
        outcomes(a, a2, List.of(day(D1, 1, List.of(app("app", 200)))));
        outcomes(b, b1, List.of(day(D1, 1, List.of(app("app", 300)))));
        // A newer version on one device does not touch the others.
        outcomes(a, a1, List.of(day(D1, 2, List.of(app("app", 111)))));

        assertThat(appRows(a1, D1)).extracting(r -> r.get("duration_seconds")).containsExactly(111);
        assertThat(appRows(a2, D1)).extracting(r -> r.get("duration_seconds")).containsExactly(200);
        assertThat(appRows(b1, D1)).extracting(r -> r.get("duration_seconds")).containsExactly(300);
        assertThat(dayRow(a2, D1)).containsEntry("snapshot_version", 1L);
        assertThat(dayRow(b1, D1)).containsEntry("snapshot_version", 1L);
    }

    // --- transactionality ------------------------------------------------------------

    /** Fails any insert of this app key inside the database, after earlier statements ran. */
    private static final String FAILING_KEY = "force-failure-7d1e";

    private void withForcedInsertFailure(Runnable body) {
        jdbc.execute("""
                CREATE FUNCTION test_force_failure() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN
                    IF NEW.app_key = '%s' THEN RAISE EXCEPTION 'forced test failure'; END IF;
                    RETURN NEW;
                END $$""".formatted(FAILING_KEY));
        jdbc.execute("CREATE TRIGGER test_force_failure BEFORE INSERT ON usage_day_apps "
                + "FOR EACH ROW EXECUTE FUNCTION test_force_failure()");
        try {
            body.run();
        } finally {
            jdbc.execute("DROP TRIGGER test_force_failure ON usage_day_apps");
            jdbc.execute("DROP FUNCTION test_force_failure()");
        }
    }

    @Test
    void failureOnALaterDayRollsBackEarlierDays() {
        Account a = newAccount();
        UUID device = newDevice(a);

        withForcedInsertFailure(() -> {
            Response response = upload(a, device, List.of(
                    day(D1, 1, apps("a", 3)), day(D2, 1, apps("b", 2)), day(D3, 1, List.of(app(FAILING_KEY, 1)))));
            assertThat(response.status()).isEqualTo(500);
            assertThat(response.body()).doesNotContain("forced test failure");
        });

        assertThat(dayCount(device)).isZero();
        assertThat(appCount(device)).isZero();
    }

    @Test
    void failureAfterDeletingOldAppsRestoresTheWholeDay() {
        Account a = newAccount();
        UUID device = newDevice(a);
        outcomes(a, device, List.of(day(D1, 1, List.of(app("old.a", 10), app("old.b", 20)))));
        Map<String, Object> dayBefore = dayRow(device, D1);
        List<Map<String, Object>> appsBefore = appRows(device, D1);

        // Metadata upsert and child delete succeed; the child insert then fails.
        withForcedInsertFailure(() -> assertThat(upload(a, device, List.of(
                day(D1, 2, List.of(app("new.a", 1), app(FAILING_KEY, 1))))).status()).isEqualTo(500));

        assertThat(dayRow(device, D1)).isEqualTo(dayBefore);
        assertThat(appRows(device, D1)).isEqualTo(appsBefore);
    }

    // --- Jackson document-length bound ----------------------------------------------

    @Test
    void largestContractRequestFitsTheDocumentLimit() {
        Account a = newAccount();
        UUID device = newDevice(a);
        // 31 days, 1000 rows, every string at its maximum in 3-byte UTF-8 characters.
        List<Map<String, Object>> days = new ArrayList<>();
        for (int d = 0; d < 31; d++) {
            List<Map<String, Object>> apps = new ArrayList<>();
            for (int i = 0; i < (d < 8 ? 33 : 32); i++) {
                String key = i + "-" + "界".repeat(255 - (i + "-").length());
                apps.add(app(key, "界".repeat(200), 90_000, Integer.MAX_VALUE));
            }
            Map<String, Object> day = day(TODAY.plusDays(1).minusDays(d), Long.MAX_VALUE, apps);
            day.put("timezoneId", "America/Argentina/ComodRivadavia");
            days.add(day);
        }
        String json = JSON.writeValueAsString(body(device, days));
        assertThat(json.getBytes(StandardCharsets.UTF_8).length).isBetween(1_400_000, 2_097_152);

        Response response = putJson(UPLOAD, json, a.token());

        assertThat(response.status()).as(response.body()).isEqualTo(200);
        assertThat(outcomesOf(response)).hasSize(31).containsOnly("APPLIED");
        assertThat(appCount(device)).isEqualTo(1000);
    }

    @Test
    void oversizedDocumentIsRejectedWithOrWithoutContentLength() {
        Account a = newAccount();
        UUID device = newDevice(a);
        // Structurally valid and within every count bound; only its length is over.
        String json = JSON.writeValueAsString(body(device, List.of(day(D1, 1, apps("a", 1)))))
                .replaceFirst("\\{", "{" + " ".repeat(3 * 1024 * 1024));
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);

        Response sized = putJson(UPLOAD, json, a.token());
        Response chunked = send(request(UPLOAD, a.token(), Map.of())
                .header("Content-Type", "application/json")
                .PUT(HttpRequest.BodyPublishers.ofInputStream(() -> new ByteArrayInputStream(bytes)))
                .build());

        assertThat(sized.status()).as(sized.body()).isEqualTo(400);
        assertThat(chunked.status()).as(chunked.body()).isEqualTo(400);
        assertThat(sized.body()).doesNotContain("StreamConstraints").doesNotContain("Document length");
        assertThat(dayCount(device)).isZero();
    }
}
