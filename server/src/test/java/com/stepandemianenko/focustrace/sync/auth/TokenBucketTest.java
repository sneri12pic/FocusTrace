package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

/** D15 limiter mechanics, on a fake clock. */
class TokenBucketTest {

    private static final long HOUR = TimeUnit.HOURS.toNanos(1);

    private final AtomicLong clock = new AtomicLong(1_000_000_000L);

    @Test
    void allowsCapacityThenRejectsWithTimeToNextToken() {
        AuthRateLimiter.TokenBucket bucket = new AuthRateLimiter.TokenBucket(5, HOUR, 100, clock::get);

        for (int i = 0; i < 5; i++) {
            assertThat(bucket.tryAcquire("a")).isZero();
        }
        long wait = bucket.tryAcquire("a");

        assertThat(wait).isEqualTo(HOUR / 5);
    }

    @Test
    void refillsContinuouslyWithoutAWindowBoundaryBurst() {
        AuthRateLimiter.TokenBucket bucket = new AuthRateLimiter.TokenBucket(5, HOUR, 100, clock::get);
        for (int i = 0; i < 5; i++) {
            bucket.tryAcquire("a");
        }

        clock.addAndGet(HOUR / 5);
        assertThat(bucket.tryAcquire("a")).isZero();
        // One token refilled, not a fresh window of five.
        assertThat(bucket.tryAcquire("a")).isPositive();
    }

    @Test
    void keysAreIndependent() {
        AuthRateLimiter.TokenBucket bucket = new AuthRateLimiter.TokenBucket(1, HOUR, 100, clock::get);

        assertThat(bucket.tryAcquire("a")).isZero();
        assertThat(bucket.tryAcquire("a")).isPositive();
        assertThat(bucket.tryAcquire("b")).isZero();
    }

    @Test
    void idleEntriesExpireAfterTheirRefillPeriod() {
        AuthRateLimiter.TokenBucket bucket = new AuthRateLimiter.TokenBucket(5, HOUR, 100, clock::get);
        for (int i = 0; i < 50; i++) {
            bucket.tryAcquire("idle-" + i);
        }
        assertThat(bucket.size()).isEqualTo(50);

        clock.addAndGet(HOUR / 5 + 1);
        bucket.tryAcquire("fresh");

        assertThat(bucket.size()).isEqualTo(1);
    }

    @Test
    void entriesStillRefillingAreNotSwept() {
        AuthRateLimiter.TokenBucket bucket = new AuthRateLimiter.TokenBucket(5, HOUR, 100, clock::get);
        for (int i = 0; i < 5; i++) {
            bucket.tryAcquire("busy");
        }

        clock.addAndGet(HOUR / 2);
        bucket.tryAcquire("other");

        assertThat(bucket.size()).isEqualTo(2);
        assertThat(bucket.tryAcquire("busy")).isZero();
    }

    @Test
    void mapIsBoundedUnderKeyFlooding() {
        AuthRateLimiter.TokenBucket bucket = new AuthRateLimiter.TokenBucket(5, HOUR, 1_000, clock::get);

        for (int i = 0; i < 50_000; i++) {
            bucket.tryAcquire("flood-" + i);
        }

        assertThat(bucket.size()).isLessThanOrEqualTo(1_000);
    }
}
