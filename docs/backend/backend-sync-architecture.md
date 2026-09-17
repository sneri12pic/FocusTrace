# FocusTrace Backend Sync v1 - Architecture

Status: design, not implemented.
Branch: `feature/backend-sync-v1`.
Stack decision (final): Java + Spring Boot + PostgreSQL.

This document is the design source of truth for Sync v1. It is written against the
local model as it exists today in `lib/src/data/datasources/focus_trace_local_data_source.dart`
(schema v5) and `android/app/src/main/kotlin/.../UsageSnapshotStore.kt`.

This document owns **decisions**. Stage scope, implementation sequence, acceptance
criteria and remaining work live in `backend-sync-v1-plan.md`; current
implementation state lives in `backend-sync-v1-progress.md`. Do not turn this file
into a work log.

---

## 1. Position in the system

FocusTrace stays local-first. Sync is a side channel, never a dependency.

```text
Android UsageStats
      |
      v
local SQLite (focus_trace.db)  <-- authoritative for tracking, restrictions, UI
      |
      v
sync layer (new, opt-in, background)
      |
      v
Spring Boot REST API  ->  PostgreSQL
```

The backend is never on the path of tracking, persistence, restriction enforcement,
or offline behaviour. If the server is unreachable, wrong, or switched off, the app
behaves exactly as it does today.

---

## 2. Current local model

### 2.1 SQLite tables (schema v5)

| Table | Columns | Role |
| --- | --- | --- |
| `daily_app_usage` | `day TEXT`, `app_key TEXT`, `app_name TEXT`, `package_name TEXT?`, `process_name TEXT?`, `duration_seconds INTEGER`, `launch_count INTEGER`; PK `(day, app_key)` | Per-app totals per local day. The only durable usage history. |
| `usage_snapshot_days` | `day TEXT PK`, `start_ms`, `end_ms`, `timezone_id TEXT`, `queried_at_ms`, `covered_until_ms`, `status IN ('partial','unavailable','reconciled')` | Device-local evidence about how a day was queried from the OS. Explicitly non-portable. |
| `usage_sessions` | `id`, `platform`, `app_name`, `package_name`, `process_name`, `window_title`, `started_at`, `ended_at`, `duration_seconds`, `category`, `created_at` | Windows desktop session tracking. Unused on Android. |
| `usage_intervals` | `id`, `app_key`, `app_name`, `started_at`, `ended_at` | Fine-grained timeline backing the detail charts. |
| `restriction_events` | `id`, `app_key`, `app_name`, `event_type`, `reason`, `occurred_at` | Local blocking telemetry for reports. |
| `settings` | `key TEXT PK`, `value TEXT` | Key/value store: restriction rules, block routines, excluded apps, onboarding flags, `usage_recovery_generation`. |

### 2.2 Facts that drive the design

- **`day` is already a local calendar date string** (`YYYY-MM-DD`, `_dayKey`), not an
  instant. `usage_snapshot_days.timezone_id` records the zone that produced it.
  The server must store it as a `DATE` plus the zone id and never convert.
- **`app_key` is not always a package name.** `AppUsageSummary.appKey` resolves to
  `packageName ?? processName ?? appName`. On Android it is the package name; on
  Windows it can be a process or display name. The server column is therefore
  `app_key`, not `package_name`.
- **A day is already a complete replaceable snapshot.** Both writers
  (`saveDailySummaries` in Dart and `UsageSnapshotStore.replaceDay` in Kotlin)
  delete the day and reinsert it inside one transaction. Whole-day replacement is
  the existing semantics, not a new invention.
- **`queried_at_ms` is a per-day monotonic-ish version already present.** It only
  advances when the day is re-queried from the OS. This is the natural snapshot
  version; no new local column is required for Phase 1.
- **There is no `synced` flag anywhere.** The sync client has to derive what to
  upload; see 8.2.
- **Icons are never persisted** (`getDailySummaries` drops `iconBytes`), so the
  privacy question "do we upload icons" is already answered: there are none to
  upload.

### 2.3 Classification for Sync v1

**Synchronized:**

- `daily_app_usage`: `day`, `app_key`, `app_name`, `duration_seconds`, `launch_count`
- from `usage_snapshot_days`: `timezone_id`, `queried_at_ms` (as the snapshot
  version), `status`

