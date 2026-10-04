-- FocusTrace Backend Sync v1 - authentication schema.
-- Contract: docs/backend/backend-sync-architecture.md section 5.1 (D03, D08) and 6.1.
-- V1__baseline.sql has been applied to real PostgreSQL and is not edited.

-- D03: the database, not the service layer, is the final authority on identity.
-- users_email_key UNIQUE (email) from V1 is kept; this CHECK is what makes the
-- value it indexes always canonical, so uniqueness over it is uniqueness over
-- identities.
--   lower(email) = email  : stored lower-case. Over U+0021-U+007E this is
--                           exactly Java toLowerCase(Locale.ROOT).
--   ~ '^[!-~]+$'          : printable ASCII only. Excludes whitespace and
--                           control characters outright, which is why no SQL
--                           equivalent of Java's trimming rule is needed.
ALTER TABLE users
    ADD CONSTRAINT users_email_canonical
    CHECK (email = lower(email) AND email ~ '^[!-~]+$');

COMMENT ON COLUMN users.email IS
    'Canonical form (D03): U+0020 stripped at both ends, printable ASCII only, lower-cased with Locale.ROOT.';

-- D08: a login session is the revocation unit. A replayed token kills its own
-- session, not every session the user has.
CREATE TABLE auth_sessions (
    id                  UUID PRIMARY KEY,
    user_id             UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    absolute_expires_at TIMESTAMPTZ NOT NULL,
    revoked_at          TIMESTAMPTZ,
    revoked_reason      TEXT CHECK (revoked_reason IN ('logout', 'password_change', 'token_reuse')),
    CONSTRAINT auth_sessions_revocation_consistent
        CHECK ((revoked_at IS NULL) = (revoked_reason IS NULL)),
    CONSTRAINT auth_sessions_id_user_key UNIQUE (id, user_id)
);

CREATE INDEX auth_sessions_user_id_idx ON auth_sessions (user_id);

-- NOT NULL without a default requires refresh_tokens to be empty, which it is:
-- no authentication code ran before this migration. On a non-empty table this
-- migration fails rather than inventing sessions.
--
-- The composite foreign key (session_id, user_id) makes it impossible to attach
-- a refresh token to a session belonging to a different user; this is why the
-- otherwise redundant refresh_tokens.user_id from V1 is kept.
ALTER TABLE refresh_tokens
    ADD COLUMN session_id UUID NOT NULL,
    ADD CONSTRAINT refresh_tokens_session_fk
        FOREIGN KEY (session_id, user_id)
        REFERENCES auth_sessions (id, user_id) ON DELETE CASCADE;

-- At most one live token per session: rotation invalidating its predecessor is a
-- database invariant, not an application intention. Last-line defence only; the
-- conditional UPDATE in D08 is the concurrency mechanism.
CREATE UNIQUE INDEX refresh_tokens_one_current_per_session
    ON refresh_tokens (session_id) WHERE revoked_at IS NULL;

COMMENT ON COLUMN refresh_tokens.token_hash IS
    'SHA-256 of the opaque token string. The plaintext token is never stored.';
