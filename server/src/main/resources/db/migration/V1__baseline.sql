-- FocusTrace Backend Sync v1 baseline.
-- Contract: docs/backend/backend-sync-architecture.md section 6.
--
-- The constraints here are load-bearing, not decoration:
--   usage_days     PK (device_id, local_date)            makes a repeated upload
--                                                        unable to duplicate a day
--   usage_day_apps PK (device_id, local_date, app_key)   makes a repeated upload
--                                                        unable to duplicate an app row
-- Idempotency is enforced by the database, not by an application-side existence
-- check. Do not relax these to make a test easier to write.

CREATE TABLE users (
    id            UUID PRIMARY KEY,
    email         TEXT        NOT NULL,
    password_hash TEXT        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_email_key UNIQUE (email)
);

COMMENT ON COLUMN users.email IS 'Stored already lower-cased and trimmed by the service layer.';

CREATE TABLE devices (
    id            UUID PRIMARY KEY,
    user_id       UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    display_name  TEXT        NOT NULL,
    platform      TEXT        NOT NULL CHECK (platform IN ('android', 'windows')),
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at  TIMESTAMPTZ
);

COMMENT ON COLUMN devices.id IS 'Client-generated installation UUID. Never a hardware or advertising identifier.';

CREATE INDEX devices_user_id_idx ON devices (user_id);

CREATE TABLE usage_days (
    device_id        UUID        NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
    local_date       DATE        NOT NULL,
    snapshot_version BIGINT      NOT NULL CHECK (snapshot_version > 0),
    timezone_id      TEXT        NOT NULL,
    source_status    TEXT        NOT NULL CHECK (source_status IN ('partial', 'reconciled', 'imported')),
    received_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (device_id, local_date)
);

COMMENT ON COLUMN usage_days.snapshot_version IS
    'Device-local ordering token (usage_snapshot_days.queried_at_ms). Higher wins; equal is a duplicate; lower is stale.';
COMMENT ON COLUMN usage_days.local_date IS
    'Calendar date as the device recorded it. Never converted server-side; timezone_id records the originating zone.';

CREATE INDEX usage_days_device_date_idx ON usage_days (device_id, local_date DESC);

CREATE TABLE usage_day_apps (
    device_id        UUID    NOT NULL,
    local_date       DATE    NOT NULL,
    app_key          TEXT    NOT NULL,
    app_name         TEXT    NOT NULL,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0 AND duration_seconds <= 86400),
    launch_count     INTEGER NOT NULL CHECK (launch_count >= 0),
    PRIMARY KEY (device_id, local_date, app_key),
    FOREIGN KEY (device_id, local_date)
        REFERENCES usage_days (device_id, local_date) ON DELETE CASCADE
);

COMMENT ON COLUMN usage_day_apps.app_key IS
    'AppUsageSummary.appKey: packageName ?? processName ?? appName. Not always a package name.';

CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY,
    user_id    UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash BYTEA       NOT NULL,
    issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT refresh_tokens_hash_key UNIQUE (token_hash)
);

CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);
