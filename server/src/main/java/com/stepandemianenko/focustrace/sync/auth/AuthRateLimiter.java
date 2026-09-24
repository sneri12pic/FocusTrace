package com.stepandemianenko.focustrace.sync.auth;

import com.stepandemianenko.focustrace.sync.common.ApiException;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.function.LongSupplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * D15: in-process token buckets for the anonymous flows. Each dimension is an
 * independent limiter, so one source trying many accounts and many sources trying
 * one account are each stopped by their own bucket.
 *
 * <p>D18: the same buckets, keyed by the authenticated account id, throttle the
 * expensive authenticated routes ({@link PerUser}, {@link PerUserRateLimitInterceptor}).
 * In-process: correct for the single instance this deployment has, not distributed.
 */
@Component
public class AuthRateLimiter {

    private static final Logger securityLog = LoggerFactory.getLogger("focustrace.security");

    public enum Bucket {
        REGISTER_PER_SOURCE,
        LOGIN_PER_SOURCE,
        LOGIN_PER_ACCOUNT,
        REFRESH_PER_SOURCE,
        DEVICE_REGISTER_PER_USER,
        UPLOAD_PER_USER,
        HISTORY_PER_USER,
        ACCOUNT_DELETE_PER_USER
    }

    /**
     * D18: marks an authenticated handler method as charged to {@code value}, keyed by
     * the token's {@code sub}. Checked before the request body is read.
     */
    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.METHOD)
    public @interface PerUser {
        Bucket value();
    }

    private final Map<Bucket, TokenBucket> limiters = new EnumMap<>(Bucket.class);

    @Autowired
    AuthRateLimiter(AuthProperties properties) {
        this(properties, System::nanoTime);
    }

    /** Tests pass a fake monotonic clock. */
    AuthRateLimiter(AuthProperties properties, LongSupplier clock) {
        AuthProperties.RateLimit config = properties.rateLimit();
        int maxEntries = config.maxEntriesPerLimiter();
        limiters.put(Bucket.REGISTER_PER_SOURCE, TokenBucket.of(config.registerPerSource(), maxEntries, clock));
        limiters.put(Bucket.LOGIN_PER_SOURCE, TokenBucket.of(config.loginPerSource(), maxEntries, clock));
        limiters.put(Bucket.LOGIN_PER_ACCOUNT, TokenBucket.of(config.loginPerAccount(), maxEntries, clock));
        limiters.put(Bucket.REFRESH_PER_SOURCE, TokenBucket.of(config.refreshPerSource(), maxEntries, clock));
        limiters.put(Bucket.DEVICE_REGISTER_PER_USER, TokenBucket.of(config.deviceRegisterPerUser(), maxEntries, clock));
        limiters.put(Bucket.UPLOAD_PER_USER, TokenBucket.of(config.uploadPerUser(), maxEntries, clock));
        limiters.put(Bucket.HISTORY_PER_USER, TokenBucket.of(config.historyPerUser(), maxEntries, clock));
        limiters.put(Bucket.ACCOUNT_DELETE_PER_USER, TokenBucket.of(config.accountDeletePerUser(), maxEntries, clock));
    }

    /**
     * Takes one token or throws a generic 429. The key is a socket peer address, a
     * canonical email or an authenticated account id - never request input for the
     * latter. Only the bucket name is logged, never an account identifier.
     */
    void acquire(Bucket bucket, String key) {
        long waitNanos = limiters.get(bucket).tryAcquire(key);
        if (waitNanos > 0) {
            securityLog.warn("event=rate_limited bucket={}", bucket);
            throw ApiException.tooManyRequests(Math.max(1, TimeUnit.NANOSECONDS.toSeconds(waitNanos + 999_999_999)));
        }
    }

    /**
     * A token bucket in GCRA form: per key, one {@code long} - the time at which the
     * bucket would be full again. {@code capacity} requests may burst; after that one
     * is admitted every {@code period / capacity}. No window boundary to double up on.
     *
     * <p>Bounded: an entry whose full-again time has passed carries no information
     * (absent means full) and is swept; above {@code maxEntries} the least recently
     * used entry is evicted.
     */
    static final class TokenBucket {

        private static final long SWEEP_INTERVAL_NANOS = TimeUnit.SECONDS.toNanos(1);

        private final long emissionIntervalNanos;
        private final long burstToleranceNanos;
        private final int maxEntries;
        private final LongSupplier nanoClock;
        private final LinkedHashMap<String, Long> fullAt;
        private long lastSweep;

        TokenBucket(int capacity, long periodNanos, int maxEntries, LongSupplier nanoClock) {
            this.emissionIntervalNanos = periodNanos / capacity;
            this.burstToleranceNanos = periodNanos - emissionIntervalNanos;
            this.maxEntries = maxEntries;
            this.nanoClock = nanoClock;
            this.lastSweep = nanoClock.getAsLong();
            this.fullAt = new LinkedHashMap<>(16, 0.75f, true) {
                @Override
                protected boolean removeEldestEntry(Map.Entry<String, Long> eldest) {
                    return size() > TokenBucket.this.maxEntries;
                }
            };
        }

        static TokenBucket of(AuthProperties.Limit limit, int maxEntries, LongSupplier nanoClock) {
            return new TokenBucket(limit.capacity(), limit.period().toNanos(), maxEntries, nanoClock);
        }

        /** Zero when admitted; otherwise nanoseconds until the next token. */
        // ponytail: one lock per limiter; auth traffic is a few requests per user per day.
        synchronized long tryAcquire(String key) {
            long now = nanoClock.getAsLong();
            if (now - lastSweep >= SWEEP_INTERVAL_NANOS || fullAt.size() >= maxEntries) {
                fullAt.values().removeIf(t -> t - now <= 0);
                lastSweep = now;
            }
            Long stored = fullAt.get(key);
            long tat = stored == null || stored - now < 0 ? now : stored;
            long wait = tat - now - burstToleranceNanos;
            if (wait > 0) {
                return wait;
            }
            fullAt.put(key, tat + emissionIntervalNanos);
            return 0;
        }

        synchronized int size() {
            return fullAt.size();
        }
    }
}
