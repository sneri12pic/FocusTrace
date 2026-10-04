package com.stepandemianenko.focustrace.sync.device;

import com.stepandemianenko.focustrace.sync.common.ApiException;
import com.stepandemianenko.focustrace.sync.common.SyncLimits;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Device registry (architecture sections 3 and 9, D12, D16). Every statement
 * carries the caller's {@code user_id} as a predicate or as the inserted owner;
 * no statement reads a device by id alone. {@code user_id} comes only from the
 * authenticated principal.
 */
@Component
class Devices {

    private static final Logger securityLog = LoggerFactory.getLogger("focustrace.security");

    private static final String COLUMNS = "id, display_name, platform, registered_at, last_seen_at";

    /**
     * D18 "active". {@code now()} is the transaction start time in PostgreSQL, so every
     * use within one registration shares one cutoff: classification and count cannot
     * straddle the window boundary.
     */
    private static final String ACTIVE = "COALESCE(last_seen_at, registered_at)"
            + " > now() - CAST(:windowSeconds AS bigint) * interval '1 second'";

    private final JdbcClient jdbc;
    private final SyncLimits limits;

    Devices(JdbcClient jdbc, SyncLimits limits) {
        this.jdbc = jdbc;
        this.limits = limits;
    }

    /** Response DTO. Deliberately has no owner field. */
    record DeviceResponse(
            UUID deviceId, String displayName, String platform, Instant registeredAt, Instant lastSeenAt) {
    }

    record Registration(boolean created, DeviceResponse device) {
    }

    private record Existing(boolean own, boolean active) {
    }

    /**
     * Idempotent on the installation UUID. Two statements, each deciding by its
     * returned row:
     * <ol>
     *   <li>insert under the caller, or do nothing if the UUID exists (whoever owns it);
     *   <li>otherwise update the row only if the caller owns it.
     * </ol>
     * Neither matching means another account owns the UUID: 409 per D12, with no
     * write and nothing about the owner in the response. Ownership never moves,
     * because no statement here assigns {@code user_id} to an existing row.
     * {@code platform} is fixed at first registration; an installation does not
     * change operating system.
     *
     * <p>D18 quota: at most {@code maxActiveDevices} of the caller's devices may be
     * active. A registration that would make a device active - a new UUID, or the
     * caller's own inactive device (reactivation) - needs a free slot; otherwise 403
     * and nothing is written. Re-registering an already-active device takes no slot.
     * Another account's UUID is never quota-checked and stays a 409. Locking the
     * caller's {@code users} row first serializes every registration of one account,
     * so the count cannot be raced; other accounts and uploads are not blocked
     * ({@code NO KEY UPDATE} does not conflict with the foreign-key {@code KEY SHARE}).
     */
    @Transactional
    Registration register(UUID userId, UUID deviceId, String displayName, String platform) {
        jdbc.sql("SELECT 1 FROM users WHERE id = :userId FOR NO KEY UPDATE")
                .param("userId", userId)
                .query(Integer.class)
                .optional()
                .orElseThrow(ApiException::unauthorized);
        // Empty for a new UUID. A foreign UUID takes no slot: the owner-scoped
        // statements below turn it into D12's 409, exactly as before.
        Optional<Existing> existing = jdbc.sql(
                        "SELECT user_id = :userId AS own, " + ACTIVE + " AS active FROM devices WHERE id = :id")
                .param("id", deviceId)
                .param("userId", userId)
                .param("windowSeconds", limits.deviceActiveWindow().toSeconds())
                .query((rs, row) -> new Existing(rs.getBoolean("own"), rs.getBoolean("active")))
                .optional();
        boolean takesSlot = existing.map(e -> e.own() && !e.active()).orElse(true);
        if (takesSlot && activeDevices(userId) >= limits.maxActiveDevices()) {
            securityLog.warn("event=device_quota_exceeded userId={}", userId);
            throw ApiException.forbidden("This account has reached its device limit.");
        }

        Optional<DeviceResponse> created = jdbc.sql("""
                        INSERT INTO devices (id, user_id, display_name, platform, last_seen_at)
                        VALUES (:id, :userId, :displayName, :platform, now())
                        ON CONFLICT (id) DO NOTHING
                        RETURNING\s""" + COLUMNS)
                .param("id", deviceId)
                .param("userId", userId)
                .param("displayName", displayName)
                .param("platform", platform)
                .query(Devices::toResponse)
                .optional();
        if (created.isPresent()) {
            return new Registration(true, created.get());
        }

        Optional<DeviceResponse> updated = jdbc.sql("""
                        UPDATE devices
                           SET display_name = :displayName,
                               last_seen_at = now()
                         WHERE id = :id
                           AND user_id = :userId
                        RETURNING\s""" + COLUMNS)
                .param("id", deviceId)
                .param("userId", userId)
                .param("displayName", displayName)
                .query(Devices::toResponse)
                .optional();
        if (updated.isPresent()) {
            return new Registration(false, updated.get());
        }

        securityLog.warn("event=device_id_conflict userId={} deviceId={}", userId, deviceId);
        throw ApiException.conflict("This device ID is already registered to another account.");
    }

    private int activeDevices(UUID userId) {
        return jdbc.sql("SELECT count(*) FROM devices WHERE user_id = :userId AND " + ACTIVE)
                .param("userId", userId)
                .param("windowSeconds", limits.deviceActiveWindow().toSeconds())
                .query(Integer.class)
                .single();
    }

    List<DeviceResponse> list(UUID userId) {
        return jdbc.sql("SELECT " + COLUMNS + " FROM devices WHERE user_id = :userId ORDER BY registered_at, id")
                .param("userId", userId)
                .query(Devices::toResponse)
                .list();
    }

    private static DeviceResponse toResponse(ResultSet rs, int row) throws SQLException {
        OffsetDateTime lastSeen = rs.getObject("last_seen_at", OffsetDateTime.class);
        return new DeviceResponse(
                rs.getObject("id", UUID.class),
                rs.getString("display_name"),
                rs.getString("platform"),
                rs.getObject("registered_at", OffsetDateTime.class).toInstant(),
                lastSeen == null ? null : lastSeen.toInstant());
    }
}