**Local-only, never uploaded in v1:**

- `usage_sessions` - contains `window_title`, which can leak document names,
  URLs and message subjects. Highest-sensitivity table in the app.
- `usage_intervals` - see 4.1.
- `restriction_events` - enforcement telemetry, no cross-device value yet.
- `settings` - restriction rules, block routines, excluded apps. Explicitly out of
  scope per the milestone brief.
- `usage_snapshot_days` coverage internals (`start_ms`, `end_ms`,
  `covered_until_ms`) - device-local OS-query evidence, meaningless on a server.
- `package_name` / `process_name` as separate columns - redundant with `app_key`.

**Explicitly excluded, permanently:** notification contents, window/page contents,
raw `UsageEvents` dumps, contacts, messages, advertising ids, hardware serials.

---

## 3. Device identity

Each installation generates a random UUID v4 on first run and stores it in the
existing `settings` table under key `sync_installation_id`.

- Generated by the app, not derived from hardware.
- Not IMEI, not `ANDROID_ID`, not a serial, not an advertising id.
- Cleared by **Clear Local Data** and by a reinstall; the device then registers as
  a new device. That is correct behaviour, not a bug.
- The UUID is the primary key of `devices` server-side. No surrogate id.

A `display_name` (user-editable, defaults to `Build.MODEL`) and `platform`
(`android` / `windows`) are stored for UI only.

---

## 4. Server domain model

```text
User 1---* Device 1---* UsageDay 1---* UsageDayApp
User 1---* RefreshToken
```

| Entity | Purpose |
| --- | --- |
| `User` | Account. Email + Argon2id password hash. |
| `Device` | One FocusTrace installation. PK is the client-generated installation UUID. |
| `UsageDay` | One device's complete snapshot of one local calendar day. Carries `snapshot_version`. |
| `UsageDayApp` | One app's totals inside that day. |
| `RefreshToken` | Hashed, rotating, revocable session handle. |

Sync metadata lives **on** `UsageDay` (`snapshot_version`, `source_status`,
`timezone_id`, `received_at`) rather than in a separate table. A separate sync
metadata table buys nothing at this scale.

### 4.1 Decision: `UsageInterval` is NOT synchronized in v1

Intervals exist to render the per-app detail charts on the device that produced
them. Uploading them would multiply row count by roughly two orders of magnitude,
turn a coarse daily total into a minute-by-minute behavioural trace (a materially
larger privacy exposure), and buy nothing for the Phase 2 proof, which is "Device B
can see Device A's history". Daily totals answer that.

If interval sync is ever needed, it is an additive table plus a second endpoint.
Not now.

---

## 5. Authentication and authorization

### 5.1 Authentication

Email + password registration, then bearer tokens.

- **Password hashing:** Spring Security `PasswordEncoder`, Argon2id (delegating
  encoder so the hash format is upgradeable). Plaintext is never stored or logged.
- **Access token:** stateless JWT (HS256), TTL 15 minutes, claims `sub` (user id),
  `iat`, `exp`, `jti`. Validated by a `OncePerRequestFilter` in front of the
  stateless `SecurityFilterChain`.
- **Refresh token:** opaque 256-bit random value, returned once, stored only as a
  SHA-256 hash in `refresh_tokens`. Rotated on every use; the consumed row is
  marked revoked. Reuse of a revoked token revokes the whole chain for that user.
  TTL 60 days.
- **Signing secret:** injected via environment variable
  (`FOCUSTRACE_JWT_SECRET`). Never committed. The app fails to start if it is
  absent or shorter than 32 bytes - no insecure default.

Short-lived access tokens plus a revocable refresh token is the reason there is a
token table at all: a 30-day non-revocable JWT would be simpler and is the wrong
trade for data this sensitive.

No custom cryptography anywhere: `SecureRandom`, Spring Security's encoders, and a
maintained JWT library.

### 5.2 Authorization

Separate concern, enforced below the controller.

- The filter chain establishes *who* the caller is.
- Every repository query used by a request is scoped by `user_id` in the SQL
  itself - for example `... FROM usage_days d JOIN devices dev ON dev.id = d.device_id
  WHERE dev.user_id = :userId`.
- No endpoint loads an entity by id and then checks ownership afterwards. Ownership
  is a predicate in the query, so "forgot the check" cannot return another user's
  row; it returns nothing.
