# Backend Sync v1 - Progress / Handoff

Newest entry first. Keep entries concise. This is the record another agent or
session reads to continue safely.

---

## 2026-09-18 — Phase 1 Step 2: authentication implemented

Date: 2026-09-18
Agent: Claude Code (lead implementation) + independent review subagent
Goal: Implement Phase 1 Step 2 per D01-D11, D14, D15, D17. No device/sync work.

Completed:
- `V2__auth_sessions.sql`: architecture 6.1 verbatim - `users_email_canonical`
  CHECK, `auth_sessions`, `refresh_tokens.session_id` with composite FK
  `(session_id, user_id)`, partial unique index (one current token per session).
- Endpoints: `POST /api/v1/auth/register` (201/400/409), `login` (200/401),
  `refresh` (200/401), `logout` (204, authenticated). Public allow-list is exactly
  register/login/refresh; everything else authenticated.
- Argon2id `m=19456,t=2,p=1`, 16/32, `{argon2}` via DelegatingPasswordEncoder; one
  NFC password path; code-point bounds 15-128 via Bean Validation; local blocklist
  (10,912 entries, provenance in file header); email-local-part check.
- D03 canonicaliser (`EmailAddresses`) shared by registration, login and lookup.
- HS256 JWT (Nimbus via Spring Security), claims exactly iss/aud/sub/iat/exp/jti,
  no `kid`, algorithm pinned, zero skew, `sub` must be an existing user.
- Refresh: 256-bit SecureRandom tokens stored as SHA-256; atomic conditional
  `UPDATE ... RETURNING` claim whose row count decides; 10 s reuse grace; replay
  outside grace revokes that session only (`token_reuse`); 30 d inactivity capped
  by 90 d absolute.
- D15 GCRA token buckets (one long per key, bounded LRU map, idle sweep), per source
  (socket peer, `forward-headers-strategy: none`) and per canonical account.
- ProblemDetail error model, request-id correlation, security event log
  (`focustrace.security`), redacted `toString` on credential-bearing records.
- D09/D14 startup checks; `application-prod.yml` with no fallbacks.

Files materially changed:
- `server/build.gradle.kts` (+ spring-boot-starter-security,
  spring-security-oauth2-resource-server, spring-security-oauth2-jose,
  bcprov-jdk18on 1.86)
- `server/src/main/resources/{application.yml, application-prod.yml,
  db/migration/V2__auth_sessions.sql, auth/common-passwords.txt}`
- `server/src/main/java/.../sync/auth/*` (11 files), `.../sync/common/*` (4 files)
- `server/src/test/java/...` (15 test files; `FlywayBaselineIT` moved onto the
  shared base and now expects V2)
- `docs/backend/backend-sync-architecture.md` (status, 5.1 implementation notes,
  6.1 heading), `backend-sync-v1-plan.md` section 5, baseline section 19 status.

Verification:
- `cd server && ./gradlew test --rerun`: 140 tests, 0 failures, 0 skipped
  (Testcontainers PostgreSQL 16, Docker 25 running).
- Race tests (RefreshTokenIT 15 rounds, StrictRotationIT 10) use two threads and
  assert the requests overlapped. Mutation check: replacing the conditional claim
  with SELECT-then-UPDATE made the race test fail (a 500 from the partial unique
  index); original restored byte-identical.
- All captured test output scanned: no JWT, Argon2 hash, Authorization header or
  generated Spring password. `CredentialLeakageIT` asserts the same per flow.
- Independent security review of the diff: 1 confirmed defect (lone UTF-16
  surrogate in a password -> 500 on register/login) fixed and regression-tested;
  1 test gap (dummy-verification call untested) closed by `LoginTimingControlTest`.

Decisions made:
- Implementation notes recorded in architecture 5.1 (blocklist source, `aud`
  string form, no `kid`, `iat` not enforced, logout authenticated, D14 mechanism,
  malformed UTF-16). No D01-D17 decision changed.

Remaining:
- Step 3 (devices), after settling D16. D13 stays open for the sync step.
- Test-only protected endpoints (`TestEndpoints`) stand in for Step 3's real ones.

Risks / unresolved questions:
1. Per-source key is the full client address; an IPv6 client with a /64 has many
   sources. Aggregate IPv6 to /64 when trusted-proxy handling lands (D15).
2. Within the 10 s grace, if an attacker rotates a stolen token first, the
   legitimate client's replay gets a 401 and nothing is revoked (D08 table,
   by design; grace 0 closes it).
3. Container-level errors (firewall rejections, direct `/error`) render Boot's
   plain JSON error body rather than problem+json; nothing internal leaks.
4. Rate-limit and session state are in-process: single instance only (D15).
5. D17 enforcement scope - **resolved 2026-09-18 by the developer**, recorded in
   architecture D17: admission control for every newly established password
   (registration; future change/reset), never at login, no retroactive effect on
   stored credentials. Implementation already conformed; no code change. Open
   obligation: the future change/reset endpoint must apply it and test it.

