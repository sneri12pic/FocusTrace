package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.stepandemianenko.focustrace.sync.common.ApiException;
import org.springframework.http.HttpStatus;

import java.time.Duration;
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

    /** D18: a per-user bucket exhausts, is keyed per account, and refills on its own. */
    @Test
    void perUserBucketsRefillAndAreIndependentPerAccount() {
        AuthProperties.Limit limit = new AuthProperties.Limit(3, Duration.ofHours(6));
        AuthProperties.Limit unused = new AuthProperties.Limit(1, Duration.ofHours(1));
        AuthRateLimiter limiter = new AuthRateLimiter(new AuthProperties(null, null, new AuthProperties.RateLimit(
                100, unused, unused, unused, unused, unused, limit, unused, unused)), clock::get);
        String alice = "0b7e2c55-4a8e-4b8f-9d6a-1f2e3d4c5b6a";
        String bob = "5d1c0f2e-7b3a-4c9d-8e6f-a1b2c3d4e5f6";

        for (int i = 0; i < 3; i++) {
            limiter.acquire(AuthRateLimiter.Bucket.UPLOAD_PER_USER, alice);
        }
        assertThatThrownBy(() -> limiter.acquire(AuthRateLimiter.Bucket.UPLOAD_PER_USER, alice))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(e.retryAfterSeconds()).isEqualTo(TimeUnit.HOURS.toSeconds(2));
                });
        limiter.acquire(AuthRateLimiter.Bucket.UPLOAD_PER_USER, bob);
        limiter.acquire(AuthRateLimiter.Bucket.HISTORY_PER_USER, alice);

        clock.addAndGet(TimeUnit.HOURS.toNanos(2));
        limiter.acquire(AuthRateLimiter.Bucket.UPLOAD_PER_USER, alice);
        assertThatThrownBy(() -> limiter.acquire(AuthRateLimiter.Bucket.UPLOAD_PER_USER, alice))
                .isInstanceOf(ApiException.class);
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
