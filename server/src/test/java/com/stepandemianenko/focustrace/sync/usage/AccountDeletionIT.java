package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;

/**
 * D19 account deletion against real PostgreSQL. Lives beside the usage tests
 * because proving the whole graph is gone needs their upload helpers.
 *
 * <p>The race tests make a request hold real rows by blocking it on a lock the
 * test owns, queue the other request behind it, and wait on {@code pg_stat_activity}
 * until both are provably waiting before releasing anything. No sleeps.
 */
class AccountDeletionIT extends UsageTestSupport {

    private static final String DELETE = "/api/v1/account/delete";
    private static final LocalDate DAY = LocalDate.of(2026, 9, 10);

    /** An account with its email, and the refresh token of its latest login. */
    record Owner(Account account, String email, String refreshToken) {
    }

    private Owner newOwner() {
        String email = uniqueEmail();
        Response registered = register(email, STRONG_PASSWORD);
        assertThat(registered.status()).isEqualTo(201);
        Response login = loggedIn(email, STRONG_PASSWORD);
        return new Owner(new Account(UUID.fromString(registered.string("userId")), login.string("accessToken")),
                email, login.string("refreshToken"));
    }

    private Response deleteAccount(String token, String password) {
        return post(DELETE, Map.of("password", password), token);
    }

    /** Every row the account owns, table by table, for equality and emptiness checks. */
    private Map<String, List<Map<String, Object>>> graph(UUID userId) {
        Map<String, List<Map<String, Object>>> rows = new LinkedHashMap<>();
        rows.put("users", jdbc.queryForList("SELECT * FROM users WHERE id = ?", userId));
        rows.put("auth_sessions", jdbc.queryForList(
                "SELECT * FROM auth_sessions WHERE user_id = ? ORDER BY id", userId));
        rows.put("refresh_tokens", jdbc.queryForList(
                // bytea as hex: byte[] compares by identity.
                "SELECT id, user_id, session_id, encode(token_hash, 'hex') AS token_hash, issued_at, expires_at,"
                        + " revoked_at FROM refresh_tokens WHERE user_id = ? ORDER BY id", userId));
        rows.put("devices", jdbc.queryForList("SELECT * FROM devices WHERE user_id = ? ORDER BY id", userId));
        return rows;
    }

    /** Usage rows by device id: devices are gone after deletion, so the join would hide orphans. */
    private int usageRows(List<UUID> devices) {
        return devices.stream().mapToInt(d -> dayCount(d) + appCount(d)).sum();
    }

    private void assertGone(UUID userId, List<UUID> devices) {
        assertThat(graph(userId).values()).allSatisfy(rows -> assertThat(rows).isEmpty());
        assertThat(usageRows(devices)).isZero();
    }

    /** An owner with two sessions, two devices and uploaded days. */
    private List<UUID> populate(Owner owner) {
        assertThat(loggedIn(owner.email(), STRONG_PASSWORD).status()).isEqualTo(200);
        UUID phone = newDevice(owner.account(), "Phone");
        UUID tablet = newDevice(owner.account(), "Tablet");
        outcomes(owner.account(), phone, List.of(day(DAY, 1, apps("p", 3)), day(DAY.plusDays(1), 1, apps("p", 2))));
        outcomes(owner.account(), tablet, List.of(day(DAY, 1, apps("t", 1))));
        return List.of(phone, tablet);
    }

    // --- basic deletion ---------------------------------------------------------

    @Test
    void deletesTheWholeAccountGraphAndAnswers204WithNoBody() {
        Owner a = newOwner();
        List<UUID> devices = populate(a);
        Map<String, List<Map<String, Object>>> before = graph(a.account().id());
        assertThat(before.get("auth_sessions")).hasSize(2);
        assertThat(before.get("refresh_tokens")).hasSize(2);
        assertThat(before.get("devices")).hasSize(2);
        assertThat(usageRows(devices)).isEqualTo(3 + 6); // days + app rows

        Response deleted = deleteAccount(a.account().token(), STRONG_PASSWORD);

        assertThat(deleted.status()).as(deleted.body()).isEqualTo(204);
        assertThat(deleted.body()).isEmpty();
        assertGone(a.account().id(), devices);
    }