Pre-commit verification pass (same date), four concerns:
- Missing `iat`/`jti`: runtime-verified (Spring synthesises `iat = exp - 1 s`; missing
  `jti` rejected). D07's six claims define issued tokens; acceptance rules (D07
  verification, baseline 6) require neither. Architecture note and code comment
  corrected to give that reason. `AccessTokenIT.missingIatIsAcceptedWithSynthesisedValueWhileMissingJtiIsRejected`.
- Logout: refresh token identifies the session, bearer `sub` is the ownership
  predicate; section 9 contract and D10 note now state both explicitly. No D10
  change. `LogoutIT` (incl. `refreshTokenNotAccessTokenIdentifiesTheSession`).
- Rate-limit source key is `getRemoteAddr()` (IP only, no port):
  `RateLimitIT.freshConnectionsFromTheSameIpShareOneSourceBucket`.
- Blocklist not consulted at login; unknown-account login still does one dummy
  verification: `LoginIT.blocklistedPasswordOnUnknownAccountIsTheGeneric401`,
  `LoginTimingControlTest.blocklistedPasswordOnUnknownAccountRunsDummyVerificationNotTheBlocklist`.
- `./gradlew test --rerun`: 146 tests, 0 failures, 0 skipped.

Relevant commit:
- `ed7f182` — `feat(server): implement secure authentication and sessions`

---

## 2026-09-17 — Step 2 decision consistency pass (final before implementation)

Date: 2026-09-17
Agent: Claude Code
Goal: Four documentation-only corrections closing inconsistencies found in
review. Last planning pass; implementation is next.

Completed:
- **D03 corrected, and a false claim withdrawn.** `CHECK (email = lower(btrim(email)))`
  was described as failing closed on Java/SQL divergence. It does not: bare
  `btrim` strips `U+0020` only, so a direct insert of `E'\tuser@example.com'`
  satisfies the predicate while staying distinct under `UNIQUE (email)` - the
  exact divergence the constraint existed to prevent. Replaced with one precise
  algorithm both layers implement: strip `U+0020` only, reject anything outside
  `U+0021`-`U+007E` as invalid input, lower-case with `Locale.ROOT`. The `CHECK`
  becomes `email = lower(email) AND email ~ '^[!-~]+$'`. Over that character set
  PostgreSQL `lower()` and Java `toLowerCase(Locale.ROOT)` are provably identical,
  and "trimmed" needs no SQL equivalent because a canonical address contains no
  whitespace at all. Accepted limitation recorded: RFC 6531 internationalised
  addresses are rejected.
- **D08 grace window described accurately.** It is a reuse-detection grace, not
  retry recovery. A lost successful refresh response leaves the client without
  the successor, and a 401 on retry strands it exactly as a revocation would -
  that client re-authenticates. Recorded that true idempotent refresh would mean
  caching the response or retaining the successor's plaintext, which the security
  baseline forbids. Grace of zero is a supported configuration giving strict
  RFC 9700 rotation. The concurrency test must now also assert the within-grace
  loser does not invalidate the successor.
- **D02 now applies Unicode NFC** before hashing - normalisation only, still no
  trim, case-fold, NFKC or truncation - because Android keyboards differ on
  composition and an unnormalised decomposed password silently fails to verify.
  Registration and verification share one processing method; length is validated
  after normalisation.
- **D17 resolved**, in Step 2: a local versioned blocklist, no outbound network
  access. The previous "this needs an outbound HIBP call" framing was wrong; a
  bundled list is an equally recognised approach and a large corpus adds little
  once D15 rate-limits attempts. Provenance, licence check, size, update strategy
  and verification are recorded. API7 stays "not exposed".
- **D09 wording corrected.** Base64 validity plus 32 decoded bytes establishes
  encoding and length, not entropy - a 44-character memorable phrase in the
  base64 alphabet passes. The CSPRNG requirement stands as an operational
  requirement verified by process, and is no longer presented as something the
  startup check enforces.

Files materially changed:
- `docs/backend/backend-sync-architecture.md` (5.1 D02, D03, D08, D09, D17; 6.1)
- `docs/security/backend-security-baseline.md` (sections 5, 11, 18, 19)
- `docs/backend/backend-sync-v1-plan.md` (Step 2 note, criteria 16c-16e)

Verification:
- None applicable. Documentation only; no build or test run.

Decisions made:
- Listed above. Two overturn claims written earlier today that were not true as
  stated (D03 "fails closed", D09 base64-as-entropy-defence); one corrects a
  design description that promised recovery it did not deliver (D08 grace); one
  reverses a deferral made on a false premise (D17).

