package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.http.HttpRequest;
import java.sql.Connection;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;

/**
 * Architecture 9.5 against real PostgreSQL: renaming and removing a device. Lives
 * beside the usage tests because removal is proven by the synced history it takes
 * with it.
 */
class DeviceManagementIT extends UsageTestSupport {

    private static final String DEVICES = "/api/v1/devices";
    private static final LocalDate DAY = LocalDate.of(2026, 9, 10);

    private Response rename(Account account, UUID deviceId, String name) {
        return rename(account.token(), deviceId.toString(), JSON.writeValueAsString(Map.of("displayName", name)));
    }

    private Response rename(String token, String deviceId, String json) {
        return send(request(DEVICES + "/" + deviceId, token, Map.of())
                .header("Content-Type", "application/json")
                .method("PATCH", HttpRequest.BodyPublishers.ofString(json))
                .build());
    }

    private Response remove(Account account, UUID deviceId) {
        return remove(account.token(), deviceId.toString());
    }

    private Response remove(String token, String deviceId) {
        return send(request(DEVICES + "/" + deviceId, token, Map.of()).DELETE().build());
    }

    private Response reRegister(Account account, UUID deviceId, String name) {
        return post(DEVICES, Map.of("deviceId", deviceId.toString(), "displayName", name, "platform", "android"),
                account.token());
    }

    private Map<String, Object> deviceRow(UUID deviceId) {
        return jdbc.queryForMap("SELECT * FROM devices WHERE id = ?", deviceId);
    }

    private int deviceCount(UUID deviceId) {
        return jdbc.queryForObject("SELECT count(*) FROM devices WHERE id = ?", Integer.class, deviceId);
    }

    // --- rename ---------------------------------------------------------------------

    @Test
    void renameReturnsTheDeviceAndKeepsLastSeen() {
        Account a = newAccount();
        UUID phone = newDevice(a, "SM-A366B");
        Object lastSeen = deviceRow(phone).get("last_seen_at");

        Response response = rename(a, phone, "Work phone");

        assertThat(response.status()).as(response.body()).isEqualTo(200);
        assertThat(response.json()).containsOnlyKeys("deviceId", "displayName", "platform", "registeredAt", "lastSeenAt")
                .containsEntry("deviceId", phone.toString())
                .containsEntry("displayName", "Work phone");
        assertThat(deviceRow(phone)).containsEntry("display_name", "Work phone")
                .containsEntry("display_name_by_user", true)
                .containsEntry("last_seen_at", lastSeen);
    }

    /** The client re-registers with Build.MODEL on every sync run; that must not undo a rename. */
    @Test
    void aRenameSurvivesReRegistrationWhileAClientNameStillUpdates() {
        Account a = newAccount();
        UUID renamed = newDevice(a, "SM-A366B");
        UUID untouched = newDevice(a, "Pixel 7");
        assertThat(rename(a, renamed, "Work phone").status()).isEqualTo(200);

        Response again = reRegister(a, renamed, "SM-A366B");
        assertThat(again.status()).as(again.body()).isEqualTo(200);
        assertThat(again.string("displayName")).isEqualTo("Work phone");

        assertThat(reRegister(a, untouched, "Pixel 7a").string("displayName")).isEqualTo("Pixel 7a");
        assertThat(deviceRow(untouched)).containsEntry("display_name_by_user", false);
    }

    @Test
    void renamingAnotherAccountsOrAnUnknownDeviceIs404AndChangesNothing() {
        Account a = newAccount();
        Account b = newAccount();
        UUID phone = newDevice(a, "SM-A366B");

        assertThat(rename(b, phone, "Mine now").status()).isEqualTo(404);
        assertThat(rename(b, UUID.randomUUID(), "Nobody").status()).isEqualTo(404);
        assertThat(deviceRow(phone)).containsEntry("display_name", "SM-A366B")
                .containsEntry("display_name_by_user", false);
    }

    @Test
    void invalidRenamesAre400AndUnauthenticatedOnesAre401() {
        Account a = newAccount();
        UUID phone = newDevice(a, "SM-A366B");

        assertThat(rename(a, phone, " ").status()).isEqualTo(400);
        assertThat(rename(a, phone, "x".repeat(101)).status()).isEqualTo(400);
        assertThat(rename(a, phone, "tab\there").status()).isEqualTo(400);
        assertThat(rename(a.token(), phone.toString(), "{\"displayName\":\"A\",\"userId\":\"x\"}").status())
                .isEqualTo(400);
        assertThat(rename(a.token(), "not-a-uuid", "{\"displayName\":\"A\"}").status()).isEqualTo(400);
        assertThat(rename(null, phone.toString(), "{\"displayName\":\"A\"}").status()).isEqualTo(401);
        assertThat(deviceRow(phone)).containsEntry("display_name", "SM-A366B");
    }

    // --- remove ---------------------------------------------------------------------

