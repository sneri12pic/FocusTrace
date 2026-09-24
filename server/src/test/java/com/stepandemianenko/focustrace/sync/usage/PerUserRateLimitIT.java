package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/**
 * D18 authenticated per-user limits, set to three requests per hour per bucket.
 * Every test uses fresh accounts, so buckets never carry over between tests.
 * Refill timing is proven on a fake clock in {@code TokenBucketTest}.
 */
@TestPropertySource(properties = {
    "focustrace.auth.rate-limit.upload-per-user.capacity=3",
    "focustrace.auth.rate-limit.history-per-user.capacity=3",
    "focustrace.auth.rate-limit.device-register-per-user.capacity=3"
})
class PerUserRateLimitIT extends UsageTestSupport {

    private static final LocalDate DAY = LocalDate.of(2026, 9, 10);
    private static final String HISTORY = "/api/v1/usage?from=2026-09-01&to=2026-09-30";

    private void assertLimited(Response response, Account account) {
        assertThat(response.status()).as(response.body()).isEqualTo(429);
        assertThat(Long.parseLong(response.header("Retry-After"))).isPositive();
        assertThat(response.header("Content-Type")).startsWith("application/problem+json");
        assertThat(response.json()).containsOnlyKeys("title", "status", "detail", "instance");
        assertThat(response.body()).doesNotContain(account.id().toString()).doesNotContainIgnoringCase("bucket");
    }

    @Test
    void uploadsPastTheLimitAre429AndWriteNothing() {
        Account a = newAccount();
        UUID device = newDevice(a);
        for (int i = 0; i < 3; i++) {
            assertThat(outcomes(a, device, List.of(day(DAY.plusDays(i), 1, apps("app", 2))))).containsExactly("APPLIED");
        }

        assertLimited(upload(a, device, List.of(day(DAY.plusDays(3), 1, apps("app", 2)))), a);

        assertThat(dayCount(device)).isEqualTo(3);
    }

    @Test
    void eachAccountHasItsOwnUploadBucket() {
        Account a = newAccount();
        Account b = newAccount();
        UUID aDevice = newDevice(a);
        UUID bDevice = newDevice(b);
        for (int i = 0; i < 3; i++) {
            outcomes(a, aDevice, List.of(day(DAY, 1, apps("app", 1))));
        }
        assertLimited(upload(a, aDevice, List.of(day(DAY, 1, apps("app", 1)))), a);

        assertThat(outcomes(b, bDevice, List.of(day(DAY, 1, apps("app", 1))))).containsExactly("APPLIED");
    }

    /** The bucket is charged before the body is read, so malformed input cannot flood. */
    @Test
    void rejectedBodiesStillSpendUploadTokens() {
        Account a = newAccount();
        UUID device = newDevice(a);
        assertThat(upload(a.token(), "{not json").status()).isEqualTo(400);
        assertThat(upload(a.token(), Map.of("deviceId", device.toString(), "days", List.of())).status()).isEqualTo(400);
        assertThat(upload(a, UUID.randomUUID(), List.of(day(DAY, 1, apps("app", 1)))).status()).isEqualTo(404);

        assertLimited(upload(a, device, List.of(day(DAY, 1, apps("app", 1)))), a);
        assertThat(dayCount(device)).isZero();
    }

    /** Authentication runs first: a rejected token never reaches, or empties, any bucket. */
    @Test
    void unauthenticatedRequestsConsumeNoAccountBudget() {
        Account a = newAccount();
        UUID device = newDevice(a);
        Object body = body(device, List.of(day(DAY, 1, apps("app", 1))));
        for (int i = 0; i < 5; i++) {
            assertThat(upload(null, body).status()).isEqualTo(401);
            assertThat(upload(a.token() + "x", body).status()).isEqualTo(401);
            assertThat(get(HISTORY, null).status()).isEqualTo(401);
        }

        for (int i = 0; i < 3; i++) {
            assertThat(upload(a.token(), body).status()).isEqualTo(200);
            assertThat(get(HISTORY, a.token()).status()).isEqualTo(200);
        }
        assertLimited(upload(a.token(), body), a);
        assertLimited(get(HISTORY, a.token()), a);
    }

    /** Reads keep their D16 semantics under the limiter, and are budgeted apart from uploads. */
    @Test
    @SuppressWarnings("unchecked")
    void historyReadsPastTheLimitAre429AndOtherAccountsAreUnaffected() {
        Account a = newAccount();
        Account b = newAccount();
        UUID aDevice = newDevice(a);
        UUID bDevice = newDevice(b);
        outcomes(a, aDevice, List.of(day(DAY, 1, apps("app", 2))));
        outcomes(b, bDevice, List.of(day(DAY, 1, apps("app", 1))));

        List<Map<String, Object>> all = (List<Map<String, Object>>) get(HISTORY, a.token()).json().get("days");
        List<Map<String, Object>> own = (List<Map<String, Object>>)
                get(HISTORY + "&deviceId=" + aDevice, a.token()).json().get("days");
        List<Map<String, Object>> foreign = (List<Map<String, Object>>)
                get(HISTORY + "&deviceId=" + bDevice, a.token()).json().get("days");
        assertThat(all).singleElement().satisfies(d -> assertThat(d).containsEntry("deviceId", aDevice.toString()));
        assertThat(own).isEqualTo(all);
        assertThat(foreign).isEmpty();

        assertLimited(get(HISTORY, a.token()), a);
        // A's uploads are a separate bucket; B's reads are B's own.
        assertThat(outcomes(a, aDevice, List.of(day(DAY, 1, apps("app", 2))))).containsExactly("DUPLICATE");
        assertThat(get(HISTORY, b.token()).status()).isEqualTo(200);
    }

    @Test
    void deviceRegistrationPastTheLimitIs429AndWritesNothing() {
        Account a = newAccount();
        UUID device = newDevice(a);
        for (int i = 0; i < 2; i++) {
            assertThat(post("/api/v1/devices",
                    Map.of("deviceId", device.toString(), "displayName", "Phone", "platform", "android"),
                    a.token()).status()).isEqualTo(200);
        }
        UUID extra = UUID.randomUUID();

        assertLimited(post("/api/v1/devices",
                Map.of("deviceId", extra.toString(), "displayName", "Extra", "platform", "android"), a.token()), a);

        assertThat(jdbc.queryForObject("SELECT count(*) FROM devices WHERE id = ?", Integer.class, extra)).isZero();
        assertThat(get("/api/v1/devices", a.token()).status()).isEqualTo(200);
    }
}
