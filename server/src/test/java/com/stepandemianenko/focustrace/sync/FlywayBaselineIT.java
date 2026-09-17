package com.stepandemianenko.focustrace.sync;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Proves the Flyway baseline applies to real PostgreSQL and that the constraints
 * carrying sync idempotency actually exist.
 *
 * <p>Real PostgreSQL, not H2: the design depends on {@code ON CONFLICT ... WHERE},
 * composite foreign keys, {@code TIMESTAMPTZ} and {@code DATE} semantics. H2 would
 * verify a dialect this application never runs on.
 *
 * <p>The context also proves {@code ddl-auto=validate} starts cleanly.
 */
@SpringBootTest
@Testcontainers
class FlywayBaselineIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16-alpine");

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void baselineCreatesEveryTable() {
        List<String> tables = jdbc.queryForList(
                "SELECT table_name FROM information_schema.tables "
                        + "WHERE table_schema = 'public' ORDER BY table_name",
                String.class);

        assertThat(tables).containsExactly(
                "devices",
                "flyway_schema_history",
                "refresh_tokens",
                "usage_day_apps",
                "usage_days",
                "users");
    }

    @Test
    void usageDayIdentityIsDeviceAndLocalDate() {
        assertThat(primaryKeyColumnsOf("usage_days"))
                .containsExactly("device_id", "local_date");
    }

    @Test
    void usageDayAppIdentityIncludesAppKey() {
        assertThat(primaryKeyColumnsOf("usage_day_apps"))
                .containsExactly("device_id", "local_date", "app_key");
    }

    @Test
    void appRowsCannotOutliveTheirDay() {
        // Composite FK to usage_days is what prevents orphaned app rows.
        Integer foreignKeys = jdbc.queryForObject(
                "SELECT count(*) FROM information_schema.table_constraints "
                        + "WHERE table_name = 'usage_day_apps' AND constraint_type = 'FOREIGN KEY'",
                Integer.class);

        assertThat(foreignKeys).isEqualTo(1);
    }

    @Test
    void migrationIsRecordedAsApplied() {
        String version = jdbc.queryForObject(
                "SELECT version FROM flyway_schema_history WHERE success = true ORDER BY installed_rank DESC LIMIT 1",
                String.class);

        assertThat(version).isEqualTo("1");
    }

    private List<String> primaryKeyColumnsOf(String table) {
        return jdbc.queryForList(
                "SELECT kcu.column_name FROM information_schema.table_constraints tc "
                        + "JOIN information_schema.key_column_usage kcu "
                        + "  ON kcu.constraint_name = tc.constraint_name "
                        + "WHERE tc.table_name = ? AND tc.constraint_type = 'PRIMARY KEY' "
                        + "ORDER BY kcu.ordinal_position",
                String.class,
                table);
    }
}