Remaining:
- D13 and D16 stay open; neither is reachable from authentication.
- Phase 1 Step 2 implementation. Nothing here is implemented.

Risks / unresolved questions:
1. Internationalised email addresses are rejected by D03. Deliberate, with the
   upgrade path recorded.
2. The blocklist source is chosen at implementation; its licence must permit
   redistribution and must be checked before the file is added to the repository.

Relevant commit:
- None. Nothing committed this session.

---

## 2026-09-17 — Step 2 security decision corrections

Date: 2026-09-17
Agent: Claude Code
Goal: Four corrections to the authentication decisions before implementation.
Documentation only. No code, no migration, no dependency.

Completed:
- **D02** minimum raised 12 -> 15 code points (max 128 unchanged), because
  FocusTrace has no second factor to absorb a weak password. Recorded that the
  password is hashed exactly as supplied - not trimmed, normalised or truncated -
  in deliberate contrast to D03's treatment of the identifier.
- **D17** added and left open: compromised-password blocklist. Held open because
  the accurate implementation adds the first outbound HTTP call in the service,
  on the registration path. No outbound password-check API introduced.
- **D03** corrected. `UNIQUE INDEX (lower(email))` enforced only the case half of
  the canonical form and ignored the trim half, so `" user@example.com "` was a
  separate identity. Replaced with `users_email_key` kept from `V1` plus
  `CHECK (email = lower(btrim(email)))`. Smaller migration, no index change,
  lookups stay `WHERE email = :canonicalEmail` against the same canonicaliser.
  Java `trim()` and `btrim()` differ on exotic input, and the divergence fails
  closed: the CHECK rejects rather than stores a second spelling.
- **D08** now defines consumption as one transaction plus a single atomic
  conditional `UPDATE ... WHERE revoked_at IS NULL AND expires_at > now()`; the
  row count is the decision. Relying on the partial unique index to throw is
  explicitly ruled out as the concurrency mechanism. Added a reuse grace window
  (policy: exists; value: configuration, default 10s) so a lost-response retry
  is not treated as theft, and a required two-thread concurrency test.
- **D09** now requires RNG-generated, base64-supplied material validated to at
  least 32 **decoded** bytes, in every profile. The earlier "shorter than 32
  bytes" wording would have accepted a 32-character passphrase.
- **D15** switched from fixed-window counters to token buckets in a bounded,
  self-expiring map, and corrected the forwarded-header position: default
  `forward-headers-strategy: none`, socket peer address as source, trusted-proxy
  handling configured in the same change that introduces a proxy.

Files materially changed:
- `docs/backend/backend-sync-architecture.md` (5.1 D02, D03, D08, D09, D15,
  new D17; 6.1 schema)
- `docs/security/backend-security-baseline.md` (sections 5, 11, 12, 18, 19, 20)
- `docs/backend/backend-sync-v1-plan.md` (Step 2 note, criteria 16c, 16d)

Verification:
- None applicable. Documentation only; no build or test run.

Decisions made:
- Listed above. Three of the four corrections overturn something written earlier
  today, each stated in place rather than quietly replaced: the `lower(email)`
  index, the `framework` forwarded-headers value, and the ambiguous 32-byte
  secret check.

Remaining:
- D13, D16 and now D17 stay open. D17 is the only one that is a residual gap in
  Step 2 rather than an unbuilt surface.
- Phase 1 Step 2 implementation. Nothing here is implemented.

Risks / unresolved questions:
1. The reuse grace window trades a 10-second replay-detection blind spot for not
   logging users out on a lost response. Revisit if the window ever needs to grow.
2. D17 remains a real weak-password exposure that D02 narrows and does not close.

Relevant commit:
- None. Nothing committed this session.

---

## 2026-09-17 — Pre-Step-2 security decisions

Date: 2026-09-17
Agent: Claude Code
Goal: Turn the Step 2 security recommendations into explicit architecture
decisions so the implementation agent does not invent security behaviour.
Documentation only. No authentication code, no migration, no dependency.

Completed:
- `backend-sync-architecture.md` section 5.1 rewritten as the authentication
  decision record: D01 Argon2id parameters, D02 password bounds, D03 account
  identity, D04 access-token TTL, D05/D06 session lifetimes, D07 JWT claims,
  D08 session and replay model, D09 signing key and rotation, D10 revocation,
  D11 enumeration behaviour, D15 rate limiting, D14 configuration fail-fast.
  Each states behaviour, rationale, consequence, verification, and whether the
  value is configuration or fixed policy.
- `backend-sync-architecture.md` new section 6.1: the `V2` schema this requires,
  designed and **not written** - `auth_sessions`, `refresh_tokens.session_id`
  with a composite FK, a partial unique index giving one live token per session,
  and the `lower(email)` unique index replacing `users_email_key`.
