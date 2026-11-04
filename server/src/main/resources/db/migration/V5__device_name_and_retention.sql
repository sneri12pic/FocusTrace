-- FocusTrace Backend Sync v1 - device rename and auth-row retention.
-- Contract: docs/backend/backend-sync-architecture.md sections 6.4 and 9.5.
-- V1-V4 have been applied to real PostgreSQL and are not edited.

-- A name the account holder chose (PATCH /api/v1/devices/{id}) survives the
-- client's routine re-registration, which sends Build.MODEL on every sync run.
-- Existing rows were all named by the client, hence the default.
ALTER TABLE devices
    ADD COLUMN display_name_by_user BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN devices.display_name_by_user IS
    'True once the account holder renamed the device; registration then keeps display_name.';

-- Retention cleanup (AuthRetention) finds dead tokens and sessions by these
-- columns. Without them each nightly run scans both tables in full.
CREATE INDEX refresh_tokens_expires_at_idx ON refresh_tokens (expires_at);
CREATE INDEX auth_sessions_absolute_expires_at_idx ON auth_sessions (absolute_expires_at);
