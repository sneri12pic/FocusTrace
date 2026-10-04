package com.stepandemianenko.focustrace.sync.device;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.sql.Connection;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/**
 * D18 active-device quota against real PostgreSQL, with the quota set to three.
 * The concurrency tests hold the account row from the test itself, so every
 * request is proven to be in flight at once before any of them may proceed.
 */
@TestPropertySource(properties = "focustrace.sync.max-active-devices=" + DeviceQuotaIT.QUOTA)
class DeviceQuotaIT extends IntegrationTest {

    static final int QUOTA = 3;
    private static final String DEVICES = "/api/v1/devices";

    record Account(UUID id, String token) {
    }

    private Account newAccount() {
        String email = uniqueEmail();
        Response registered = register(email, STRONG_PASSWORD);
        assertThat(registered.status()).isEqualTo(201);
        return new Account(UUID.fromString(registered.string("userId")),
                loggedIn(email, STRONG_PASSWORD).string("accessToken"));
    }

    private Response registerDevice(Account account, UUID deviceId, String name) {
        return post(DEVICES, Map.of("deviceId", deviceId.toString(), "displayName", name, "platform", "android"),
                account.token());
    }

    /** Fills the account to {@code count} devices; returns their ids. */
    private List<UUID> fill(Account account, int count) {
        List<UUID> ids = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            UUID id = UUID.randomUUID();
            assertThat(registerDevice(account, id, "Device " + i).status()).isEqualTo(201);
            ids.add(id);
        }
        return ids;
    }

    private int deviceCount(Account account) {
        return jdbc.queryForObject("SELECT count(*) FROM devices WHERE user_id = ?", Integer.class, account.id());
    }

    /** The D18 definition, with the default 90-day window. */
    private int activeCount(Account account) {
        return jdbc.queryForObject("""
                SELECT count(*) FROM devices WHERE user_id = ?
                   AND COALESCE(last_seen_at, registered_at) > now() - interval '90 days'""",
                Integer.class, account.id());
    }

    private void makeInactive(UUID deviceId) {
        jdbc.update("UPDATE devices SET last_seen_at = now() - interval '91 days' WHERE id = ?", deviceId);
    }

    private Map<String, Object> row(UUID deviceId) {
        return jdbc.queryForMap("SELECT * FROM devices WHERE id = ?", deviceId);
    }

    /**
     * Starts every call while the test holds the account row, waits until all are
     * queued on a lock (proven overlap, no sleeps), then releases them.
     */
    private List<Integer> raceUnderAccountLock(Account account, List<Supplier<Response>> calls) throws Exception {
        try (Connection lock = lockAccount(account.id());
                ExecutorService pool = Executors.newFixedThreadPool(calls.size())) {
            List<CompletableFuture<Response>> requests = new ArrayList<>();
            for (Supplier<Response> call : calls) {
                requests.add(CompletableFuture.supplyAsync(call, pool));
            }
            awaitLockWaiters(calls.size(), requests);
            lock.commit();
            return requests.stream().map(f -> f.join().status()).toList();
        }
    }

    private int rowCount(UUID deviceId) {
        return jdbc.queryForObject("SELECT count(*) FROM devices WHERE id = ?", Integer.class, deviceId);
    }

    @Test
    void admitsUpToTheQuotaThenRejectsWithNoRowWritten() {
        Account a = newAccount();
        fill(a, QUOTA - 1);
        assertThat(registerDevice(a, UUID.randomUUID(), "Last slot").status()).isEqualTo(201);

        UUID over = UUID.randomUUID();
        Response rejected = registerDevice(a, over, "One too many");

        assertThat(rejected.status()).isEqualTo(403);
        assertThat(rejected.header("Content-Type")).startsWith("application/problem+json");
        assertThat(rejected.json()).containsEntry("status", 403).doesNotContainKey("errors");
        assertThat(rejected.body()).doesNotContain(a.id().toString()).doesNotContain(over.toString());
        assertThat(rowCount(over)).isZero();
        assertThat(deviceCount(a)).isEqualTo(QUOTA);
    }

    @Test
    void oneAccountAtQuotaDoesNotAffectAnother() {
        Account a = newAccount();
        Account b = newAccount();
        fill(a, QUOTA);
        assertThat(registerDevice(a, UUID.randomUUID(), "A over").status()).isEqualTo(403);

        fill(b, QUOTA);

        assertThat(deviceCount(b)).isEqualTo(QUOTA);
    }

    @Test
    void reRegistrationOfAnOwnDeviceSucceedsAtQuota() {
        Account a = newAccount();
        UUID first = fill(a, QUOTA).getFirst();

        Response again = registerDevice(a, first, "Renamed");

        assertThat(again.status()).as(again.body()).isEqualTo(200);
        assertThat(again.json()).containsEntry("displayName", "Renamed");
        assertThat(deviceCount(a)).isEqualTo(QUOTA);
    }

    /** D12 is unchanged: another account's UUID is a 409, never the caller's quota. */
    @Test
    void foreignUuidIsStill409AtQuotaAndBelowIt() {
        Account a = newAccount();
        Account b = newAccount();
        UUID bDevice = fill(b, 1).getFirst();

        assertThat(registerDevice(a, bDevice, "Takeover").status()).isEqualTo(409);
        fill(a, QUOTA);
        Response atQuota = registerDevice(a, bDevice, "Takeover");
        makeInactive(bDevice);
        Map<String, Object> before = row(bDevice);
        Response inactiveAtQuota = registerDevice(a, bDevice, "Takeover");

        assertThat(atQuota.status()).isEqualTo(409);
        assertThat(inactiveAtQuota.status()).isEqualTo(409);
        assertThat(inactiveAtQuota.body()).isEqualTo(atQuota.body());
        assertThat(row(bDevice)).isEqualTo(before);
        assertThat(jdbc.queryForObject("SELECT user_id FROM devices WHERE id = ?", UUID.class, bDevice))
                .isEqualTo(b.id());
        assertThat(deviceCount(a)).isEqualTo(QUOTA);
    }

    /** A device unseen for longer than the active window stops holding a slot. */
    @Test
    void aDeviceUnseenForTheActiveWindowFreesItsSlot() {
        Account a = newAccount();
        UUID retired = fill(a, QUOTA).getFirst();
        makeInactive(retired);

        assertThat(registerDevice(a, UUID.randomUUID(), "Replacement").status()).isEqualTo(201);
        assertThat(registerDevice(a, UUID.randomUUID(), "One too many").status()).isEqualTo(403);
        assertThat(activeCount(a)).isEqualTo(QUOTA);
    }

    /** Re-registering an already-active device at full quota takes no slot. */
    @Test
    void anActiveDeviceReRegistersAtFullQuota() {
        Account a = newAccount();
        UUID target = fill(a, QUOTA).getFirst();
        jdbc.update("UPDATE devices SET last_seen_at = now() - interval '1 day' WHERE id = ?", target);
        Timestamp before = (Timestamp) row(target).get("last_seen_at");

        Response again = registerDevice(a, target, "Phone");

        assertThat(again.status()).as(again.body()).isEqualTo(200);
        assertThat(activeCount(a)).isEqualTo(QUOTA);
        assertThat((Timestamp) row(target).get("last_seen_at")).isAfter(before);
    }

    /** Reactivation takes a slot; with one free it succeeds on the same row and owner. */
    @Test
    void anInactiveDeviceReactivatesBelowQuota() {
        Account a = newAccount();
        UUID dormant = fill(a, QUOTA).getFirst();
        makeInactive(dormant);
        assertThat(activeCount(a)).isEqualTo(QUOTA - 1);

        Response back = registerDevice(a, dormant, "Back again");

        assertThat(back.status()).as(back.body()).isEqualTo(200);
        assertThat(activeCount(a)).isEqualTo(QUOTA);
        assertThat(deviceCount(a)).isEqualTo(QUOTA);
        assertThat(row(dormant)).containsEntry("user_id", a.id()).containsEntry("display_name", "Back again");
    }

    /**
     * Regression: reactivation at quota used to bypass it and leave QUOTA + 1 active
     * devices. It is now the same 403 as a new device, and the row is untouched.
     */
    @Test
    void anInactiveDeviceAtQuotaIsRefusedAndLeftUnchanged() {
        Account a = newAccount();
        UUID dormant = fill(a, QUOTA).getFirst();
        makeInactive(dormant);
        assertThat(registerDevice(a, UUID.randomUUID(), "Replacement").status()).isEqualTo(201);
        Map<String, Object> before = row(dormant);
        Response newAtQuota = registerDevice(a, UUID.randomUUID(), "New");

        Response reactivation = registerDevice(a, dormant, "Back again");

        assertThat(newAtQuota.status()).isEqualTo(403);
        assertThat(reactivation.status()).isEqualTo(403);
        assertThat(reactivation.body()).isEqualTo(newAtQuota.body());
        assertThat(row(dormant)).isEqualTo(before);
        assertThat(activeCount(a)).isEqualTo(QUOTA);
    }

    /** Two dormant devices race for the last slot: exactly one comes back. */
    @Test
    void concurrentReactivationsForTheLastSlotAdmitExactlyOne() throws Exception {
        for (int round = 0; round < 3; round++) {
            Account a = newAccount();
            List<UUID> devices = fill(a, QUOTA);
            makeInactive(devices.get(0));
            makeInactive(devices.get(1));
            assertThat(registerDevice(a, UUID.randomUUID(), "Active").status()).isEqualTo(201);
            assertThat(activeCount(a)).isEqualTo(QUOTA - 1);

            List<Integer> statuses = raceUnderAccountLock(a, List.of(
                    () -> registerDevice(a, devices.get(0), "Back"),
                    () -> registerDevice(a, devices.get(1), "Back")));

            assertThat(statuses).containsExactlyInAnyOrder(200, 403);
            assertThat(activeCount(a)).isEqualTo(QUOTA);
        }
    }

    /** A reactivation and a new installation race for the last slot: exactly one wins. */
    @Test
    void reactivationAndNewDeviceRacingForTheLastSlotAdmitExactlyOne() throws Exception {
        for (int round = 0; round < 3; round++) {
            Account a = newAccount();
            UUID dormant = fill(a, QUOTA).getFirst();
            makeInactive(dormant);
            UUID fresh = UUID.randomUUID();

            List<Integer> statuses = raceUnderAccountLock(a, List.of(
                    () -> registerDevice(a, dormant, "Back"),
                    () -> registerDevice(a, fresh, "New")));

            // Either may win: 200 (reactivated) + 403, or 201 (created) + 403.
            assertThat(statuses).containsOnlyOnce(403).hasSize(2).containsAnyOf(200, 201);
            assertThat(activeCount(a)).isEqualTo(QUOTA);
        }
    }

    /**
     * Five new installations race for the last slot. The test holds the account row,
     * so all five are provably queued at once; releasing it lets exactly one in.
     * Without the service's account lock, every request counts first and then waits
     * on the same row at its foreign-key check, and all five are admitted.
     */
    @Test
    void concurrentRegistrationsForTheLastSlotAdmitExactlyOne() throws Exception {
        for (int round = 0; round < 3; round++) {
            Account a = newAccount();
            fill(a, QUOTA - 1);

            List<Integer> statuses;
            try (Connection lock = lockAccount(a.id()); ExecutorService pool = Executors.newFixedThreadPool(5)) {
                List<CompletableFuture<Response>> requests = new ArrayList<>();
                for (int i = 0; i < 5; i++) {
                    UUID id = UUID.randomUUID();
                    requests.add(CompletableFuture.supplyAsync(() -> registerDevice(a, id, "Racer"), pool));
                }
                awaitLockWaiters(5, requests);
                lock.commit();
                statuses = requests.stream().map(f -> f.join().status()).toList();
            }

            assertThat(statuses).containsExactlyInAnyOrder(201, 403, 403, 403, 403);
            assertThat(deviceCount(a)).isEqualTo(QUOTA);
        }
    }

    /** Unbarriered rounds from an empty account: whatever the interleaving, never above quota. */
    @Test
    void repeatedConcurrentRoundsStayBounded() {
        for (int round = 0; round < 5; round++) {
            Account a = newAccount();
            CountDownLatch start = new CountDownLatch(1);
            List<Integer> statuses;
            try (ExecutorService pool = Executors.newFixedThreadPool(6)) {
                List<CompletableFuture<Response>> requests = new ArrayList<>();
                for (int i = 0; i < 6; i++) {
                    UUID id = UUID.randomUUID();
                    requests.add(CompletableFuture.supplyAsync(() -> {
                        try {
                            start.await();
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                            throw new IllegalStateException(e);
                        }
                        return registerDevice(a, id, "Racer");
                    }, pool));
                }
                start.countDown();
                statuses = requests.stream().map(f -> f.join().status()).toList();
            }

            assertThat(statuses).containsOnly(201, 403);
            assertThat(statuses.stream().filter(s -> s == 201)).hasSize(QUOTA);
            assertThat(deviceCount(a)).isEqualTo(QUOTA);
        }
    }
}