    @Test
    void anotherAccountIsLeftByteForByteUnchanged() {
        Owner a = newOwner();
        Owner b = newOwner();
        populate(a);
        List<UUID> bDevices = populate(b);
        Map<String, List<Map<String, Object>>> bBefore = graph(b.account().id());
        List<Map<String, Object>> bUsage = jdbc.queryForList(
                "SELECT * FROM usage_day_apps WHERE device_id = ? OR device_id = ? ORDER BY device_id, local_date, app_key",
                bDevices.get(0), bDevices.get(1));

        assertThat(deleteAccount(a.account().token(), STRONG_PASSWORD).status()).isEqualTo(204);

        assertThat(graph(b.account().id())).isEqualTo(bBefore);
        assertThat(jdbc.queryForList(
                "SELECT * FROM usage_day_apps WHERE device_id = ? OR device_id = ? ORDER BY device_id, local_date, app_key",
                bDevices.get(0), bDevices.get(1))).isEqualTo(bUsage);
        assertThat(refresh(b.refreshToken()).status()).isEqualTo(200);
    }

    // --- authentication -----------------------------------------------------------

    @Test
    void aWrongPasswordIs403AndChangesNothing() {
        Owner a = newOwner();
        List<UUID> devices = populate(a);
        Map<String, List<Map<String, Object>>> before = graph(a.account().id());
        int usage = usageRows(devices);

        Response wrong = deleteAccount(a.account().token(), "Wrong-Password-For-Deletion-1");

        assertThat(wrong.status()).isEqualTo(403);
        assertThat(wrong.header("Content-Type")).startsWith("application/problem+json");
        assertThat(wrong.json()).containsEntry("status", 403).doesNotContainKey("errors");
        assertThat(wrong.body()).doesNotContain("Wrong-Password").doesNotContain(a.email())
                .doesNotContain(a.account().id().toString());
        assertThat(graph(a.account().id())).isEqualTo(before);
        assertThat(usageRows(devices)).isEqualTo(usage);
        // The session is untouched: the same access token still works.
        assertThat(get("/api/v1/devices", a.account().token()).status()).isEqualTo(200);
    }

    @Test
    void unauthenticatedAndForgedRequestsAre401AndChangeNothing() {
        Owner a = newOwner();
        List<UUID> devices = populate(a);
        Map<String, List<Map<String, Object>>> before = graph(a.account().id());

        assertThat(deleteAccount(null, STRONG_PASSWORD).status()).isEqualTo(401);
        assertThat(deleteAccount(a.account().token() + "x", STRONG_PASSWORD).status()).isEqualTo(401);

        assertThat(graph(a.account().id())).isEqualTo(before);
        assertThat(usageRows(devices)).isEqualTo(3 + 6);
    }

    /** The owner is the token's subject; the body cannot name one. */
    @Test
    void malformedInputIs400AndCannotNameAnotherAccount() {
        Owner a = newOwner();
        Owner b = newOwner();
        Map<String, List<Map<String, Object>>> before = graph(b.account().id());
        String token = a.account().token();

        List<Response> responses = List.of(
                postJson(DELETE, "{}", token, Map.of()),
                postJson(DELETE, "{not json", token, Map.of()),
                postJson(DELETE, "{\"password\":null}", token, Map.of()),
                postJson(DELETE, "{\"password\":\"" + "x".repeat(1025) + "\"}", token, Map.of()),
                post(DELETE, Map.of("password", STRONG_PASSWORD, "userId", b.account().id().toString()), token),
                post(DELETE, Map.of("password", STRONG_PASSWORD, "email", b.email()), token));

        assertThat(responses).allSatisfy(r -> {
            assertThat(r.status()).as(r.body()).isEqualTo(400);
            assertThat(r.body()).doesNotContain(STRONG_PASSWORD).doesNotContain("Exception");
        });
        assertThat(graph(b.account().id())).isEqualTo(before);
        assertThat(graph(a.account().id()).get("users")).hasSize(1);
    }