- Writing to a `deviceId` the caller does not own returns `404`, not `403`, so the
  API does not confirm that someone else's device id exists.

---

## 6. PostgreSQL schema

Flyway owns the schema. `spring.jpa.hibernate.ddl-auto=validate` in every profile
including tests, so a drifted entity fails the build rather than silently mutating
production.

`V1__baseline.sql`:

```sql
CREATE TABLE users (
    id            UUID PRIMARY KEY,
    email         TEXT        NOT NULL,
    password_hash TEXT        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_email_key UNIQUE (email)
);
-- email is stored already lower-cased and trimmed by the service layer.

CREATE TABLE devices (
    id            UUID PRIMARY KEY,               -- client installation UUID
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name  TEXT        NOT NULL,
    platform      TEXT        NOT NULL CHECK (platform IN ('android', 'windows')),
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at  TIMESTAMPTZ
);
CREATE INDEX devices_user_id_idx ON devices (user_id);

CREATE TABLE usage_days (
    device_id        UUID        NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    local_date       DATE        NOT NULL,
    snapshot_version BIGINT      NOT NULL CHECK (snapshot_version > 0),
    timezone_id      TEXT        NOT NULL,
    source_status    TEXT        NOT NULL CHECK (source_status IN ('partial', 'reconciled', 'imported')),
    received_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (device_id, local_date)
);
CREATE INDEX usage_days_device_date_idx ON usage_days (device_id, local_date DESC);

CREATE TABLE usage_day_apps (
    device_id        UUID   NOT NULL,
    local_date       DATE   NOT NULL,
    app_key          TEXT   NOT NULL,
    app_name         TEXT   NOT NULL,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0 AND duration_seconds <= 86400),
    launch_count     INTEGER NOT NULL CHECK (launch_count >= 0),
    PRIMARY KEY (device_id, local_date, app_key),
    FOREIGN KEY (device_id, local_date)
        REFERENCES usage_days (device_id, local_date) ON DELETE CASCADE
);

CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY,
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash BYTEA       NOT NULL,
    issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT refresh_tokens_hash_key UNIQUE (token_hash)
);
CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);
```

Notes on the constraints that are doing real work:

- `usage_days` PK `(device_id, local_date)` is what makes a repeated upload
  impossible to duplicate. It is not an application-level check.
- `usage_day_apps` PK `(device_id, local_date, app_key)` is what makes a repeated
  app row impossible to duplicate.
- The composite FK from `usage_day_apps` to `usage_days` plus `ON DELETE CASCADE`
  means a day can never hold orphan app rows.
- `duration_seconds <= 86400` is a cheap sanity bound; a day cannot contain more
  than a day of usage per app. It has caught this class of bug before.
- `source_status` gains `imported` beyond the local vocabulary - see 7.2.
  `unavailable` days are never uploaded, so the server does not model them.

---

## 7. Idempotency and versioning

### 7.1 Identity

A snapshot's identity is:

```text
device_id + local_date
```

and its ordering is `snapshot_version`. The user is not part of the key because a
device belongs to exactly one user; user scoping is an authorization predicate, not
an identity component.

`snapshot_version` = `usage_snapshot_days.queried_at_ms` for the day. It advances
only when the OS is re-queried, so re-uploading an unchanged day carries an
unchanged version, which the server recognises as a duplicate.

### 7.2 Days without a snapshot row

Windows days, legacy pre-v5 days, and days restored from a portable backup have no
`usage_snapshot_days` row. They upload with `snapshot_version = 1` and
`source_status = 'imported'`. Since any real `queried_at_ms` is an epoch
millisecond value, a genuine later snapshot always supersedes an imported one.

### 7.3 Write path

Per day, inside one transaction:

```sql
INSERT INTO usage_days (device_id, local_date, snapshot_version, timezone_id, source_status)
VALUES (:deviceId, :localDate, :version, :tz, :status)
ON CONFLICT (device_id, local_date) DO UPDATE
    SET snapshot_version = EXCLUDED.snapshot_version,
        timezone_id      = EXCLUDED.timezone_id,
        source_status    = EXCLUDED.source_status,
        received_at      = now()
WHERE usage_days.snapshot_version < EXCLUDED.snapshot_version;
```

