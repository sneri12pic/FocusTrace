package com.stepandemianenko.focustrace.sync.device;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.sql.Timestamp;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

/**
 * Phase 1 Step 3 against real PostgreSQL: registration idempotency, D12's 409,
 * query-scoped listing, and the cross-user (BOLA) attempts from baseline section 4.
 */
class DeviceIT extends IntegrationTest {

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
        return registerDevice(account.token(), deviceId, name, "android");
    }

    private Response registerDevice(String token, UUID deviceId, String name, String platform) {
        return post(DEVICES, Map.of("deviceId", deviceId.toString(), "displayName", name, "platform", platform), token);
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> listDevices(Account account) {
        Response response = get(DEVICES, account.token());
        assertThat(response.status()).as(response.body()).isEqualTo(200);
        return JSON.readValue(response.body(), List.class);
    }

    private Map<String, Object> row(UUID deviceId) {
        return jdbc.queryForMap("SELECT * FROM devices WHERE id = ?", deviceId);
    }

    private int rowCount(UUID deviceId) {
        return jdbc.queryForObject("SELECT count(*) FROM devices WHERE id = ?", Integer.class, deviceId);
    }

    // --- basic behaviour ------------------------------------------------------

    @Test
    void registersANewDeviceUnderTheCaller() {
        Account a = newAccount();
        UUID deviceId = UUID.randomUUID();

        Response response = registerDevice(a, deviceId, "Galaxy A36");

        assertThat(response.status()).as(response.body()).isEqualTo(201);
        Map<String, Object> body = response.json();
        assertThat(body).containsOnlyKeys("deviceId", "displayName", "platform", "registeredAt", "lastSeenAt");
        assertThat(body).containsEntry("deviceId", deviceId.toString())
                .containsEntry("displayName", "Galaxy A36")
                .containsEntry("platform", "android");
        assertThat(body.get("registeredAt")).isNotNull();
        assertThat(body.get("lastSeenAt")).isNotNull();
        assertThat(row(deviceId)).containsEntry("user_id", a.id());
    }

    @Test
    void unauthenticatedRequestsAreRejectedWithoutSideEffect() {
        UUID deviceId = UUID.randomUUID();

        assertThat(registerDevice((String) null, deviceId, "Phone", "android").status()).isEqualTo(401);
        assertThat(registerDevice("not-a-jwt", deviceId, "Phone", "android").status()).isEqualTo(401);
        assertThat(get(DEVICES, null).status()).isEqualTo(401);
        assertThat(rowCount(deviceId)).isZero();
    }

    @Test
    void reRegistrationBySameUserUpdatesInPlace() {
        Account a = newAccount();
        UUID deviceId = UUID.randomUUID();
        assertThat(registerDevice(a, deviceId, "Old name").status()).isEqualTo(201);
        Map<String, Object> before = row(deviceId);

        // Platform is fixed at first registration and is not rewritten.
        Response again = registerDevice(a.token(), deviceId, "New name", "windows");

        assertThat(again.status()).as(again.body()).isEqualTo(200);
        assertThat(again.json()).containsEntry("displayName", "New name").containsEntry("platform", "android");
        assertThat(rowCount(deviceId)).isEqualTo(1);
        Map<String, Object> after = row(deviceId);
        assertThat(after).containsEntry("user_id", a.id())
                .containsEntry("display_name", "New name")
                .containsEntry("platform", "android")
                .containsEntry("registered_at", before.get("registered_at"));
        assertThat((Timestamp) after.get("last_seen_at")).isAfterOrEqualTo((Timestamp) before.get("last_seen_at"));
        assertThat(listDevices(a)).hasSize(1);
    }

    @Test
    void listingReturnsOnlyTheCallersDevices() {
        Account a = newAccount();
        Account b = newAccount();
        UUID a1 = UUID.randomUUID();
        UUID a2 = UUID.randomUUID();
        UUID b1 = UUID.randomUUID();
        registerDevice(a, a1, "A phone");
        registerDevice(a, a2, "A tablet");
        registerDevice(b, b1, "B phone");

        assertThat(listDevices(a)).extracting(d -> d.get("deviceId"))
                .containsExactly(a1.toString(), a2.toString());
        assertThat(listDevices(b)).extracting(d -> d.get("deviceId")).containsExactly(b1.toString());
        assertThat(listDevices(newAccount())).isEmpty();
    }

    // --- cross-user (BOLA) ----------------------------------------------------

    @Test
    void anotherUsersDeviceIdIsA409WithNoSideEffectAndNoDisclosure() {
        Account a = newAccount();
        Account b = newAccount();
        UUID bDevice = UUID.randomUUID();
        assertThat(registerDevice(b, bDevice, "B private name").status()).isEqualTo(201);
        Map<String, Object> before = row(bDevice);

        Response takeover = registerDevice(a.token(), bDevice, "Stolen", "windows");

        assertThat(takeover.status()).isEqualTo(409);
        assertThat(takeover.header("Content-Type")).startsWith("application/problem+json");
        assertThat(takeover.body())
                .doesNotContain("B private name")
                .doesNotContain(b.id().toString())
                .doesNotContain(bDevice.toString())
                .doesNotContain("registeredAt")
                .doesNotContain("lastSeenAt")
                .doesNotContainIgnoringCase("exception");
        // Nothing moved, nothing renamed, nothing touched.
        assertThat(row(bDevice)).isEqualTo(before);
        assertThat(rowCount(bDevice)).isEqualTo(1);
        assertThat(listDevices(a)).isEmpty();

        // The owner is unaffected and can still use their device.
        assertThat(listDevices(b)).extracting(d -> d.get("displayName")).containsExactly("B private name");
        assertThat(registerDevice(b, bDevice, "B renamed").status()).isEqualTo(200);
        assertThat(row(bDevice)).containsEntry("user_id", b.id()).containsEntry("display_name", "B renamed");
    }

    @Test
    void repeatedTakeoverAttemptsNeverTransferOwnership() {
        Account a = newAccount();
        Account b = newAccount();
        UUID bDevice = UUID.randomUUID();
        registerDevice(b, bDevice, "B phone");

        for (int i = 0; i < 3; i++) {
            assertThat(registerDevice(a, bDevice, "A attempt " + i).status()).isEqualTo(409);
        }
        assertThat(row(bDevice)).containsEntry("user_id", b.id()).containsEntry("display_name", "B phone");
    }

    /** Step 3 has no read-one, rename or delete route; none of those verbs may reach B's row. */
    @Test
    void verbsWithoutARouteChangeNothing() throws Exception {
        Account a = newAccount();
        Account b = newAccount();
        UUID bDevice = UUID.randomUUID();
        registerDevice(b, bDevice, "B phone");
        Map<String, Object> before = row(bDevice);
        HttpClient http = HttpClient.newHttpClient();
        String body = "{\"displayName\":\"Stolen\"}";

        for (String method : List.of("GET", "PUT", "PATCH", "DELETE")) {
            for (String path : List.of(DEVICES + "/" + bDevice, DEVICES)) {
                HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                        .header("Authorization", "Bearer " + a.token())
                        .header("Content-Type", "application/json")
                        .method(method, HttpRequest.BodyPublishers.ofString(body))
                        .build();
                if (method.equals("GET") && path.equals(DEVICES)) {
                    continue; // the real listing, covered above
                }
                HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
                assertThat(response.statusCode()).as(method + " " + path).isIn(404, 405);
                assertThat(response.body()).doesNotContain("B phone");
            }
        }
        assertThat(row(bDevice)).isEqualTo(before);
    }

    @Test
    void concurrentFirstRegistrationByTwoUsersHasExactlyOneOwner() {
        for (int round = 0; round < 5; round++) {
            Account a = newAccount();
            Account b = newAccount();
            UUID deviceId = UUID.randomUUID();

            List<Response> results = race(
                    () -> registerDevice(a, deviceId, "A"),
                    () -> registerDevice(b, deviceId, "B"));

            assertThat(results).extracting(Response::status).containsExactlyInAnyOrder(201, 409);
            assertThat(rowCount(deviceId)).isEqualTo(1);
            UUID winner = results.get(0).status() == 201 ? a.id() : b.id();
            assertThat(row(deviceId)).containsEntry("user_id", winner);
        }
    }

    @Test
    void concurrentRegistrationBySameUserCreatesOneRow() {
        Account a = newAccount();
        UUID deviceId = UUID.randomUUID();

        List<Response> results = race(
                () -> registerDevice(a, deviceId, "first"),
                () -> registerDevice(a, deviceId, "second"));

        assertThat(results).extracting(Response::status).containsExactlyInAnyOrder(201, 200);
        assertThat(rowCount(deviceId)).isEqualTo(1);
    }

    // --- request boundary -----------------------------------------------------

    @Test
    void ownershipAndServerFieldsCannotBeSupplied() {
        Account a = newAccount();
        Account b = newAccount();
        for (String extra : List.of("userId", "user_id", "ownerId", "registeredAt", "lastSeenAt")) {
            UUID deviceId = UUID.randomUUID();
            String json = """
                    {"deviceId":"%s","displayName":"x","platform":"android","%s":"%s"}
                    """.formatted(deviceId, extra, b.id());

            Response response = postJson(DEVICES, json, a.token(), Map.of());

            assertThat(response.status()).as(extra).isEqualTo(400);
            assertThat(rowCount(deviceId)).as(extra).isZero();
        }
    }

    @Test
    void invalidInputIsA400WithNoRowWritten() {
        Account a = newAccount();
        UUID nameBased = UUID.nameUUIDFromBytes("serial-R58M1234".getBytes());
        List<String> bodies = List.of(
                "{\"deviceId\":\"%s\",\"displayName\":\"x\",\"platform\":\"android\"}".formatted(nameBased),
                "{\"deviceId\":\"00000000-0000-0000-0000-000000000000\",\"displayName\":\"x\",\"platform\":\"android\"}",
                "{\"deviceId\":\"not-a-uuid\",\"displayName\":\"x\",\"platform\":\"android\"}",
                "{\"displayName\":\"x\",\"platform\":\"android\"}",
                "{\"deviceId\":\"%s\",\"displayName\":\"  \",\"platform\":\"android\"}".formatted(UUID.randomUUID()),
                "{\"deviceId\":\"%s\",\"displayName\":\"%s\",\"platform\":\"android\"}"
                        .formatted(UUID.randomUUID(), "n".repeat(101)),
                "{\"deviceId\":\"%s\",\"displayName\":\"x\",\"platform\":\"ios\"}".formatted(UUID.randomUUID()),
                "{\"deviceId\":\"%s\",\"displayName\":\"x\",\"platform\":\"Android\"}".formatted(UUID.randomUUID()),
                "{\"deviceId\":\"%s\",\"displayName\":\"x\"}".formatted(UUID.randomUUID()),
                // Lone surrogate (stored as '?' before this was rejected), NUL, tab.
                "{\"deviceId\":\"%s\",\"displayName\":\"a\\ud800b\",\"platform\":\"android\"}"
                        .formatted(UUID.randomUUID()),
                "{\"deviceId\":\"%s\",\"displayName\":\"a\\u0000b\",\"platform\":\"android\"}"
                        .formatted(UUID.randomUUID()),
                "{\"deviceId\":\"%s\",\"displayName\":\"a\\tb\",\"platform\":\"android\"}"
                        .formatted(UUID.randomUUID()),
                "{not json");
        int before = jdbc.queryForObject("SELECT count(*) FROM devices WHERE user_id = ?", Integer.class, a.id());

        for (String body : bodies) {
            Response response = postJson(DEVICES, body, a.token(), Map.of());
            assertThat(response.status()).as(body).isEqualTo(400);
            assertThat(response.body()).as(body).doesNotContain("Exception").doesNotContain("at com.");
        }
        assertThat(jdbc.queryForObject("SELECT count(*) FROM devices WHERE user_id = ?", Integer.class, a.id()))
                .isEqualTo(before);
    }

    @Test
    void wellFormedUnicodeNamesRoundTrip() {
        Account a = newAccount();
        UUID deviceId = UUID.randomUUID();
        String name = "Pixel 📱 Téléphone";

        Response response = registerDevice(a, deviceId, name);

        assertThat(response.status()).as(response.body()).isEqualTo(201);
        assertThat(response.json()).containsEntry("displayName", name);
        assertThat(row(deviceId)).containsEntry("display_name", name);
    }

    // --- persistence-layer ownership ----------------------------------------

    @Test
    void schemaRefusesMissingOrDanglingOwnership() {
        Account a = newAccount();
        UUID deviceId = UUID.randomUUID();
        registerDevice(a, deviceId, "Phone");

        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO devices (id, user_id, display_name, platform) VALUES (?, NULL, 'x', 'android')",
                UUID.randomUUID())).isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> jdbc.update("UPDATE devices SET user_id = NULL WHERE id = ?", deviceId))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO devices (id, user_id, display_name, platform) VALUES (?, ?, 'x', 'android')",
                UUID.randomUUID(), UUID.randomUUID())).isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> jdbc.update("UPDATE devices SET user_id = ? WHERE id = ?", UUID.randomUUID(), deviceId))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThat(row(deviceId)).containsEntry("user_id", a.id());
    }

    @Test
    void deletingTheOwnerDeletesTheirDevicesOnly() {
        Account a = newAccount();
        Account b = newAccount();
        UUID aDevice = UUID.randomUUID();
        UUID bDevice = UUID.randomUUID();
        registerDevice(a, aDevice, "A");
        registerDevice(b, bDevice, "B");

        jdbc.update("DELETE FROM users WHERE id = ?", a.id());

        assertThat(rowCount(aDevice)).isZero();
        assertThat(rowCount(bDevice)).isEqualTo(1);
    }

    // --- helpers --------------------------------------------------------------

    private static List<Response> race(Supplier<Response> first, Supplier<Response> second) {
        CountDownLatch start = new CountDownLatch(1);
        try (ExecutorService pool = Executors.newFixedThreadPool(2)) {
            List<CompletableFuture<Response>> futures = List.of(
                    CompletableFuture.supplyAsync(() -> awaitThen(start, first), pool),
                    CompletableFuture.supplyAsync(() -> awaitThen(start, second), pool));
            start.countDown();
            List<Response> results = futures.stream().map(CompletableFuture::join).toList();
            assertThat(results).allSatisfy(r -> assertThat(r.status()).as(r.body()).isLessThan(500));
            return results;
        }
    }

    private static Response awaitThen(CountDownLatch start, Supplier<Response> call) {
        try {
            start.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
        return call.get();
    }
}