    @Test
    void aDeletedAccountsAccessAndRefreshTokensAreDead() {
        Owner a = newOwner();
        List<UUID> devices = populate(a);
        String access = a.account().token();

        assertThat(deleteAccount(access, STRONG_PASSWORD).status()).isEqualTo(204);

        assertThat(get("/api/v1/devices", access).status()).isEqualTo(401);
        assertThat(get("/api/v1/usage?from=2026-09-01&to=2026-09-30", access).status()).isEqualTo(401);
        assertThat(upload(a.account(), devices.get(0), List.of(day(DAY, 9, apps("x", 1)))).status()).isEqualTo(401);
        assertThat(post("/api/v1/devices", Map.of("deviceId", UUID.randomUUID().toString(),
                "displayName", "Ghost", "platform", "android"), access).status()).isEqualTo(401);
        assertThat(refresh(a.refreshToken()).status()).isEqualTo(401);
        // The lost-response retry: the account is gone, so the original token cannot repeat it.
        assertThat(deleteAccount(access, STRONG_PASSWORD).status()).isEqualTo(401);
        assertThat(login(a.email(), STRONG_PASSWORD).status()).isEqualTo(401);
        assertGone(a.account().id(), devices);
    }

    /** The installation UUID is not account-scoped: after deletion it registers afresh elsewhere. */
    @Test
    void theSameInstallationAndEmailStartCleanUnderANewAccount() {
        Owner a = newOwner();
        UUID installation = populate(a).get(0);
        assertThat(deleteAccount(a.account().token(), STRONG_PASSWORD).status()).isEqualTo(204);

        Response registered = register(a.email(), STRONG_PASSWORD);
        assertThat(registered.status()).isEqualTo(201);
        assertThat(registered.string("userId")).isNotEqualTo(a.account().id().toString());
        Account b = new Account(UUID.fromString(registered.string("userId")),
                loggedIn(a.email(), STRONG_PASSWORD).string("accessToken"));
        Response device = post("/api/v1/devices", Map.of("deviceId", installation.toString(),
                "displayName", "Phone", "platform", "android"), b.token());

        assertThat(device.status()).isEqualTo(201);
        assertThat(dayCount(installation)).isZero();
        assertThat(outcomes(b, installation, List.of(day(DAY, 1, apps("p", 3))))).containsExactly("APPLIED");
    }

    // --- concurrency ----------------------------------------------------------------

    /**
     * Starts {@code first}, waits until it is blocked on a lock, starts {@code second},
     * waits until both are blocked, then commits {@code lock}.
     */
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
     * The deadlock D19's lock order exists to prevent: an upload that has created a
     * day and holds its device and day rows, and a deletion that arrives next. The
     * upload is stopped on a day row the test holds; the deletion then queues on the
     * account row the upload already share-locked, so it waits for the upload instead
     * of cascading into its rows. Both succeed and nothing survives.
     */
    @Test
    void deletionWaitsForAnUploadThatAlreadyHoldsItsRows() throws Exception {
        for (int round = 0; round < 3; round++) {
            Owner a = newOwner();
            List<UUID> devices = populate(a);
            UUID phone = devices.get(0);
            Connection dayLock = lockRow(
                    "SELECT 1 FROM usage_days WHERE device_id = ? AND local_date = ? FOR UPDATE", phone, DAY);

            // Ascending order: the new day before DAY is created, then DAY blocks.
            List<Map<String, Object>> days = List.of(day(DAY.minusDays(1), 1, apps("n", 2)), day(DAY, 5, apps("r", 2)));
            List<Response> responses = ordered(dayLock,
                    () -> upload(a.account(), phone, days),
                    () -> deleteAccount(a.account().token(), STRONG_PASSWORD));

            assertThat(responses.get(0).status()).isEqualTo(200);
            assertThat(responses.get(1).status()).isEqualTo(204);
            assertGone(a.account().id(), devices);
        }
    }

