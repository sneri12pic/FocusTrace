package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Shared helpers for session and refresh-token tests. */
abstract class SessionTestSupport extends IntegrationTest {

    /** Outcome of one race; {@code overlapped} is true when both requests were in flight at once. */
    record Race(List<Response> results, boolean overlapped) {
    }

    /** Two threads released together by a latch, each presenting {@code token}. No 5xx allowed. */
    Race raceRefresh(String token) {
        CountDownLatch start = new CountDownLatch(1);
        try (ExecutorService pool = Executors.newFixedThreadPool(2)) {
            List<CompletableFuture<Timed>> futures = List.of(
                    CompletableFuture.supplyAsync(() -> awaitThenRefresh(start, token), pool),
                    CompletableFuture.supplyAsync(() -> awaitThenRefresh(start, token), pool));
            start.countDown();
            List<Timed> timed = futures.stream().map(CompletableFuture::join).toList();
            List<Response> results = timed.stream().map(Timed::response).toList();
            assertThat(results).allSatisfy(r -> assertThat(r.status()).as(r.body()).isLessThan(500));
            Timed a = timed.get(0);
            Timed b = timed.get(1);
            return new Race(results, a.startNanos() < b.endNanos() && b.startNanos() < a.endNanos());
        }
    }

    private record Timed(Response response, long startNanos, long endNanos) {
    }

    private Timed awaitThenRefresh(CountDownLatch start, String token) {
        try {
            start.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
        long begin = System.nanoTime();
        Response response = refresh(token);
        return new Timed(response, begin, System.nanoTime());
    }

    Map<String, Object> sessionOf(String refreshToken) {
        return jdbc.queryForMap("SELECT s.* FROM auth_sessions s JOIN refresh_tokens t ON t.session_id = s.id "
                + "WHERE t.token_hash = ?", (Object) AuthSessions.sha256(refreshToken));
    }

    int liveTokens(String anyTokenOfSession) {
        return jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE session_id = ? AND revoked_at IS NULL",
                Integer.class, sessionOf(anyTokenOfSession).get("id"));
    }
}
