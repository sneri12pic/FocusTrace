# Backend Sync v1 - Progress / Handoff

Newest entry first. Keep entries concise. This is the record another agent or
session reads to continue safely.

---

## 2026-09-17 — Phase 1 Step 1

Date: 2026-09-17
Agent: Claude Code
Goal: Plan Phase 1 Step 1 - bootstrap `server/` as a standalone Gradle Kotlin DSL
Spring Boot build with the Flyway baseline. Stop before Step 2.

Completed:
- `server/` bootstrapped as a standalone Gradle build, not wired into
  `android/settings.gradle.kts`.
- Gradle wrapper copied from `android/` and repointed to Gradle 9.5.1.
- Spring Boot application entry point and `application.yml` with `ddl-auto=validate`.
- `V1__baseline.sql` implementing architecture section 6 verbatim: `users`,
  `devices`, `usage_days`, `usage_day_apps`, `refresh_tokens`, plus their
  constraints and indexes.
- `FlywayBaselineIT` - Testcontainers PostgreSQL 16, asserts the migration applies
  and that the idempotency-carrying primary keys exist.

Files materially changed:
- `server/settings.gradle.kts`, `server/build.gradle.kts`, `server/.gitignore` (new)
- `server/gradlew`, `server/gradlew.bat`, `server/gradle/wrapper/*` (new, copied)
- `server/src/main/java/com/stepandemianenko/focustrace/sync/FocusTraceSyncApplication.java` (new)
- `server/src/main/resources/application.yml` (new)
- `server/src/main/resources/db/migration/V1__baseline.sql` (new)
- `server/src/test/java/com/stepandemianenko/focustrace/sync/FlywayBaselineIT.java` (new)
- `docs/backend/backend-sync-architecture.md` - section 10 version pin updated

Verification:
- `./gradlew build -x test` - **PASS**. Compiles, `bootJar` produced.
- `./gradlew compileTestJava` - **PASS**, zero warnings with `-Xlint:deprecation`.
- `gradlew.bat test` - **PASS** (run 2026-09-17T21:17:24Z once Docker was started).
  Evidence read back from `build/test-results/test/TEST-...FlywayBaselineIT.xml`:
  - `tests="5" skipped="0" failures="0" errors="0"`, suite time 32.9s;
  - container: `Creating container for image: postgres:16-alpine`,
    `started in PT2.7856428S`, `PostgreSQL 16.15`;
  - Flyway: `Migrating schema "public" to version "1 - baseline"` ->
    `Successfully applied 1 migration to schema "public", now at version v1
    (execution time 00:00.198s)`;
  - all five assertions passed: `baselineCreatesEveryTable`,
    `usageDayIdentityIsDeviceAndLocalDate`, `usageDayAppIdentityIncludesAppKey`,
    `appRowsCannotOutliveTheirDay`, `migrationIsRecordedAsApplied`.
- **`V1__baseline.sql` has now executed against real PostgreSQL 16.15**, and the
  Spring context started with `ddl-auto=validate`. Plan acceptance criterion 1 is
  met.

Decisions made:
- **Spring Boot 4.1.0, not 3.5.x.** The design document told this step to pin the
  actual current version at bootstrap. 4.1.0 is what the local Maven cache holds
  and is current. Architecture section 10 updated to match.
- **Gradle 9.5.1 for `server/`** while `android/` stays on 8.12. Boot 4.1.0
  refuses Gradle below 8.14. Separate builds, so no conflict.
- Boot 4 starter renames adopted: `spring-boot-starter-webmvc`,
  `spring-boot-starter-flyway`.
- Testcontainers 2.0.5 pinned via its own BOM; the Boot BOM does not manage it.
  Artifacts are `testcontainers-junit-jupiter` / `testcontainers-postgresql`, and
  `PostgreSQLContainer` now lives in `org.testcontainers.postgresql` and is
  non-generic.
- **Spring Security deferred to Step 2.** It is in the fixed stage stack but Step 1
  has no endpoints to protect; adding the starter now would only produce an
  unconfigured lockdown and a generated password on every boot. Step 2 owns auth.
- No credentials committed. `application.yml` uses `${FOCUSTRACE_DB_URL}`,
  `${FOCUSTRACE_DB_USER}`, `${FOCUSTRACE_DB_PASSWORD}` with local-only defaults and
  an empty default password.

Remaining:
- Next exact plan step: **Phase 1 Step 2** - `users` table plus registration and
  login, Argon2id hashing, JWT access token, rotating hashed refresh token,
  stateless `SecurityFilterChain`. Adds Spring Security.

Risks / unresolved questions:
1. Boot 4.1.0 is a newer major than the design assumed. Step 2 will meet further
   Boot 4 API differences, particularly in Spring Security configuration.
2. `postgres:16-alpine` in the test is not pinned to a digest, and no PostgreSQL
   version is fixed for production yet.
3. Running the suite requires a live Docker daemon. There is no fallback and
   deliberately no H2 substitute; without Docker the suite is blocked, not failing.