- 1 row affected -> the day is new or superseded. Delete its `usage_day_apps` and
  insert the new set. Result `APPLIED`.
- 0 rows affected -> `snapshot_version` is equal or lower. Touch nothing. Result
  `DUPLICATE` (equal) or `STALE` (lower).

Whole-day replace, never accumulate. `duration_seconds` is a total, not a delta, so
adding would inflate usage on every retry - the exact failure this design must not
have.

The whole request is one `@Transactional` unit. A validation or constraint failure
on day 7 of 30 rolls back days 1-6 as well; the client retries the whole batch,
which is safe by construction.

No `Idempotency-Key` header is needed. The natural key plus the version guard makes
`PUT /sync/usage-days` idempotent by definition, which is why it is a `PUT`.

---

## 8. Conflict and multi-device policy

### 8.1 Conflict

**Within one device/day:** the higher `snapshot_version` wins, wholesale. A later
snapshot of a day is a better measurement of that day, not additional usage.

**Across devices:** never merged.

```text
User
├── Device A  2026-09-17  com.example.app  2840s
└── Device B  2026-09-17  com.example.app   410s
```

These stay two independent rows. The server does not compute, store, or return a
combined "true attention time" - a phone and a laptop can be used simultaneously,
so summing them is not a measurement of anything. The API returns per-device data
and any aggregation is a labelled, explicit client-side choice.

### 8.2 What the client uploads, and when

There is no `synced` column locally and this design does not add one in Phase 1.

The client keeps a watermark in `settings` under `sync_usage_watermark_ms`. A sync
run uploads every day whose `queried_at_ms` exceeds the watermark (plus every day
lacking a snapshot row that has not been uploaded before), then advances the
watermark on success. Because the server side is idempotent, an over-broad or
repeated upload is harmless; the watermark is an optimisation, not a correctness
mechanism.

### 8.3 Offline and retry behaviour

1. Usage is recorded locally by the existing pipeline. Nothing changes.
2. The local database stays authoritative for every user-visible feature.
3. Sync runs asynchronously, off the UI path, best-effort.
4. Any failure - network, 5xx, auth, storage - leaves local state untouched. Sync
   failures are swallowed the same way `recoverUsageHistory` swallows its own.
5. Failed work stays retryable because nothing is marked consumed until the server
   acknowledges it.
6. Success advances the watermark only.
7. Repeating any request is safe (section 7).
8. **Local history is never deleted after upload.** The server is a copy, not a
   destination.

---

## 9. REST API contract

All endpoints under `/api/v1`. JSON in, JSON out. Errors use RFC 9457
`application/problem+json` via Spring's `ProblemDetail`.

```text
POST /api/v1/auth/register        {email, password}                -> 201 {userId}
POST /api/v1/auth/login           {email, password}                -> 200 {accessToken, expiresIn, refreshToken}
POST /api/v1/auth/refresh         {refreshToken}                   -> 200 {accessToken, expiresIn, refreshToken}

POST /api/v1/devices              {deviceId, displayName, platform} -> 200/201 {device}
GET  /api/v1/devices                                                -> 200 [{device}]

PUT  /api/v1/sync/usage-days      {deviceId, days:[...]}            -> 200 {results:[...]}

GET  /api/v1/usage?from=&to=[&deviceId=]                            -> 200 {days:[...]}
```

`POST /devices` is idempotent on `deviceId`: re-registering an installation the
caller already owns updates `display_name` / `last_seen_at` and returns 200.
Registering a `deviceId` owned by someone else returns 409 without disclosing the
owner.

### 9.1 Upload request

```json
{
  "deviceId": "550e8400-e29b-41d4-a716-446655440000",
  "days": [
    {
      "localDate": "2026-09-17",
      "timezoneId": "Europe/London",
      "snapshotVersion": 1758124800123,
      "sourceStatus": "reconciled",
      "apps": [
        { "appKey": "com.example.app", "appName": "Example", "durationSeconds": 2840, "launchCount": 12 }
      ]
    }
  ]
}
```

Bean Validation on the DTOs: `deviceId` a UUID; `days` non-empty, at most 400
entries; `localDate` a valid ISO date not in the future relative to the server's
day plus one (a device can legitimately be a day ahead); `timezoneId` resolvable by
`ZoneId.of`; `snapshotVersion` positive; `apps` at most 2000 entries per day with
unique `appKey`; `appKey` and `appName` non-blank, length-bounded;
`durationSeconds` in `[0, 86400]`; `launchCount` non-negative. Request body size
capped server-side.

