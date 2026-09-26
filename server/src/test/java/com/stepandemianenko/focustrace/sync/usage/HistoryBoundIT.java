package com.stepandemianenko.focustrace.sync.usage;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/**
 * Architecture 9.3 response bound against PostgreSQL, set to ten rows. A row is one
 * app of one stored day, or one stored day with no apps. At the bound the history is
 * returned whole; one row past it the request is a 400 and nothing is truncated.
 */
@TestPropertySource(properties = "focustrace.sync.max-history-rows=" + HistoryBoundIT.MAX_ROWS)
class HistoryBoundIT extends UsageTestSupport {

    static final int MAX_ROWS = 10;
    private static final LocalDate DAY = TODAY.minusDays(10);
    private static final String RANGE = "/api/v1/usage?from=" + DAY + "&to=" + TODAY;

    private Response read(Account account, String query) {
        return get(RANGE + query, account.token());
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> daysOf(Response response) {
        assertThat(response.status()).as(response.body()).isEqualTo(200);
        return (List<Map<String, Object>>) response.json().get("days");
    }

    private static int rowsOf(List<Map<String, Object>> days) {
        return days.stream().mapToInt(day -> Math.max(1, ((List<?>) day.get("apps")).size())).sum();
    }

    private void assertTooLarge(Response response) {
        assertThat(response.status()).isEqualTo(400);
        assertThat(response.header("Content-Type")).startsWith("application/problem+json");
        assertThat(response.json()).doesNotContainKey("days");
        assertThat(response.body()).contains("\"field\":\"to\"")
                .doesNotContainIgnoringCase("select").doesNotContainIgnoringCase("limit ")
                .doesNotContain("usage_day").doesNotContain("Exception").doesNotContain("at com.");
    }

    @Test
    void anEmptyHistoryIsReturned() {
        Account a = newAccount();
        newDevice(a);

        assertThat(daysOf(read(a, ""))).isEmpty();
    }

    @Test
    void exactlyTheBoundIsReturnedWholeInTheUsualOrder() {
        Account a = newAccount();
        UUID phone = newDevice(a, "Phone");
        UUID tablet = newDevice(a, "Tablet");
        // Uploaded out of order: the response order must still be date, device, appKey.
        outcomes(a, phone, List.of(day(DAY.plusDays(1), 1, apps("p", 3)), day(DAY, 1, apps("q", 2))));
        outcomes(a, tablet, List.of(day(DAY, 1, apps("t", 3)), day(DAY.plusDays(1), 1, apps("u", 2))));

        List<Map<String, Object>> days = daysOf(read(a, ""));

        assertThat(rowsOf(days)).isEqualTo(MAX_ROWS);
        List<Map<String, Object>> sorted = new ArrayList<>(days);
        sorted.sort(Comparator.comparing((Map<String, Object> d) -> (String) d.get("localDate"))
                // PostgreSQL orders uuid by unsigned bytes: the order of the hex strings.
                .thenComparing(d -> (String) d.get("deviceId")));
        assertThat(days).isEqualTo(sorted);
        for (Map<String, Object> day : days) {
            List<String> keys = ((List<Map<String, Object>>) day.get("apps")).stream()
                    .map(app -> (String) app.get("appKey")).toList();
            assertThat(keys).isSorted();
        }
    }

    @Test
    void oneRowPastTheBoundIsRejectedWhole() {
        Account a = newAccount();
        UUID phone = newDevice(a);
        outcomes(a, phone, List.of(day(DAY, 1, apps("p", MAX_ROWS))));
        assertThat(rowsOf(daysOf(read(a, "")))).isEqualTo(MAX_ROWS);
        int storedBefore = appCount(phone);

        outcomes(a, phone, List.of(day(DAY.plusDays(1), 1, apps("q", 1))));

        assertTooLarge(read(a, ""));
        assertThat(appCount(phone)).isEqualTo(storedBefore + 1);
        // A narrower range is the remedy.
        assertThat(rowsOf(daysOf(get("/api/v1/usage?from=" + DAY + "&to=" + DAY.plusDays(1), a.token()))))
                .isEqualTo(MAX_ROWS);
    }

    /** A stored day without apps is one row, so it counts towards the bound too. */
    @Test
    void daysWithoutAppsCountAsOneRowEach() {
        Account a = newAccount();
        UUID phone = newDevice(a);
        outcomes(a, phone, List.of(day(DAY, 1, apps("p", MAX_ROWS - 1)), day(DAY.plusDays(1), 1, List.of())));
        assertThat(rowsOf(daysOf(read(a, "")))).isEqualTo(MAX_ROWS);

        outcomes(a, phone, List.of(day(DAY.plusDays(2), 1, List.of())));

        assertTooLarge(read(a, ""));
    }

    @Test
    void spreadingRowsAcrossDevicesDoesNotEscapeTheBound() {
        Account a = newAccount();
        UUID phone = newDevice(a, "Phone");
        UUID tablet = newDevice(a, "Tablet");
        outcomes(a, phone, List.of(day(DAY, 1, apps("p", 6))));
        outcomes(a, tablet, List.of(day(DAY, 1, apps("t", 5))));

        assertTooLarge(read(a, ""));
        // Each device alone fits, so the deviceId filter is the per-device remedy.
        assertThat(rowsOf(daysOf(read(a, "&deviceId=" + phone)))).isEqualTo(6);
        assertThat(rowsOf(daysOf(read(a, "&deviceId=" + tablet)))).isEqualTo(5);
    }

    @Test
    void theBoundAppliesWithinADeviceFilter() {
        Account a = newAccount();
        UUID phone = newDevice(a, "Phone");
        UUID tablet = newDevice(a, "Tablet");
        outcomes(a, phone, List.of(day(DAY, 1, apps("p", MAX_ROWS + 1))));
        outcomes(a, tablet, List.of(day(DAY, 1, apps("t", 2))));

        assertTooLarge(read(a, "&deviceId=" + phone));
        assertThat(rowsOf(daysOf(read(a, "&deviceId=" + tablet)))).isEqualTo(2);
    }

    /**
     * A foreign device over the bound still filters to nothing, exactly like an
     * unknown id (D16): the bound only ever sees the caller's own rows.
     */
    @Test
    void aForeignDeviceOverTheBoundIsIndistinguishableFromAnUnknownOne() {
        Account a = newAccount();
        Account b = newAccount();
        newDevice(a);
        UUID bPhone = newDevice(b);
        outcomes(b, bPhone, List.of(day(DAY, 1, apps("b", MAX_ROWS + 5))));

        Response foreign = read(a, "&deviceId=" + bPhone);
        Response unknown = read(a, "&deviceId=" + UUID.randomUUID());

        assertThat(foreign.status()).isEqualTo(200);
        assertThat(foreign.body()).isEqualTo(unknown.body()).isEqualTo("{\"days\":[]}");
        assertTooLarge(read(b, ""));
    }

    @Test
    void theDateRangeRulesAreUnchanged() {
        Account a = newAccount();
        String from = "/api/v1/usage?from=" + DAY + "&to=";

        assertThat(get(from + DAY.plusDays(UsageDays.MAX_HISTORY_DAYS), a.token()).status()).isEqualTo(200);
        assertThat(get(from + DAY.plusDays(UsageDays.MAX_HISTORY_DAYS + 1), a.token()).status()).isEqualTo(400);
        assertThat(get(from + DAY, a.token()).status()).isEqualTo(400);
    }
}
