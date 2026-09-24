package com.stepandemianenko.focustrace.sync.device;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.sql.Connection;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
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

        assertThat(atQuota.status()).isEqualTo(409);
        assertThat(jdbc.queryForObject("SELECT user_id FROM devices WHERE id = ?", UUID.class, bDevice))
                .isEqualTo(b.id());
        assertThat(deviceCount(a)).isEqualTo(QUOTA);
    }

    /**
     * A device unseen for longer than the active window stops holding a slot, so a
     * reinstalled app is never stranded. Its data and row are kept, and it may still
     * re-register: the quota bounds admission of new installations only.
     */
    @Test
    void aDeviceUnseenForTheActiveWindowFreesItsSlot() {
        Account a = newAccount();
        UUID retired = fill(a, QUOTA).getFirst();
        jdbc.update("UPDATE devices SET last_seen_at = now() - interval '91 days' WHERE id = ?", retired);

        assertThat(registerDevice(a, UUID.randomUUID(), "Replacement").status()).isEqualTo(201);
        assertThat(registerDevice(a, UUID.randomUUID(), "One too many").status()).isEqualTo(403);
        assertThat(registerDevice(a, retired, "Back again").status()).isEqualTo(200);
        assertThat(deviceCount(a)).isEqualTo(QUOTA + 1);
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