### 9.2 Upload response

```json
{
  "results": [
    { "localDate": "2026-09-17", "outcome": "APPLIED",   "storedVersion": 1758124800123 },
    { "localDate": "2026-09-16", "outcome": "DUPLICATE", "storedVersion": 1758038400000 },
    { "localDate": "2026-09-15", "outcome": "STALE",     "storedVersion": 1758000000000 }
  ]
}
```

Per-day outcomes rather than a single status: the client learns exactly what
happened without a follow-up read, and the integration tests assert on this
directly.

### 9.3 History read

`GET /api/v1/usage?from=2026-09-01&to=2026-09-18` returns the caller's days across
all their devices; `deviceId` narrows it. `from` inclusive, `to` exclusive, mirroring
`getUsageHistory` locally. Range capped at 400 days.

```json
{
  "days": [
    {
      "deviceId": "550e8400-...",
      "deviceName": "Galaxy A36",
      "localDate": "2026-09-17",
      "timezoneId": "Europe/London",
      "snapshotVersion": 1758124800123,
      "apps": [
        { "appKey": "com.example.app", "appName": "Example", "durationSeconds": 2840, "launchCount": 12 }
      ]
    }
  ]
}
```

Source device identity is always present, which is what makes the Phase 2 proof
observable.

### 9.4 Future incremental sync

The shape `GET /api/v1/sync/changes?since=<cursor>` is left room for by
`usage_days.received_at`: a server-side monotonic timestamp is a sufficient cursor
when it is needed. **Not implemented in v1.** No change feed, no cursor table, no
tombstones until the vertical slice works end to end.

---

## 10. Backend project layout

```text
server/
├── build.gradle.kts
├── settings.gradle.kts
└── src/
    ├── main/
    │   ├── java/com/stepandemianenko/focustrace/sync/
    │   │   ├── auth/       AuthController, AuthService, JwtService, SecurityConfig, User, RefreshToken
    │   │   ├── device/     DeviceController, DeviceService, Device
    │   │   ├── usage/      UsageController, UsageQueryService, UsageDay, UsageDayApp
    │   │   ├── sync/       SyncController, UsageSyncService, DTOs
    │   │   └── common/     ProblemDetail handlers, CurrentUser resolver
    │   └── resources/
    │       ├── application.yml
    │       └── db/migration/V1__baseline.sql
    └── test/
```

Controllers -> services -> repositories -> entities. DTOs are records in the
package that owns the endpoint. **JPA entities are never returned from a
controller.** No interface with a single implementation, no service that only
forwards to a repository.

`server/` is a standalone Gradle build, not part of the Android `settings.gradle.kts`.
It must be possible to build the app without a JDK-for-server toolchain and vice
versa.

**Gradle over Maven**, Kotlin DSL, matching `android/`. One build tool in the
repository is worth more than matching the Spring tutorial convention.

**Java 21 (LTS) + the current Spring Boot 3.5.x patch release.** Pin the exact
version from start.spring.io at bootstrap time rather than trusting a version
written into a design document.

Libraries: Spring Web, Spring Data JPA, Spring Security, Bean Validation, Flyway,
PostgreSQL driver, a maintained JWT library. Nothing else without a concrete need.

---

## 11. Privacy

Sync v1 stores, per user, exactly:

- email address and an Argon2id password hash;
- for each device: an app-generated UUID, a display name, a platform string,
  registration and last-seen timestamps;
- for each device-day: the local date, IANA zone id, snapshot version, source
  status, receipt timestamp;
- for each app in that day: an app key, a display name, total seconds, launch count.

That is the complete list. Every field is present because a cross-device history
view cannot be rendered without it - `app_name` is included specifically because
Device B may not have the app installed and cannot resolve the key to a label
itself.

Not stored: window titles, notification contents, page or document contents, raw
`UsageEvents`, icons, restriction rules, block routines, excluded-app lists,
location, contacts, messages, hardware identifiers, advertising identifiers.

Sync is opt-in. An account is required to sync; the app works fully without one.
`README.md` and `docs/privacy.html` currently state that FocusTrace never sends
data to a server. **Both must be updated before any sync code ships to users**,
alongside account deletion (`ON DELETE CASCADE` from `users` already makes the
data deletion correct).

