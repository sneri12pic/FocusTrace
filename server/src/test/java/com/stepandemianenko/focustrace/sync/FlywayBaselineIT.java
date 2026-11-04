package com.stepandemianenko.focustrace.sync;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Proves the Flyway migrations apply to real PostgreSQL and that the constraints
 * carrying sync idempotency actually exist.
 *
 * <p>Real PostgreSQL, not H2: the design depends on {@code ON CONFLICT ... WHERE},
 * composite foreign keys, {@code TIMESTAMPTZ} and {@code DATE} semantics. H2 would
 * verify a dialect this application never runs on.
 *
 * <p>The context also proves {@code ddl-auto=validate} starts cleanly.
 */
class FlywayBaselineIT extends IntegrationTest {

    @Test
    void migrationsCreateEveryTable() {
        List<String> tables = jdbc.queryForList(
                "SELECT table_name FROM information_schema.tables "
                        + "WHERE table_schema = 'public' ORDER BY table_name",
                String.class);

        assertThat(tables).containsExactly(
                "auth_sessions",
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
    void durationCheckAllowsA25HourDayAndNoMore() {
        // V3: the database bound matches the DTO bound; the API never reaches it.
        assertThat(checkClause("usage_day_apps_duration_seconds_check"))
                .contains("duration_seconds >= 0").contains("duration_seconds <= 90000");
    }

    private String checkClause(String constraint) {
        return jdbc.queryForObject("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = ?",
                String.class, constraint);
    }

    @Test
    void migrationsAreRecordedAsAppliedInOrder() {
        List<String> versions = jdbc.queryForList(
                "SELECT version FROM flyway_schema_history WHERE success = true ORDER BY installed_rank",
                String.class);

        assertThat(versions).containsExactly("1", "2", "3", "4", "5");
    }

    /**
     * V4: a plain index on refresh_tokens(session_id) for the D08 replay check and the
     * cascade from auth_sessions, beside - not replacing - V2's partial unique index.
     */
    @Test
    void refreshTokensAreIndexedBySession() {
        assertThat(indexDefinition("refresh_tokens_session_id_idx"))
                .isEqualTo("CREATE INDEX refresh_tokens_session_id_idx ON public.refresh_tokens USING btree (session_id)");
        assertThat(indexDefinition("refresh_tokens_one_current_per_session"))
                .isEqualTo("CREATE UNIQUE INDEX refresh_tokens_one_current_per_session ON public.refresh_tokens"
                        + " USING btree (session_id) WHERE (revoked_at IS NULL)");
    }

    /** V5: the rename flag defaults to false for existing rows; retention scans are indexed (architecture 6.4). */
    @Test
    void v5AddsTheRenameFlagAndRetentionIndexes() {
        assertThat(jdbc.queryForMap("""
                SELECT data_type, is_nullable, column_default FROM information_schema.columns
                 WHERE table_name = 'devices' AND column_name = 'display_name_by_user'"""))
                .containsEntry("data_type", "boolean")
                .containsEntry("is_nullable", "NO")
                .containsEntry("column_default", "false");
        assertThat(indexDefinition("refresh_tokens_expires_at_idx"))
                .isEqualTo("CREATE INDEX refresh_tokens_expires_at_idx ON public.refresh_tokens USING btree (expires_at)");
        assertThat(indexDefinition("auth_sessions_absolute_expires_at_idx"))
                .isEqualTo("CREATE INDEX auth_sessions_absolute_expires_at_idx ON public.auth_sessions"
                        + " USING btree (absolute_expires_at)");
    }

    private String indexDefinition(String index) {
        return jdbc.queryForObject("SELECT indexdef FROM pg_indexes WHERE indexname = ?", String.class, index);
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