    @Test
    void removeDeletesTheDeviceAndItsHistoryOnly() {
        Account a = newAccount();
        UUID old = newDevice(a, "Old phone");
        UUID current = newDevice(a, "New phone");
        assertThat(outcomes(a, old, List.of(day(DAY, 1, apps("o", 3))))).containsExactly("APPLIED");
        assertThat(outcomes(a, current, List.of(day(DAY, 1, apps("c", 2))))).containsExactly("APPLIED");

        Response response = remove(a, old);

        assertThat(response.status()).as(response.body()).isEqualTo(204);
        assertThat(response.body()).isEmpty();
        assertThat(deviceCount(old)).isZero();
        assertThat(dayCount(old)).isZero();
        assertThat(appCount(old)).isZero();
        assertThat(dayCount(current)).isEqualTo(1);
        assertThat(appCount(current)).isEqualTo(2);
        assertThat(remove(a, old).status()).isEqualTo(404);
    }

    @Test
    void removingAnotherAccountsOrAnUnknownDeviceIs404AndChangesNothing() {
        Account a = newAccount();
        Account b = newAccount();
        UUID phone = newDevice(a, "SM-A366B");
        assertThat(outcomes(a, phone, List.of(day(DAY, 1, apps("p", 2))))).containsExactly("APPLIED");

        assertThat(remove(b, phone).status()).isEqualTo(404);
        assertThat(remove(b, UUID.randomUUID()).status()).isEqualTo(404);
        assertThat(remove(a.token(), "not-a-uuid").status()).isEqualTo(400);
        assertThat(remove(null, phone.toString()).status()).isEqualTo(401);
        assertThat(deviceCount(phone)).isEqualTo(1);
        assertThat(appCount(phone)).isEqualTo(2);
    }

    /** A still-signed-in installation comes back as a device with no history. */
    @Test
    void aRemovedInstallationCanRegisterAgainWithNoHistory() {
        Account a = newAccount();
        UUID phone = newDevice(a, "SM-A366B");
        assertThat(rename(a, phone, "Work phone").status()).isEqualTo(200);
        assertThat(outcomes(a, phone, List.of(day(DAY, 1, apps("p", 2))))).containsExactly("APPLIED");
        assertThat(remove(a, phone).status()).isEqualTo(204);

        assertThat(upload(a, phone, List.of(day(DAY, 2, apps("p", 2)))).status()).isEqualTo(404);
        Response back = reRegister(a, phone, "SM-A366B");
        assertThat(back.status()).as(back.body()).isEqualTo(201);
        assertThat(back.string("displayName")).isEqualTo("SM-A366B");
        assertThat(dayCount(phone)).isZero();
    }

    // --- concurrency ----------------------------------------------------------------

    /** As AccountDeletionIT.ordered: {@code first} is blocked, then {@code second}, then {@code lock} commits. */
    private List<Response> ordered(Connection lock, Supplier<Response> first, Supplier<Response> second)
            throws Exception {
        try (lock; ExecutorService pool = Executors.newFixedThreadPool(2)) {
            List<CompletableFuture<Response>> requests = new ArrayList<>();
            requests.add(CompletableFuture.supplyAsync(first, pool));
            awaitLockWaiters(1, requests);
            requests.add(CompletableFuture.supplyAsync(second, pool));
            awaitLockWaiters(2, requests);
            lock.commit();
            List<Response> responses = requests.stream().map(CompletableFuture::join).toList();
            assertThat(responses).allSatisfy(r -> assertThat(r.status()).as(r.body()).isLessThan(500));
            return responses;
        }
    }

    /**
     * The deadlock the account-row lock prevents: an upload that has created a day,
     * holds the device and day rows, and will next upgrade its account lock for the
     * stored-day budget, while a removal arrives. The removal must wait on the account
     * row, not on the device row. Both succeed and the device is gone.
     */
    @Test
    void removalWaitsForAnUploadThatAlreadyHoldsItsRows() throws Exception {
        for (int round = 0; round < 3; round++) {
            Account a = newAccount();
            UUID phone = newDevice(a, "SM-A366B");
            assertThat(outcomes(a, phone, List.of(day(DAY, 1, apps("p", 2))))).containsExactly("APPLIED");
            Connection dayLock = lockRow(
                    "SELECT 1 FROM usage_days WHERE device_id = ? AND local_date = ? FOR UPDATE", phone, DAY);

            List<Map<String, Object>> days = List.of(day(DAY.minusDays(1), 1, apps("n", 2)), day(DAY, 5, apps("r", 2)));
            List<Response> responses = ordered(dayLock,
                    () -> upload(a, phone, days),
                    () -> remove(a, phone));

            assertThat(responses.get(0).status()).isEqualTo(200);
            assertThat(responses.get(1).status()).isEqualTo(204);
            assertThat(deviceCount(phone)).isZero();
            assertThat(dayCount(phone)).isZero();
        }
    }

    /** A removal that already holds the account makes a later upload a 404, never a write. */
    @Test
    void anUploadQueuedBehindARemovalFindsNoDevice() throws Exception {
        Account a = newAccount();
        UUID phone = newDevice(a, "SM-A366B");
        Connection deviceLock = lockRow("SELECT 1 FROM devices WHERE id = ? FOR KEY SHARE", phone);

        List<Response> responses = ordered(deviceLock,
                () -> remove(a, phone),
                () -> upload(a, phone, List.of(day(DAY, 1, apps("late", 2)))));

        assertThat(responses.get(0).status()).isEqualTo(204);
        assertThat(responses.get(1).status()).isEqualTo(404);
        assertThat(deviceCount(phone)).isZero();
        assertThat(dayCount(phone)).isZero();
    }
}
