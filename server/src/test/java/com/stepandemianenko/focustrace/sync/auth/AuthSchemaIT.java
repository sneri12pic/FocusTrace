package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.stepandemianenko.focustrace.sync.IntegrationTest;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.FlywayException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.dao.DataIntegrityViolationException;

/** Database assertions for V2 (D03, D08): the constraints are the authority, so test them directly. */
class AuthSchemaIT extends IntegrationTest {

    @Test
    void canonicalEmailIsAccepted() {
        insertUser(UUID.randomUUID(), "canonical-" + UUID.randomUUID() + "@example.com");
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "Upper@example.com",
        " lead@example.com",
        "trail@example.com ",
        "\tuser@example.com",
        "in ner@example.com",
        "ctrl@example.com",
        "nbsp @example.com",
        "café@example.com"
    })
    void nonCanonicalEmailViolatesCheck(String email) {
        assertThatThrownBy(() -> insertUser(UUID.randomUUID(), email))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("users_email_canonical");
    }

    @Test
    void duplicateEmailViolatesUniqueKey() {
        String email = "dup-" + UUID.randomUUID() + "@example.com";
        insertUser(UUID.randomUUID(), email);

        assertThatThrownBy(() -> insertUser(UUID.randomUUID(), email))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("users_email_key");
    }

    @Test
    void refreshTokenCannotBeAttachedToAnotherUsersSession() {
        UUID alice = newUser();
        UUID bob = newUser();
        UUID alicesSession = insertSession(alice);

        assertThatThrownBy(() -> insertToken(bob, alicesSession, null))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("refresh_tokens_session_fk");
    }

    @Test
    void atMostOneCurrentTokenPerSession() {
        UUID user = newUser();
        UUID session = insertSession(user);
        insertToken(user, session, "now()");
        insertToken(user, session, "now()");
        insertToken(user, session, null);

        assertThatThrownBy(() -> insertToken(user, session, null))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("refresh_tokens_one_current_per_session");
    }

    @Test
    void sessionRevocationNeedsBothTimestampAndKnownReason() {
        UUID user = newUser();

        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO auth_sessions (id, user_id, absolute_expires_at, revoked_at) "
                        + "VALUES (?, ?, now() + interval '1 day', now())", UUID.randomUUID(), user))
                .hasMessageContaining("auth_sessions_revocation_consistent");
        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO auth_sessions (id, user_id, absolute_expires_at, revoked_at, revoked_reason) "
                        + "VALUES (?, ?, now() + interval '1 day', now(), 'bored')", UUID.randomUUID(), user))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void deletingUserCascadesToSessionsAndTokens() {
        UUID user = newUser();
        UUID session = insertSession(user);
        insertToken(user, session, null);

        jdbc.update("DELETE FROM users WHERE id = ?", user);

        assertThat(jdbc.queryForObject("SELECT count(*) FROM auth_sessions WHERE user_id = ?", Integer.class, user))
                .isZero();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_tokens WHERE user_id = ?", Integer.class, user))
                .isZero();
    }

    /**
     * V2 adds a NOT NULL column without a default. On a refresh_tokens table that is
     * not empty it must fail, not invent sessions; on an empty one it applies.
     * Runs against its own schemas so the shared one is untouched.
     */
    @Test
    void v2AppliesOnEmptyTablesAndRefusesExistingRefreshTokens() {
        Flyway empty = flywayFor("mig_empty_" + UUID.randomUUID().toString().replace("-", ""), "2");
        empty.migrate();
        assertThat(empty.info().current().getVersion().getVersion()).isEqualTo("2");

        String schema = "mig_nonempty_" + UUID.randomUUID().toString().replace("-", "");
        Flyway v1Only = flywayFor(schema, "1");
        v1Only.migrate();
        UUID user = UUID.randomUUID();
        jdbc.update("INSERT INTO " + schema + ".users (id, email, password_hash) VALUES (?, 'x@example.com', 'h')", user);
        jdbc.update("INSERT INTO " + schema + ".refresh_tokens (id, user_id, token_hash, expires_at) "
                + "VALUES (?, ?, '\\x00', now())", UUID.randomUUID(), user);

        assertThatThrownBy(() -> flywayFor(schema).migrate()).isInstanceOf(FlywayException.class);
        assertThat(flywayFor(schema).info().current().getVersion().getVersion()).isEqualTo("1");
    }

    private Flyway flywayFor(String schema) {
        return flywayFor(schema, "latest");
    }

    private Flyway flywayFor(String schema, String target) {
        return Flyway.configure()
                .dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .schemas(schema)
                .createSchemas(true)
                .target(target)
                .load();
    }

    private UUID newUser() {
        UUID id = UUID.randomUUID();
        insertUser(id, "schema-" + id + "@example.com");
        return id;
    }

    private void insertUser(UUID id, String email) {
        jdbc.update("INSERT INTO users (id, email, password_hash) VALUES (?, ?, 'not-a-real-hash')", id, email);
    }

    private UUID insertSession(UUID user) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO auth_sessions (id, user_id, absolute_expires_at) VALUES (?, ?, now() + interval '1 day')",
                id, user);
        return id;
    }

    private void insertToken(UUID user, UUID session, String revokedAtSql) {
        jdbc.update("INSERT INTO refresh_tokens (id, user_id, session_id, token_hash, expires_at, revoked_at) "
                        + "VALUES (?, ?, ?, ?, now() + interval '1 day', " + (revokedAtSql == null ? "NULL" : revokedAtSql) + ")",
                UUID.randomUUID(), user, session, randomBytes(32));
    }
}
