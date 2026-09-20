-- FocusTrace Backend Sync v1 - usage upload (Phase 1 Step 4).
-- Contract: docs/backend/backend-sync-architecture.md sections 6.2 and 9.1.
-- V1 and V2 have been applied to real PostgreSQL and are not edited.

-- A local day is 25 hours on a DST fall-back date. Attribution is exclusive, so
-- one app's total can reach the window length: 90,000 s. The V1 bound of 86,400
-- would reject that legitimate day, and the whole batch with it, on every retry.
-- Relaxing a CHECK cannot invalidate existing rows.
ALTER TABLE usage_day_apps
    DROP CONSTRAINT usage_day_apps_duration_seconds_check,
    ADD CONSTRAINT usage_day_apps_duration_seconds_check
        CHECK (duration_seconds >= 0 AND duration_seconds <= 90000);
