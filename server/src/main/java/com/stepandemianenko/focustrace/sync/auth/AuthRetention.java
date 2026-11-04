package com.stepandemianenko.focustrace.sync.auth;

import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Retention for authentication rows (architecture 6.4). Every login adds an
 * {@code auth_sessions} row and every refresh a {@code refresh_tokens} row; without
 * this job neither table ever shrinks.
 *
 * <p>Only rows that can no longer change an outcome are deleted, and only once they
 * have been dead for {@code retention}, so recent ones stay for log correlation:
 * <ul>
 *   <li>A token past {@code expires_at} is already rejected without any D08 replay
 *       action ({@link AuthSessions#rotate} classifies it {@code token_expired}), and
 *       {@code expires_at} never decreases within a session, so no newer token's
 *       replay check reads it. Deleting it turns {@code token_expired} into
 *       {@code unknown_token}: the same 401, the same absence of side effects.
 *   <li>A session that was revoked, passed its absolute expiry, or holds no token that
 *       is still valid can never issue a token again. Its remaining tokens go with it
 *       through {@code ON DELETE CASCADE}; presenting one is again a plain 401.
 * </ul>
 *
 * <p>Each statement is its own short transaction (no {@code @Transactional}) and works
 * in bounded batches, so the job never holds many row locks, never holds a child row
 * while waiting for another, and so cannot form a lock cycle with account deletion
 * (D19) or rotation. A failed run changes nothing that the next run cannot redo.
 */
@Component
public class AuthRetention {

    private static final Logger log = LoggerFactory.getLogger(AuthRetention.class);
    static final int BATCH = 5_000;

    private final JdbcClient jdbc;
    private final Duration retention;

    AuthRetention(JdbcClient jdbc, @Value("${focustrace.maintenance.auth-retention}") Duration retention) {
        if (retention.isNegative()) {
            throw new IllegalStateException("focustrace.maintenance.auth-retention must not be negative");
        }
        this.jdbc = jdbc;
        this.retention = retention;
    }

    public record Result(int tokens, int sessions) {
    }

    @Scheduled(cron = "${focustrace.maintenance.auth-cleanup-cron}", zone = "UTC")
    void scheduled() {
        try {
            Result result = purge();
            log.info("event=auth_retention_purge tokens={} sessions={}", result.tokens(), result.sessions());
        } catch (RuntimeException e) {
            // The next run retries; the service keeps serving either way.
            log.error("event=auth_retention_failed", e);
        }
    }

    /** Deletes dead tokens, then dead sessions. Returns the number of rows of each removed. */
    public Result purge() {
        long retentionMs = retention.toMillis();
        int tokens = 0;
        int batch;
        do {
            batch = jdbc.sql("""
                            DELETE FROM refresh_tokens
                             WHERE id IN (SELECT id FROM refresh_tokens
                                           WHERE expires_at < now() - :retentionMs * interval '1 millisecond'
                                           LIMIT :batch)""")
                    .param("retentionMs", retentionMs)
                    .param("batch", BATCH)
                    .update();
            tokens += batch;
        } while (batch == BATCH);

        int sessions = 0;
        do {
            batch = jdbc.sql("""
                            DELETE FROM auth_sessions
                             WHERE id IN (SELECT s.id FROM auth_sessions s
                                           WHERE s.revoked_at < now() - :retentionMs * interval '1 millisecond'
                                              OR s.absolute_expires_at < now() - :retentionMs * interval '1 millisecond'
                                              OR (s.created_at < now() - :retentionMs * interval '1 millisecond'
                                                  AND NOT EXISTS (SELECT 1 FROM refresh_tokens t
                                                                   WHERE t.session_id = s.id
                                                                     AND t.expires_at >= now() - :retentionMs * interval '1 millisecond'))
                                           LIMIT :batch)""")
                    .param("retentionMs", retentionMs)
                    .param("batch", BATCH)
                    .update();
            sessions += batch;
        } while (batch == BATCH);
        return new Result(tokens, sessions);
    }
}