Relevant commit:
- The `feat(server): bootstrap Spring backend and baseline schema` commit that
  carries this entry. A commit cannot contain its own hash; `git log` on
  `server/` resolves it. Previous checkpoint: `5bc75c5`.

---

## 2026-09-17

Date: 2026-09-17
Agent: Claude Code
Goal: Inspect repository state, remove remnants of the aborted backend attempt,
design the Sync v1 architecture. Stop before Spring Boot implementation.

Completed:
- Confirmed branch `feature/backend-sync-v1`.
- Established that **no FastAPI/Python backend ever existed** in this repository.
  The aborted attempt was a Dart `shelf` server, parked on branch
  `feat/sync-server` (commit `17e7fc3`): `server/bin/server.dart`,
  `server/lib/sync_handler.dart`, `server/lib/sync_store.dart`. Nothing from it
  is tracked on this branch. The only `.py` files are in
  `.agents/skills/caveman-compress/` and are unrelated tooling.
- Inspected the local usage model: `focus_trace_local_data_source.dart` (SQLite
  schema v5) and `android/app/src/main/kotlin/.../UsageSnapshotStore.kt`.
- Designed and wrote the server domain model, PostgreSQL schema, auth model,
  idempotency and conflict semantics, and the REST contract.
- Wrote the stage plan with explicit acceptance criteria.

Files materially changed:
- `docs/backend/backend-sync-architecture.md` (new)
- `docs/backend/backend-sync-v1-plan.md` (new)
- `docs/backend/backend-sync-v1-progress.md` (new, this file)
- `.gitignore` (one line: ignore `.local/`)
- `CLAUDE.md` (new, then reduced to Claude-specific rules only)
- `AGENTS.md` (new, shared Claude/Codex working agreement)

Verification:
- None applicable. Design-only stage, no code written, no test run.

Decisions made (rationale in the architecture document):
- Sync payload is `daily_app_usage` plus three fields from
  `usage_snapshot_days` (`timezone_id`, `queried_at_ms`, `status`). Nothing else.
- `usage_sessions` is never uploaded - it holds `window_title`.
- `UsageInterval` is **not** synchronized in v1.
- Snapshot identity is `(device_id, local_date)`; ordering is `snapshot_version`
  = `usage_snapshot_days.queried_at_ms`. No new SQLite column, no schema v6.
- Idempotency is enforced by the primary key plus a guarded upsert
  (`ON CONFLICT ... DO UPDATE ... WHERE stored.snapshot_version < excluded`),
  not by an application-side existence check. Whole-day replace, never
  accumulate.
- Devices are never merged or summed; the server stores and returns per-device
  data only.
- Server column is `app_key`, not `package_name`: `AppUsageSummary.appKey`
  resolves to `packageName ?? processName ?? appName`.
- Device identity is an app-generated UUID v4 in `settings` under
  `sync_installation_id`. No hardware or advertising identifiers.
- Auth is Argon2id + 15-minute JWT access token + rotating hashed refresh token.
- Gradle Kotlin DSL, standalone build under `server/`, not part of
  `android/settings.gradle.kts`.

Remaining:
- All of Phase 1 and Phase 2. No `server/` source exists yet.
- Architecture review by the developer before implementation begins.

Risks / unresolved questions:
1. `snapshot_version` is device wall clock. A backwards clock change can make a
   newer snapshot look `STALE`. Stale server day, never corruption; self-repairs.
2. `app_key` is not stable across platforms (`com.example.app` vs `Example.exe`).
   v1 does no identity resolution.
3. The upload watermark can miss a day mutated without advancing
   `queried_at_ms` - notably `importPortableData`, which clears
   `usage_snapshot_days` and rotates `usage_recovery_generation`. The sync client
   should reset its watermark on that signal. **Verify during implementation.**
4. Whether Windows devices participate. The `platform` CHECK allows `windows`,
   but the Windows shell lives on the parked `feat/sync-server` branch. Dropping
   Windows also removes risk 2.
5. `README.md` and `docs/privacy.html` currently state that no data leaves the
   device. Release blocker, tracked in the plan.

Blocked / needs a manual command:
- `server/` still contains `.dart_tool/` build cache from the parked Dart shelf
  server (gitignored, untracked, 4 files). Deletion was refused twice by the
  Claude Code permission classifier. It must be removed before Spring Boot
  claims that path:
  ```
  rm -rf server
  ```

Working tree notes (not this session's work, left untouched):
- Eight modified `lib/l10n/generated/app_localizations*.dart` files - line-ending
  churn only (LF/CRLF), no content diff.
- Untracked `.agents/` (skill definitions), `.local/` (another agent's archived
  audits and docs), `skills-lock.json`.
- `.local/archive/` and `.local/audits/` duplicate tracked files still present in
  `docs/` (`BlockerService.md`, `PhaseA_BlockerService.md`, `audit.md`,
  `closed-test-*`). Someone appears to be mid-move. Not resolved here.

Relevant commit:
- None. Nothing committed this session.