- Architecture section 9 gains `POST /auth/logout`; risk 6 rewritten; the auth
  row of the testing table points at the per-decision expectations.
- `backend-security-baseline.md`: section 19 is now a status register pointing at
  the architecture rather than a second copy of the decisions; section 20 marks
  C1, C2, C4, C5, C6, C7 resolved and C3 open; sections 2, 7, 12 and the control
  table corrected where they described a decision as pending; section 18 gains
  the session, logout, rate-limit and email-identity tests.
- `backend-sync-v1-plan.md`: Step 2 now names the `V2` migration, the logout
  endpoint, rate limiting and the Bouncy Castle dependency; criteria 16a-16c
  added; release blockers updated.

Files materially changed:
- `docs/backend/backend-sync-architecture.md`
- `docs/security/backend-security-baseline.md`
- `docs/backend/backend-sync-v1-plan.md`

Verification:
- None applicable. Documentation only; no build or test run. Decisions were made
  against `V1__baseline.sql`, `application.yml` and `build.gradle.kts` as they
  exist, not against the design documents alone.

Decisions made:
- Two substantive changes to previously written architecture, both stated in
  place rather than silently: the flat 60-day refresh TTL becomes a 90-day
  absolute plus 30-day inactivity session window, and rate limiting moves from
  "before a public deployment" into Step 2.
- The revocation unit is a **login session**, not the user. The old "revokes the
  whole chain" wording was unenforceable against a schema whose only grouping
  column was `user_id`, and would have logged a user out everywhere because one
  installation was replayed.
- HS256 with a single environment-supplied secret, rotated by restart. Safe
  because refresh tokens are opaque database rows that a key change does not
  invalidate, so clients repair themselves through the normal refresh flow.
- In-process bounded rate-limit counters. No Redis, no Bucket4j, no new
  dependency beyond Bouncy Castle.

Remaining:
- D13 (total app rows per upload request, with C3) and D16 (`403` versus
  non-revealing `404`) stay open. Neither is reachable from authentication.
- Phase 1 Step 2 implementation itself. Nothing in this entry is implemented.

Risks / unresolved questions:
1. `ALTER TABLE refresh_tokens ADD COLUMN session_id UUID NOT NULL` assumes the
   table is empty, which holds only while no authentication code has run.
2. PostgreSQL `lower()` and Java `toLowerCase(Locale.ROOT)` are not identical
   over all of Unicode; email validation is what keeps them in agreement.
3. Whether the `V2` work ships as `V2` or is folded into `V1` while nothing is
   deployed is the developer's call. `V2` is the documented default.

Relevant commit:
- None. Nothing committed this session.

---

## 2026-09-17 — Pre-Step-2 security baseline

Date: 2026-09-17
Agent: Claude Code
Goal: Establish the backend security baseline that Phase 1 Step 2 and later sync
work must satisfy. Documentation only. Stop before any Step 2 implementation.

Completed:
- `docs/security/backend-security-baseline.md` (new): scope and trust boundaries,
  current-state inventory, control status table, access control, authentication,
  JWT, refresh tokens, Android token assumption, API boundaries, injection,
  secrets, resource consumption, Spring configuration, persistence, logging and
  exceptional conditions, supply chain, OWASP relevance, verification, sixteen
  decisions to resolve (D01-D16), seven conflicts (C1-C7).
- `AGENTS.md`: one section requiring the baseline be read before security-sensitive
  backend work.
- `CLAUDE.md`: baseline added to the backend reading list.
- `backend-sync-v1-plan.md`: Step 2 now points at the baseline; acceptance criteria
  13 broadened to all four verbs; criteria 14-18 added for auth security tests;
  release blocker note points at decision D15.

Files materially changed:
- `docs/security/backend-security-baseline.md` (new)
- `AGENTS.md`, `CLAUDE.md`, `docs/backend/backend-sync-v1-plan.md`

Verification:
- None applicable. No code written, no build or test run. Baseline derived by
  reading `server/build.gradle.kts`, `application.yml`, `V1__baseline.sql`,
  `FocusTraceSyncApplication.java`, `FlywayBaselineIT.java` and `git ls-files server`.

Decisions made:
- None. The document records decisions as unresolved (D01-D16) with
  recommendations. Turning a recommendation into a decision belongs in
  `backend-sync-architecture.md` and is the developer's call.

Remaining:
- Resolve D01-D16 in the architecture document, then begin Phase 1 Step 2.

Risks / unresolved questions:
1. C3: 400 days x 2000 apps permits 800,000 rows in one transaction. Needs a
   total-rows cap before the sync endpoint exists.
2. C5: email uniqueness is case-sensitive in the database while normalization is
   application-side. Needs a `V2` functional unique index.
3. C4: no rate limiting anywhere, deferred by both plan and architecture with no
   gate that would stop it shipping.

Relevant commit:
- None. Nothing committed this session.

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