---

## 12. Testing strategy

Integration tests run against real PostgreSQL via Testcontainers and a static
container shared across the suite (`@ServiceConnection`). H2 is not used: this
design depends on `ON CONFLICT ... WHERE`, composite foreign keys, `TIMESTAMPTZ`,
and `DATE` semantics, and H2 would test a dialect the application never runs on.

| Area | Test |
| --- | --- |
| Auth | register, login, wrong password rejected, unauthenticated request to a protected route is 401, expired access token is 401, refresh rotation, reused refresh token revokes the chain |
| Authorization | User A reading User B's usage gets an empty result; User A uploading to User B's device gets 404 |
| Device | registration succeeds; re-registering the same installation UUID updates rather than duplicates; a UUID owned by another user is 409 |
| Validation | negative duration, duration above 86400, duplicate `appKey` in a day, unknown `timezoneId`, empty `days` all rejected with 400 and no rows written |
| Idempotency | upload a snapshot twice; assert row counts and totals identical to a single upload, and the second response is `DUPLICATE` |
| Supersede | upload version 1, then version 2 with different apps; assert only version 2's rows exist, app row count matches version 2, no accumulation, outcome `APPLIED` |
| Stale | upload version 2, then version 1; assert version 2 survives and outcome is `STALE` |
| Device isolation | Devices A and B, same user, same date; assert two independent `usage_days` rows and that the history response labels each one |
| Transaction safety | a batch whose last day violates a constraint leaves zero rows from that batch |
| Flyway | context loads with `ddl-auto=validate`, proving entities match the migration |

---

## 13. Delivery order

Owned by `backend-sync-v1-plan.md` (sections 2 and 3). Not duplicated here.

The one constraint that is architectural rather than schedule: Flutter integration
starts only after the API contract is stable, layered as
`domain -> sync repository -> remote data source`. No HTTP in widgets or view
models. The SQLite layer stays authoritative.

---

## 14. Risks and assumptions

1. **Wall-clock regression breaks version ordering.** `snapshot_version` is
   `queried_at_ms`, a device wall clock. If a user moves their clock backwards, a
   genuinely newer snapshot can carry a lower version and be rejected as `STALE`.
   Consequence is a stale server-side day, never corruption, and the next real
   snapshot after the clock settles repairs it. Upgrade path if it bites: a
   per-device monotonic counter in `settings`, incremented per changed day, which
   requires local state this design deliberately avoids for now.

2. **`app_key` is not a stable cross-device identifier.** The same app can appear
   as `com.example.app` from Android and `Example.exe` from Windows. Sync v1 does
   not attempt identity resolution; devices are presented separately, so the
   mismatch is visible rather than silently wrong.

3. **The watermark can miss days.** If a day is mutated by something that does not
   advance `queried_at_ms` - a portable-data import, for example - the watermark
   will not select it. `importPortableData` already clears `usage_snapshot_days`
   and rotates `usage_recovery_generation`; the sync client should reset its
   watermark on the same signal. This must be verified during implementation.

4. **No local per-day upload state.** The watermark is a single scalar. Losing it
   causes a full re-upload, which is safe but heavy. Acceptable at this scale.

5. **An account is a new attack surface on sensitive data.** Mitigated by Argon2id,
   short access tokens, revocable rotating refresh tokens, query-level ownership
   scoping, no secret defaults, and TLS terminated in front of the service. The
   service refuses to start without a configured JWT secret.

6. **Rate limiting and email verification are absent in v1.** `POST /auth/login`
   and `/auth/register` are unauthenticated and currently unthrottled. Acceptable
   for a private deployment; **must** be addressed before any public one.

7. **Assumption: one day per device is small.** Roughly 50-200 app rows. If some
   device produces thousands, the 2000-app cap rejects it rather than degrading
   quietly.

8. **Assumption: Windows devices participate.** `platform` allows `windows`, but
   the Windows shell currently lives on the parked `feat/sync-server` branch. If
   Windows is dropped from scope, the `CHECK` constraint narrows to `android` and
   the `app_key` risk in item 2 disappears.

9. **`README.md` and `docs/privacy.html` are currently inaccurate about sync.**
   Tracked as a release blocker in section 11, not a backend task.