    /** A deletion that already holds the account makes a later upload find no account, not resurrect one. */
    @Test
    void anUploadQueuedBehindADeletionFindsNothingToWriteTo() throws Exception {
        Owner a = newOwner();
        List<UUID> devices = populate(a);
        UUID phone = devices.get(0);
        // Deletion holds the account row and stops at the device row the test shares.
        Connection deviceLock = lockRow("SELECT 1 FROM devices WHERE id = ? FOR KEY SHARE", phone);

        List<Response> responses = ordered(deviceLock,
                () -> deleteAccount(a.account().token(), STRONG_PASSWORD),
                () -> upload(a.account(), phone, List.of(day(DAY.plusDays(5), 1, apps("late", 2)))));

        assertThat(responses.get(0).status()).isEqualTo(204);
        assertThat(responses.get(1).status()).isEqualTo(401);
        assertGone(a.account().id(), devices);
    }

    @Test
    void aRegistrationEitherSideOfADeletionLeavesNoDevice() throws Exception {
        // Registration first: it holds the account row; deletion queues behind it.
        Owner a = newOwner();
        UUID first = UUID.randomUUID();
        List<Response> registrationFirst = ordered(lockAccount(a.account().id(), "FOR NO KEY UPDATE"),
                () -> post("/api/v1/devices", Map.of("deviceId", first.toString(), "displayName", "New",
                        "platform", "android"), a.account().token()),
                () -> deleteAccount(a.account().token(), STRONG_PASSWORD));
        assertThat(registrationFirst.get(0).status()).isEqualTo(201);
        assertThat(registrationFirst.get(1).status()).isEqualTo(204);
        assertGone(a.account().id(), List.of(first));

        // Deletion first: it holds the account row and stops at a device row the test shares.
        Owner b = newOwner();
        List<UUID> devices = populate(b);
        UUID second = UUID.randomUUID();
        List<Response> deletionFirst = ordered(
                lockRow("SELECT 1 FROM devices WHERE id = ? FOR KEY SHARE", devices.get(0)),
                () -> deleteAccount(b.account().token(), STRONG_PASSWORD),
                () -> post("/api/v1/devices", Map.of("deviceId", second.toString(), "displayName", "New",
                        "platform", "android"), b.account().token()));
        assertThat(deletionFirst.get(0).status()).isEqualTo(204);
        assertThat(deletionFirst.get(1).status()).isEqualTo(401);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM devices WHERE id = ?", Integer.class, second)).isZero();
        assertGone(b.account().id(), devices);
    }

    /**
     * A refresh stopped just before claiming its token row, and a deletion that
     * arrives meanwhile. Without rotation's account-first lock the refresh would hold
     * nothing yet, the deletion would take the account row and wait for the token row,
     * and the refresh - granted the token row first - would then wait for the account
     * row in its successor's foreign-key check: a cycle. With it, the deletion waits
     * for the refresh; the refresh completes, and the deletion removes what it issued.
     */
    @Test
    void aRefreshInFlightCannotOutliveADeletion() throws Exception {
        for (int round = 0; round < 3; round++) {
            Owner a = newOwner();
            Connection tokenLock = lockRow(
                    "SELECT 1 FROM refresh_tokens WHERE user_id = ? AND revoked_at IS NULL FOR UPDATE",
                    a.account().id());

            List<Response> responses = ordered(tokenLock,
                    () -> refresh(a.refreshToken()),
                    () -> deleteAccount(a.account().token(), STRONG_PASSWORD));

            assertThat(responses.get(0).status()).isEqualTo(200);
            assertThat(responses.get(1).status()).isEqualTo(204);
            assertThat(refresh(responses.get(0).string("refreshToken")).status()).isEqualTo(401);
            assertThat(get("/api/v1/devices", responses.get(0).string("accessToken")).status()).isEqualTo(401);
            assertGone(a.account().id(), List.of());
        }
    }
}
