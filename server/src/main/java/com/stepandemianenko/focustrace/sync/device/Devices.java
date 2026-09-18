package com.stepandemianenko.focustrace.sync.device;

import com.stepandemianenko.focustrace.sync.common.ApiException;
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

    private final JdbcClient jdbc;

    Devices(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /** Response DTO. Deliberately has no owner field. */
    record DeviceResponse(
            UUID deviceId, String displayName, String platform, Instant registeredAt, Instant lastSeenAt) {
    }

    record Registration(boolean created, DeviceResponse device) {
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
     */
    @Transactional
    Registration register(UUID userId, UUID deviceId, String displayName, String platform) {
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
