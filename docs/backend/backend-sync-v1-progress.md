# Backend Sync v1 - Progress / Handoff

Newest entry first. Keep entries concise. This is the record another agent or
session reads to continue safely.

---

## 2026-09-26 — History query work bounded

Date: 2026-09-26
Agent: Claude Code
Goal: Establish with PostgreSQL evidence whether a bounded history read still
expands and sorts the account's whole history, and remove that work if a simple
change does so without touching the contract.

State before work: HEAD `b2c71de`, clean tree except the unrelated untracked
`.agents/` and `skills-lock.json` (excluded).

Fixture and method (`.local/history-bench/`, gitignored; `setup.sh`,
`fixture.sql`, `baseline.sql`, `candidate-a.sql`, `equivalence.sh`,
`extract.py`, raw `EXPLAIN (ANALYZE, BUFFERS)` output): `postgres:16-alpine`
(PostgreSQL 16.15, the Testcontainers image, defaults: `work_mem` 4 MB,
`shared_buffers` 128 MB), V1-V4 applied. A D18-consistent maximum account of 14
devices x 260 days (2026-01-01..2026-09-17, 3,640 stored days, budget 3,650) x
500 apps = 1,820,000 app rows, a small account (30 days x 60 apps + 2 app-less
days), and 2,000 background accounts; 3,021,800 app rows in total; `VACUUM
ANALYZE`. The production SQL as a prepared statement, range 2026-01-01..2026-09-28,
`LIMIT 20001`, 2-4 runs per case (first run reported separately), custom and
forced-generic plans.

Cause (original plan, all devices): owner filtering ran first and was cheap (14
devices, 3,640 candidate days in about 2 ms). A nested loop then probed
`usage_day_apps_pkey` 3,640 times and produced all 1,820,000 joined rows (about
1.86 M shared buffers), which a single `Sort` ordered by date, device and app -
external merge, sort node `Disk: 231560kB`, statement temp 58,016 blocks written
and 29,431 read - before `LIMIT` took 20,001. The days came device by device, so
no presorted prefix existed; the planner estimated 442 days and 20,954 rows. With
one device the days arrive in date order and an incremental sort already stopped
early - except under a generic plan, which sorted all 130,000 rows on disk.

Alternatives evaluated:
- Ordered candidate days in a subquery, apps via `LEFT JOIN LATERAL` (chosen):
  no index, no planner settings, same result and order.
- An index: rejected - owner filtering and the per-day app lookup already use
  indexes; the missing piece was row order, and ordering needs `user_id` on
  `usage_days` (denormalisation), which is out of scope.
- A `MATERIALIZED` CTE: not adopted - PostgreSQL 16 does not carry a CTE's sort
  order to the outer query, so the outer `ORDER BY` would sort everything again.
- `work_mem` or planner settings: excluded by scope.

Completed:
- `UsageDays.history` now orders the caller's candidate days first and fetches
  each day's apps with `LEFT JOIN LATERAL`; outer `ORDER BY` and `LIMIT max + 1`
  unchanged, one statement.
- Proven identical: hashes of the complete ordered output of old and new SQL
  matched for 7 parameter sets (217,000 untruncated rows; the production 20,001
  shape with and without `deviceId`; a device slice; the small account with its
  app-less days; foreign and unknown `deviceId`).

Before/after (SQL extracted from the Java source at `b2c71de` and in the working
tree, same fixture, warm):

| Case | Before | After |
| --- | --- | --- |
| all devices, custom | 1.71-1.87 s (2.39 s first); 1,820,000 joined rows; merge 231,560 kB; temp w 58,016 / r 29,431 | 19-20 ms (42 ms first); 20,501 rows, 42 days; no temp |
| all devices, generic | 3.21-3.35 s; same spill | 19-23 ms; no temp |
| one device, custom | 25 ms; incremental sort | 14-20 ms |
| one device, generic | 192-208 ms; 130,000 rows; merge 16,600 kB; temp w 2,084 / r 709 | 14 ms; no temp |
| small account | 1.1 ms (1,802 rows) | 1.0 ms |

`LIMIT` now stops the expensive work: the app fetch runs only for the days that
produce the first 20,001 rows. What remains per read is selecting and sorting the
candidate days (at most 3,650 rows, in memory).

Files materially changed: `server/.../usage/UsageDays.java` (history SQL and
Javadoc); `server/.../usage/UsageHistoryIT.java` (new test: the production default
is 20,000, exactly 20,000 rows return whole, row 20,001 is the 400);
architecture 9.3, security baseline section 9, plan section 5, this entry.

Verification (PostgreSQL 16 via Testcontainers, all with `--rerun`):
- `UsageHistoryIT` 17/17, `HistoryBoundIT` 8/8, `FlywayBaselineIT` 7/7,
  `PerUserRateLimitIT` 6/6: PASS.
- `./gradlew test --rerun`: PASS, 26 suites, 273 tests, 0 failures, 0 errors,
  0 skipped. `./gradlew clean build`: PASS, same 273. `git diff --check`: clean.
- Mutation (measured): `b2c71de`'s SQL run again on the same fixture restored the
  full expansion and spill (old-again row above). No production file was
  mutated; the working-tree `UsageDays.java` matches the recorded candidate hash
  (`802892a6...c7287`).

Decisions made: history query shape in architecture 9.3 (benchmark figures are
observations, not guarantees).

Remaining production blockers, in order: installation-ID backup fix; privacy,
README and Play copy plus the web account-deletion page; the staging deployment
(proxy, TLS, private port, backups, log persistence) and the physical-device pass;
session/token row cleanup before a wide rollout.

Risks / unresolved questions:
- The plan relies on the planner choosing the nested loop with incremental sort.
  It did so under custom and generic plans despite underestimating rows per day
  by about 80x; a more accurate estimate only makes the early stop cheaper
  relative to a full sort. Not guarded by a plan-shape test (by design).
- Measured on one synthetic distribution and container defaults, not on
  production hardware or data.

Relevant commit: uncommitted.

---

## 2026-09-26 — History response bound and refresh-session index

Date: 2026-09-26
Agent: Claude Code
Goal: Bound the worst-case `GET /api/v1/usage` response and index
`refresh_tokens(session_id)`.

State before work: HEAD `3c1501a`, clean tree except the unrelated untracked
`.agents/` and `skills-lock.json` (excluded). Code matched the documents: the read
is one owner-scoped `LEFT JOIN` bounded only by the 400-day range; the only
session index is V2's partial unique one.

Confirmed problems:
- One read of an account at its D18 budget (10 devices x 365 days x 500 apps)
  returned 1,825,000 rows, fully materialised in the JVM and serialised: a single
  account could exhaust the one instance's heap. No production screen reads
  history.
- The D08 replay check (`n.session_id = ... AND n.revoked_at > ...`) cannot use the
  partial index and scanned `refresh_tokens` (15-134 ms at 600,000 rows).

Completed:
- Architecture 9.3 size rule: at most `focustrace.sync.max-history-rows` = 20,000
  result rows (one per app of a returned day, one per app-less day). Enforced in
  the same query with `LIMIT max + 1`; the extractor rejects on the extra row with
  `400` on field `to` ("request a shorter range or a single device"). Never
  truncated, no count query, no pagination. Ordering, range rules, device filter
  and D16 behaviour unchanged.
- `V4__refresh_tokens_session_index.sql`: `CREATE INDEX
  refresh_tokens_session_id_idx ON refresh_tokens (session_id)`. Measured on
  600,000 tokens: parallel seq scan (15 ms warm) -> bitmap index scan (0.065 ms).

Files materially changed:
- `server/.../usage/UsageDays.java`, `common/SyncLimits.java`,
  `application.yml`, new `db/migration/V4__refresh_tokens_session_index.sql`.
- Tests: new `usage/HistoryBoundIT.java` (8 tests, bound set to 10);
  `FlywayBaselineIT.java` (migration list now 1-4, which V4 requires; index
  definition test).
- Docs: architecture 6.3 and 9.3, security baseline (sync limits, section 9
  statement, API4 row), plan section 5, this entry.

Verification (PostgreSQL 16 via Testcontainers):
- `UsageHistoryIT` 16/16, `HistoryBoundIT` 8/8, `FlywayBaselineIT` 7/7,
  `--tests '*Auth*'` 4 suites / 18 tests: PASS.
- `./gradlew test --rerun`: PASS, 26 suites, 272 tests, 0 failures, 0 errors,
  0 skipped. `./gradlew clean build`: PASS, same 272.
- Mutation: removed the `LIMIT` and the extractor check. The 5 over-bound tests
  failed (200 instead of 400); the at-bound, empty and range tests stayed green.
  Restored byte-identically (SHA-256 `184a7489...c69603`).
- A first version returned `null` from the extractor for "too large", which
  `JdbcClient` rejects ("No result from ResultSetExtractor") as a 500 - caught by
  the tests; the extractor now throws the 400 itself.

Decisions made: history size rule in architecture 9.3; V4 in 6.3.

Remaining production blockers, in order: installation-ID backup fix; privacy,
README and Play copy plus the web account-deletion page; the staging deployment
(proxy, TLS, private port, backups, log persistence) and the physical-device pass;
session/token row cleanup before a wide rollout.

Risks / unresolved questions:
- Measured residual: for an account at its full budget PostgreSQL still sorts the
  whole range (about 2.4 s and a 218 MB temporary spill) before `LIMIT` applies;
  it does not use a bounded top-N sort at this width. Bounded by the stored-day
  budget and 60 reads per hour per account, not by the response bound.
- 20,000 rows rejects some legitimate full-range reads (one device beyond about 50
  apps a day for 400 days). No client calls history today; a future caller must
  narrow the range or read per device.

Relevant commit: this entry's commit (`fix(server): bound history responses and index refresh sessions`).

---

## 2026-09-26 — Network edge: trusted-proxy client address (D20)

Date: 2026-09-24 (started) - 2026-09-26
Agent: Claude Code
Goal: Record the v1 production topology and make the D15 source limits key on the
real client behind one TLS-terminating reverse proxy, without trusting headers
from anyone else.

State before work: HEAD `4ec67d4`, clean tree except the unrelated untracked
`.agents/` and `skills-lock.json` (excluded).

Problem (from the code): `server.forward-headers-strategy: none` and
`AuthController` keys the register/login/refresh source buckets on
`getRemoteAddr()`. Behind a proxy every request has the proxy's address, so each
source limit becomes one limit for all users (registration 5/h, login 10/15 min,
refresh 60/h service-wide) and one client can lock out every login. No security
event logged a source address.

Completed (architecture 5.1, D20):
- Topology recorded: HTTPS to one reverse proxy (TLS terminates there), private
  HTTP to one Spring instance, one PostgreSQL; the Spring port must be reachable
  only from the proxy.
- `focustrace.network.mode`: `direct` (socket peer, headers ignored; default
  outside `prod`) or `trusted-proxy` with `focustrace.network.trusted-proxies`
  (exact IP literals). `prod` requires `FOCUSTRACE_NETWORK_MODE`; proxy mode
  requires `FOCUSTRACE_TRUSTED_PROXIES`.
- Tomcat's `RemoteIpValve`, added only in proxy mode, with the validated
  literals as a quoted exact-match regex. Verified in Tomcat 11.0.22 bytecode:
  without `/` the value is a regex (raw `10.0.0.5` would also match `10.0.0.15`),
  and CIDR matching calls `InetAddress.getByName` (DNS for names). Boot's
  forwarded-header support must stay `none` (its default trusts private ranges).
- One hop: rightmost `X-Forwarded-For` entry that is not a listed proxy is the
  client; prepended entries ignored; `Forwarded`/`X-Real-IP` never read.
- `getRemoteAddr()` stays the one resolved address. `event=rate_limited` now logs
  `source=` for the three per-source buckets only. Budgets unchanged.

Files materially changed:
- New `server/.../common/ClientAddressConfiguration.java`;
  `common/ProductionConfiguration.java` (required mode),
  `auth/AuthRateLimiter.java` (source in the event), `auth/AuthController.java`
  (comment), `application.yml`, `application-prod.yml`.
- Tests: new `auth/TrustedProxyIT.java`, `auth/UntrustedPeerIT.java`;
  `StartupConfigurationTest.java` (new required variable; D20 cases; command-line
  arguments for the two overrides, since builder properties are defaults that
  `application.yml` overrides).
- Docs: architecture (D20; D15 note corrected - appending or overwriting both
  work with the valve), security baseline (section 12, verification, decision
  table), plan section 5, this entry.

Verification (Docker Desktop, PostgreSQL 16 via Testcontainers):
- `./gradlew test --tests '*RateLimit*'`: PASS, 3 suites, 14 tests.
- `./gradlew test --tests '*Auth*'`: PASS, 4 suites, 18 tests.
- `TrustedProxyIT` 7/7, `UntrustedPeerIT` 1/1, `StartupConfigurationTest` 27/27.
- `./gradlew test --rerun`: PASS, 25 suites, 263 tests, 0 failures, 0 errors,
  0 skipped. `./gradlew clean build`: PASS, same 263.
- Mutations (restored byte-identically, SHA-256 `16f48a27...a45928`):
  1. Valve trusting any peer (`.*`): `UntrustedPeerIT` failed - the spoofing
     client got [401, 401, 401] instead of being limited.
  2. No valve: all 7 `TrustedProxyIT` tests failed - forwarded clients collapsed
     into the proxy's one bucket.

Decisions made: D20.

Remaining: the deployment itself (proxy product, host, certificates, private
application port, proxy volumetric limits, PostgreSQL backups and retention, log
persistence); the rest of the release sequence (history row cap and
`refresh_tokens(session_id)` index, installation-ID backup fix, privacy/Play
copy and web deletion page, physical-device pass, session cleanup).

Risks / unresolved questions:
- A listed proxy that omits `X-Forwarded-For` puts all its traffic in one
  bucket; the proxy configuration must be checked in staging.
- The trusted address must be the one Spring sees (e.g. IPv4 vs IPv4-mapped
  IPv6 on dual-stack sockets); confirm from the security log in staging.
- Rate-limit events now contain client IP addresses: log retention must be
  covered by the privacy policy.

Relevant commit: this entry's commit (`fix(server): trust client IP only through configured proxy`).

---

## 2026-09-24 — Account deletion (D19)

Date: 2026-09-24
Agent: Claude Code
Goal: User-initiated deletion of the FocusTrace cloud account and all server data,
keeping local usage history, without racing sync or session changes.

State before work: HEAD `e9b96f6`, clean tree except the unrelated untracked
`.agents/` and `skills-lock.json` (excluded).

Findings (from the code):
- Every account-owned table cascades from `users` (V1/V2); no other table exists.
  One `DELETE FROM users` removes the whole graph.
- The JWT converter already rejects a `sub` that is not an existing account, so an
  access token issued before deletion dies with it. No deny-list needed.
- Two real lock cycles against a deletion: an upload held device/day rows before
  locking the account row, and a refresh held its token row before its successor's
  foreign-key check took the account row. Both were reproduced as PostgreSQL
  `deadlock detected`.
- The client's `_authorized` refreshes and replays on any `401`, so a wrong
  password must not be `401`.
- Logout already keeps the watermark (same-account re-login); deletion must not.

Completed (architecture 5.1, D19):
- `POST /api/v1/account/delete {password}` -> `204`; wrong password `403`;
  malformed `400`; unauthenticated `401`; per-user limit 5 / 15 min. Owner is the
  token's `sub`; the body cannot name one. Password verified with the existing
  `PasswordProcessor.matches` before any lock; DTO redacts it.
- Lock order: the account row first, for every account-graph writer. Upload,
  login session start, refresh rotation and logout now take `users` `KEY SHARE`
  first; registration already took `NO KEY UPDATE` first; deletion's `DELETE`
  takes `FOR UPDATE`.
- Client: `SyncRepository.deleteAccount` runs entirely inside the shared
  `SyncExecutionGate`. It cancels scheduling, resets the watermark before the
  request, clears the session only on `204`, then sets `sync_enabled=false` and
  clears email and last-success. On a certain refusal (400/403/429) it restores
  the watermark and scheduling. The installation id, imported version, local
  usage and non-sync settings are kept. The sync card has "Delete account" with a
  password-gated confirmation dialog, in 7 locales.

Files materially changed:
- Server: new `auth/AccountController.java`; `auth/AuthService.java`,
  `AuthSessions.java`, `AuthRateLimiter.java`, `AuthProperties.java`;
  `usage/UsageDays.java`; `application.yml`. No migration, no dependency.
- Server tests: new `usage/AccountDeletionIT.java`; `IntegrationTest.java`
  (lock-mode helpers), `usage/StorageBudgetIT.java` (its race now holds
  `NO KEY UPDATE`, so uploads still queue at the budget check rather than at their
  new first lock), `auth/TokenBucketTest.java`.
- Flutter: `focus_trace_sync_api.dart`, `sync_repository.dart`,
  `sync_repository_impl.dart`, `sync_usage.dart`, `sync_view_model.dart`,
  `sync_account_card.dart`, `lib/l10n/app_*.arb` and generated localizations.
- Flutter tests: `sync_repository_test.dart`, `sync_view_model_test.dart`,
  `sync_account_card_test.dart`, `sync_end_to_end_test.dart`.
- Docs: architecture (D19, D16/D18 cross-references, API list, privacy note),
  security baseline, plan section 6, this entry.

Verification:
- `./gradlew test --tests '*Account*'`: PASS (12 suites, 32 tests matched by name;
  `AccountDeletionIT` 11/11).
- `./gradlew test --rerun`: PASS, 23 suites, 241 tests, 0 failures, 0 errors,
  0 skipped. `./gradlew clean build`: PASS, same 241.
- `flutter analyze`: no issues. `flutter test`: PASS, 230 passed, 0 failed,
  1 skipped (the real-backend suite without a URL). `flutter build apk --debug`:
  PASS. `android ./gradlew :app:testDebugUnitTest`: PASS, 10 suites, 114 tests,
  0 failures/errors, 1 skipped benchmark.
- Real E2E: backend `bootRun` against PostgreSQL 16 in Docker,
  `flutter test test/sync_end_to_end_test.dart --dart-define=...`: 3/3 PASS,
  including account A upload -> wrong-password refusal -> deletion -> old refresh
  401 and login 401 -> account B on the same installation re-uploads both days.
  A direct database check found 0 rows left for account A.
- `connectedDebugAndroidTest`: not run, no device attached.
- Mutations (each restored byte-identically, SHA-256 checked):
  1. Upload without the account-first lock: the upload-vs-deletion race failed
     with PostgreSQL `deadlock detected` (500).
  2. Refresh rotation without it: the refresh-vs-deletion race failed with
     `deadlock detected`. The first version of that test blocked the refresh on
     its session row, where the successor's user FK check had already taken the
     account row, so the mutation passed. The test now blocks on the token row
     before the claim, which is the actual exposure.
  3. Client without the pre-request watermark reset: account B after deleting A
     uploaded 0 of 2 days; the success and offline tests also failed.

Decisions made: D19.

Remaining (release, unchanged unless noted): privacy copy (`README.md`,
`docs/privacy.html`); a Google Play web account-deletion path for users without
the app; device retirement/deletion; session/token row retention; history page
bound; proxy volumetric limits and trusted-proxy handling; single-instance limiter.

Risks / unresolved questions:
- Lost response: after a committed deletion the retry is `401` and the client
  shows "session ended". Signing in then fails and the user may re-register; the
  watermark was reset before the request, so no upload progress leaks.
- A login whose password check passes just as the account is deleted gets `401`
  (session start re-checks under the account lock).
- The deletion notice is in-memory UI state; it is not shown again after restart.

Relevant commit: this entry's commit (`feat(account): add secure account deletion`).

---

## 2026-09-24 — D18 fix: device reactivation obeys the active-device quota

Date: 2026-09-24
Agent: Claude Code
Goal: Close the reactivation hole in `7d0dad6`'s active-device quota.

Bug (confirmed in code): `Devices.register` quota-checked only UUIDs that did not
exist (`!exists`). An inactive device of the caller re-registering at quota was
exempt and had `last_seen_at` refreshed, so an account at 10 active devices could
reach 11 (and more, one dormant device at a time).

Completed:
- Invariant: at most `max-active-devices` (10) of an account's devices are active
  (`COALESCE(last_seen_at, registered_at)` within 90 days). New UUID or reactivation
  of the caller's inactive device takes a slot; at quota it is the same `403` as
  before and the row is untouched. Re-registering an active device takes no slot.
  Foreign UUID: unchanged `409`, same precedence.
- Under the existing account-row lock, one query classifies the UUID (owner,
  active) using the same `ACTIVE` predicate as the count. Both use PostgreSQL
  `now()` (transaction start), so they share one cutoff. No schema change.
- `DeviceQuotaIT`: the previous test asserting reactivation at quota succeeds
  encoded the bug and was replaced. New: active re-registration at full quota
  (200, `last_seen_at` advances), reactivation below quota (200, same row/owner,
  active = quota), reactivation at quota (403, body identical to new-device 403,
  row identical), foreign inactive UUID at quota (409, row unchanged), two
  reactivations racing for the last slot, reactivation vs new device racing for
  the last slot (both under the test-held account lock, 3 rounds each).

Files materially changed: `server/.../device/Devices.java`,
`server/.../device/DeviceQuotaIT.java`; architecture 5.1 D18, security baseline
sections 9 and 18, plan section 5, this entry.

Verification (PostgreSQL 16 via Testcontainers):
- `DeviceQuotaIT` 12/12, `DeviceIT` 14/14: PASS.
- `./gradlew test --rerun`: PASS, 22 suites, 230 tests, 0 failures, 0 errors,
  0 skipped. `./gradlew clean build`: PASS, same 230.
- Mutation: restored the old `!exists` exemption. Exactly the three reactivation
  tests failed (at-quota reactivation 200 instead of 403; racing reactivations
  [200, 200]; reactivation vs new [200, 201]). Restored; SHA-256 identical
  (`5a8f51af...c18386`).

Decisions made: D18 wording corrected to the explicit active-device invariant.

Remaining: unchanged from the entry below; the D18 resource-control slice is
closed for its stated scope.

Risks / unresolved questions: none new. Lock order is unchanged (account row
first, then device rows), and only registration writes `last_seen_at`.

Relevant commit: this entry's commit (`fix(server): enforce quota on device reactivation`).

---

## 2026-09-24 — Release hardening: bounded sync resource consumption (D18)

Date: 2026-09-24
Agent: Claude Code
Goal: Close the documented backend API4 release blockers (device growth,
per-account storage growth, authenticated request rates) without changing the
API design, authentication or upload contract.

State before work: `feature/backend-sync-v1` at `0555e10`, clean tree except the
unrelated untracked `.agents/` and `skills-lock.json` (excluded). Baseline
`./gradlew test --rerun` on HEAD: 19 suites, 205 tests, 0 failures/errors/skips.

Confirmed risks (from the code, not the docs):
- `Devices.register` was `INSERT ... ON CONFLICT (id) DO NOTHING` with no count:
  unlimited device UUIDs per account. Idempotent re-registration; no inactive
  concept beyond `last_seen_at`; no deletion anywhere.
- Per device: one day per date from `2026-01-01` to UTC today + 1, up to 500 app
  rows each, whole-day replacement, retained forever. Account storage was
  therefore proportional to the number of UUIDs the caller minted.
- `POST/GET /devices`, `PUT /sync/usage-days` and `GET /usage` had no per-user
  throttling; D15 covers only register/login/refresh.

Completed (architecture 5.1, D18):
- Active-device quota: a new UUID is admitted only while the account has fewer
  than 10 devices seen within 90 days, else `403`, nothing written. Own
  re-registration is never quota-checked (`200` at quota); a foreign UUID stays
  `409`. A hard total cap was rejected because the installation UUID changes on
  reinstall/data clear/new phone and no deletion exists, which would strand
  ordinary users; the inactivity window needs no new endpoint and deletes nothing.
- Concurrency: every registration first locks the caller's `users` row
  `FOR NO KEY UPDATE`, then checks existence, counts and inserts.
- Stored-day budget: at most 3,650 `usage_days` per account across devices. Only a
  request that creates a day (`RETURNING xmax = 0`) is checked; it then locks the
  account row and counts, after the writes. Over budget -> `403`, whole request
  rolled back. Replace/duplicate/stale/conflict never trip it. Rejection chosen
  over retention: no data is ever deleted to make room.
- Per-user rate limits, same D15 GCRA buckets, keyed by the verified `sub`:
  device registration 30/h, upload 300/6 h, history 60/h. Charged by a
  `HandlerInterceptor` on `@AuthRateLimiter.PerUser` handlers: after
  authentication, before body parsing, outside the transaction. `GET /devices`
  deliberately unthrottled. Generic `429` + `Retry-After`.

Files materially changed:
- `server/src/main/java/.../auth/AuthRateLimiter.java`, `AuthProperties.java`,
  new `PerUserRateLimitInterceptor.java`; new `common/SyncLimits.java`;
  `common/ApiException.java` (`forbidden`); `device/Devices.java`,
  `DeviceController.java`; `usage/UsageDays.java`, `UsageUploadController.java`,
  `UsageHistoryController.java`; `FocusTraceSyncApplication.java`;
  `application.yml`. No migration, no dependency, no Flutter/Android change.
- Tests: new `device/DeviceQuotaIT`, `usage/StorageBudgetIT`,
  `usage/PerUserRateLimitIT`; `TokenBucketTest` (+1); `IntegrationTest` (per-user
  limits raised for other suites, account-lock barrier helpers).
- Docs: architecture (D18, D16 note, 7.3, 9, 9.1, 9.3), security baseline
  (sections 9, 12, 17, 18, decision table), plan section 5/6, this entry.

Verification (Docker Desktop, PostgreSQL 16 via Testcontainers):
- Focused: `DeviceQuotaIT` 7/7, `StorageBudgetIT` 6/6, `PerUserRateLimitIT` 6/6,
  `TokenBucketTest` 7/7, `DeviceIT` 14/14, `UsageUploadIT` 24/24,
  `UsageConcurrencyIT` 4/4, `UsageHistoryIT` 16/16, `RateLimitIT` 7/7: PASS.
- `./gradlew test --rerun`: PASS, 22 suites, 225 tests, 0 failures, 0 errors,
  0 skipped.
- `./gradlew clean build`: PASS, same 225 tests.
- Race tests hold the account row from the test and wait (polling
  `pg_stat_activity`) until every request is queued on a lock before releasing,
  so overlap is proven, not timed.
- Mutation 1: removed the account lock from `Devices.register`. The barriered
  last-slot test admitted 5/5 racers (7 devices on a quota of 3) and the
  unbarriered rounds admitted 6/6. Restored; SHA-256 identical
  (`7b2cbbb7...65fa6`).
- Mutation 2: removed the account lock before the stored-day count. In 3 of 3
  runs all four racers were admitted (budget 6 exceeded by 3). Restored; SHA-256
  identical (`ae3ceb80...49720`).

Decisions made: D18 (values are configuration; dimensions, keys, `403`/`429`
responses and "reject, never delete" are policy).

Remaining (plan section 5): device retirement/deletion; session and refresh-token
row retention; a page bound for the worst-case history response; client
per-batch watermark progress (the upload burst is sized to cover a full
re-upload instead); proxy-level volumetric limits; in-process limiter means one
instance only. Plan section 6 blockers (privacy copy, account deletion UI,
email verification) are unchanged.

Risks / unresolved questions:
- `RETURNING xmax = 0` is a PostgreSQL implementation detail; the tests pin both
  directions (a replacement at budget passes, a new day at budget is refused).
- A future account or device deletion must take the account row lock first;
  deleting a user while an upload waits for that lock can otherwise deadlock
  (PostgreSQL aborts one side; no deletion endpoint exists today).
- The Sync v1 client maps `403` to an `unknown` failure; there is no quota UI.
- Worst-case per-account storage is still on the order of a few GB (3,650 days x
  500 apps x maximal strings). The values are initial defaults to tune.

Relevant commit: this entry's commit (`fix(server): bound sync resource consumption`).

---

## 2026-09-23 — Phase 5 opt-in periodic synchronization

Date: 2026-09-23; lifecycle blocker closed 2026-09-24
Agent: Codex
Goal: Trigger the existing gated Dart sync repository from Android WorkManager.

Completed:
- Inspected existing changes and checkpointed Phase 4 separately as `db87c03`
  and the cross-engine prerequisite as `dd62ba8`. Phase 3 (`48a1861`) and API 36
  (`31625ed`) were already committed. Unrelated `.agents/` and `skills-lock.json`
  remain excluded. Checkpoint Flutter suite: 195 passed, 0 failed, 1 skipped.
- Unique KEEP work `focustrace_periodic_sync_v1`, every six hours, CONNECTED
  network constraint, no charging/idle/unmetered requirement or notification.
- Opt-in changes and logout reconcile scheduling under the shared gate.
  Startup repairs interrupted reconciliation; the worker rechecks consent
  inside the repository gate. Logout preserves the existing disable-sync policy.
- Activity-free Flutter engine attaches the same native gate and secure-store
  channels as foreground. Tiny Dart entrypoint uses production providers and
  `syncNow(requireEnabled: true)`. No Kotlin HTTP or sync business logic.
- Background connections use SQLite singleInstance=false and close after the
  run; API client/container disposal precedes native completion and destruction.
  Worker cancellation drains the protected operation before engine teardown.
- Success/no-op/disabled/signed-out/revoked/refused complete without retry.
  Transport and HTTP 408/429/500/502/503/504 retry with exponential 30-minute
  backoff, at most three retries per period. Unknown failures do not retry.
- Registration uses Build.MODEL; the existing UUID remains authoritative.
- Closed the blocker that prevented Phase 5 completion: the entire original
  engine invocation was NonCancellable and waited only for `complete`, so failed
  Dart/plugin startup retained both the wait and engine indefinitely.
- Lifecycle: STARTING -> READY -> AUTHORIZED -> RUNNING -> DRAINED -> COMPLETED
  -> CLOSED, with startup exception/deadline/cancellation exits. READY follows
  binding/provider/channel setup and a database-plugin probe without opening a
  database or touching credentials; Dart awaits explicit native authorization.
- A 60-second deadline covers cold loader/VM/plugin startup and authorization
  until actual native gate admission. Only admission suspends the deadline,
  before the gate can queue/grant this engine's single acquisition. Validated
  owner release seals admission and starts a 60-second disposal/completion bound.
  Startup/initialization/post-release timeout is terminal failure, never retry.
- Cancellation before admission destroys safely; afterward it drains the existing
  protected operation. Cleanup never releases a Dart lease itself. One finally
  closes admission, cancels pending waits/timer, detaches handlers and destroys
  the engine once; its existing lifecycle listener retires the caller. Late or
  duplicate callbacks cannot resurrect execution or affect a later engine.

Files materially changed:
- Android: manifest INTERNET permission; MainActivity shared registration;
  new SyncPlatformChannel.kt, SyncScheduler.kt, SyncWorker.kt,
  BackgroundSyncLifecycle.kt; SyncExecutionGateChannel.kt admission/release hooks;
  SyncSchedulerTest.kt, BackgroundSyncLifecycleTest.kt and
  BackgroundSyncInstrumentedTest.kt.
- Dart: main.dart, application/services/background_sync.dart,
  data/datasources/{sync_scheduler,secure_sync_credential_store,
  focus_trace_sync_api,focus_trace_local_data_source}.dart,
  sync_repository_impl.dart, sync_usage.dart, sync_repository.dart,
  providers.dart and focus_trace_app.dart.
- Tests: sync_repository_test.dart, sync_end_to_end_test.dart,
  sync_account_card_test.dart, sync_view_model_test.dart,
  background_sync_lifecycle_test.dart; canonical stage docs.

Verification (rerun 2026-09-24 after the lifecycle fix):
- `flutter analyze`: PASS, no issues.
- `flutter test --reporter expanded`: PASS, 213 passed, 0 failed, 1 skipped
  (real-backend suite without configured backend); includes two new Dart handshake
  tests and the existing 50 repository tests.
- `flutter build apk --debug`: PASS.
- `cd android; ./gradlew :app:testDebugUnitTest`: PASS, 114 total,
  113 passed, 0 failures/errors, 1 skipped benchmark. Includes real WorkManager
  unique enqueue/cancel under Robolectric, cadence/constraints and bounded mapping.
- `./gradlew :app:compileDebugAndroidTestKotlin`: PASS.
- 13 deterministic lifecycle tests cover normal ordering, deadline with paused
  Robolectric time (59,999 + 1 ms), bootstrap exceptions, cancellation before
  READY/authorization/acquisition, active drain, both result/cancel orderings,
  stale callbacks, missing post-release completion, and premature completion.
  Each terminal invocation asserts one completion/cleanup and a free real gate.
- Mutation proof: removed startup `postDelayed`; targeted never-ready test
  failed with `startup deadline must terminate the wait` (Gradle exit 1).
  Production restored byte-identically, SHA-256
  `6a49578dfeccc28cf92cbc4e199401a11858d98ee514fa238f67d880e55fc7ce`;
  the full Android suite subsequently passed.
- Instrumentation now observes real engine destruction and plugin detachment
  after repeated production Dart handshakes, plus cancellation of a real engine
  whose Dart entrypoint is never started. These three Phase 5 tests compile but
  have NOT executed. ADB reports no connected devices, so
  connectedDebugAndroidTest and the Samsung manual/device pass were not run.
- `docker info`: daemon unavailable (`docker_engine` pipe absent); real-backend E2E
  and authenticated background upload were not reverified.
- Repository tests cover disabled upload, model/UUID, transport/server/revoked
  mapping, queued opt-out, background/manual/logout ordering and separate DB close.
- `git diff --check`: PASS. No backend changes or new dependencies.

Security review:
- No secrets or backend messages in WorkManager data, outcomes or new logging.
  Secure credential storage is reused; no access-token persistence or hardware ID.
- Same gate covers background, foreground, opt-out and logout; no second lock.
  KEEP avoids duplicate schedules; unknown errors cannot trigger retry storms.
- Cancellation does not release a lease while live Dart continues to mutate it.

Decisions / remaining / risks:
- Six hours is implementation policy, not an exact-time guarantee. An operation
  already owning the gate may finish before opt-out/logout takes its turn.
- Device runtime proof remains unverified: real headless entrypoint with configured
  repository, gate contention, cancellation/teardown, repeated runs, forced
  WorkManager execution, model registration and logcat secret checks. The default
  unconfigured build's headless test only proves the no-op engine path.
- Startup and post-release completion waits are now bounded. Protected work is
  deliberately not force-timed-out; it retains the established drain semantics.
  Deadline delivery assumes a responsive Android platform looper, as do engine
  creation/destruction and all native method-channel callbacks.
- Phase 5 meets the deterministic acceptance gate; connected-device execution,
  logcat credential inspection and authenticated background upload remain
  unavailable, not claimed as passed. No scheduler/retry/backend policy changed.
- Existing backend public-release blockers remain in the plan; no release-hardening
  work was started. No natural six-hour execution or production readiness claimed.

Relevant commit: the Phase 5 `feat(sync): add reliable background synchronization`
commit containing this entry; resolve its hash with Git history.

---

## 2026-09-23 — Cross-engine sync/session gate prerequisite

Date: 2026-09-23
Agent: Codex
Goal: Close the concurrency blocker that stopped Phase 5, without implementing
WorkManager, background engines, scheduling, retry policy or device naming.

Completed:
- Verified branch `feature/backend-sync-v1`, HEAD `31625ed`. Phase 3 is committed
  (`48a1861`) and API 36 is committed (`31625ed`). Phase 4 remains uncommitted;
  existing UI/localization work and unrelated `.agents/` / `skills-lock.json`
  were preserved. No mixed commit was created.
- Confirmed the race: ViewModel exclusion and API refresh coalescing were local
  to Dart instances. Separate engines could rotate or clear the same persisted
  credential concurrently, race logout, and independently advance the watermark.
- Added a JVM singleton gate with asynchronous FIFO waiters and engine-bound
  ownership plus a per-operation lease. Dart acquires over a small channel and
  releases in `finally`. Native checks reject foreign/stale/duplicate release.
  Engine destruction retires its active lease and pending requests after teardown
  returns to the platform loop. No lock state is persisted.
- Repository ownership covers the whole sync run, remote history, sign-in,
  account creation/sign-in, logout, session reads, installation-ID creation and
  opt-in writes. Helpers do not reacquire. The ViewModel guard stays unchanged.
- Reconcile cached access tokens against the persisted session under the lease,
  so another engine's logout or sign-in cannot leave a usable stale client cache.
  Logout now clears credentials/cache in `finally` even for malformed responses.
- Source and merged manifests have no separate Android process. The engine-only
  channel attachment can be reused by a later worker without Activity ownership.

Files materially changed:
- native: `MainActivity.kt`, new `SyncExecutionGate.kt`,
  `SyncExecutionGateChannel.kt`, `SyncExecutionGateTest.kt`,
  `SyncExecutionGateInstrumentedTest.kt` under the existing Android package
- Dart: new `data/datasources/sync_execution_gate.dart`,
  `focus_trace_sync_api.dart`, `sync_repository_impl.dart`, `providers.dart`
- tests: `sync_repository_test.dart`, `sync_end_to_end_test.dart` (required test
  gate injection only), new `sync_execution_gate_test.dart` and
  `support/test_sync_execution_gate.dart`
- documentation: this entry and architecture section 8.5

Verification:
- `flutter analyze`: PASS, no issues.
- `flutter build apk --debug`: PASS, built `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter test --reporter expanded`: PASS, 195 passed, 0 failed, 1 skipped
  (real-backend suite without its URL). Focused gate/repository rerun after
  strengthening the contender assertion: 36 passed, 0 failed, 0 skipped.
- `cd android; ./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest`:
  PASS. JVM XML totals: 98 total, 97 passed, 0 failures/errors, 1 skipped
  (`UsageStatsAggregationBenchmarkTest.benchmarkFilteredAggregation`).
  Device XML: 15 total/passed, 0 failures/errors/skips, SM-A366B Android 16/API 36.
- Device gate test creates two actual FlutterEngine instances with separate
  channel handlers, calls their native handlers, rejects foreign ownership,
  destroys the active engine, and verifies deferred handoff. It does not run two
  Dart sync entrypoints or a background worker.
- Mutation proof: temporarily removed the native client-identity release check.
  The targeted foreign-owner test failed (1 run, 1 failure, Gradle exit 1).
  SHA-256 comparison confirmed byte-identical restoration; full native gates
  then passed. JVM contention uses a latch, not sleeps.
- Real-backend E2E: BLOCKED, Docker daemon unavailable and no local listener on
  the existing backend/PostgreSQL ports (18080, 18081, 5432). Not executed.
- `git diff --check`: PASS. Existing unrelated working-tree edits preserved.

Decisions made:
- One top-level repository ownership boundary, no per-request/nested locks.
- FIFO completion ordering for sync/auth/logout; no gate retry or expiry policy.
- Gate channel carries only synchronization leases, never credentials. No new
  logs, credential storage, hardware identifiers, dependencies or backend changes.

Remaining / risks:
- Phase 5's cross-engine exclusion prerequisite is implemented. A future worker
  must attach the gate channel and existing credential capability, use the same
  repository gate, and stop Dart before releasing ownership on cancellation.
- Scheduler, cadence/retry/opt-in lifecycle and background integration testing
  remain separate work. No user-facing device sign-in flow was exercised here.
- Engine/process death during refresh still has the existing lost-response
  reauthentication risk; in-flight HTTP effects cannot be undone by a local lock.
- No production release-hardening work was begun.

Relevant commit: uncommitted; kept separate in scope from existing Phase 4 work.

---

## 2026-09-20 — Phase 4: the sync UI slice

Date: 2026-09-20
Agent: Claude Code
Goal: Make the existing sync capability reachable from the app with the
smallest reasonable UI. No scheduler, no background sync, no incremental sync,
no cross-device aggregation, no backend change.

Completed:
- **One new settings section, no new route.** `SyncAccountCard` renders inside
  the existing `SettingsScreen` behind `syncSupportedProvider`, so a build
  without `FOCUSTRACE_SYNC_BASE_URL` is byte-for-byte the app it was.
  Signed out: email, password, Sign in, Create account. Signed in: the account,
  an opt-in switch, Sync now, last successful sync, the current phase and
  Log out.
- **`SyncViewModel`** owns `SyncPhase { idle, syncing, success, error }`,
  refuses a second run while one is in flight, and re-reads the session from the
  repository - and therefore the keystore - on every load.
- **Opt-in is real but lives in the view model, not `syncNow()`.** The
  repository stays the raw capability; nothing calls it but this view model,
  and `canSyncNow` requires the switch. `SyncRepository.isSyncEnabled` is the
  flag a background scheduler must consult when it exists. Putting the check
  inside `syncNow()` would have rewritten ten proven tests for no behaviour.
- **Three device-local settings** under the `sync` prefix, so
  `SyncSettingKeys.isDeviceLocal` already keeps them out of portable backups:
  `sync_enabled`, `sync_last_success_ms`, `sync_account_email`. The email is not
  a credential and is cleared on sign-out.
- **Errors are classified, never echoed.** `SyncAuthException`/`SyncAuthFailure`
  are new domain types: `SyncRepositoryImpl` translates `SyncApiException` into
  them, so no status code, server body or exception string crosses into
  presentation. `SyncRunResult` gained a `SyncFailureReason` for the same reason
  on the sync path. The UI maps both onto localized sentences.
- **A privacy claim that had gone false.** `settingsPrivacyBody` said
  "FocusTrace never uploads them", which stops being true once sync exists in
  the build. A sync-aware variant is shown where sync is available; the original
  sentence is untouched everywhere else.
- 24 new strings across all seven locales. No `@` metadata, matching the
  convention for keys without placeholders.

Files materially changed:
- new: `lib/src/presentation/view_models/sync_view_model.dart`,
  `lib/src/presentation/widgets/sync_account_card.dart`,
  `test/sync_view_model_test.dart`, `test/sync_account_card_test.dart`
- `lib/src/domain/models/sync_usage.dart` (`SyncFailureReason`,
  `SyncAuthFailure`, `SyncAuthException`),
  `lib/src/domain/repositories/sync_repository.dart`,
  `lib/src/data/repositories/sync_repository_impl.dart`,
  `lib/src/data/datasources/focus_trace_local_data_source.dart`,
  `lib/src/presentation/providers.dart`,
  `lib/src/presentation/screens/settings_screen.dart`, `lib/focus_trace.dart`,
  all seven `lib/l10n/app_*.arb` and their generated output

Verification:
- `flutter analyze` -> No issues found.
- `flutter test` -> **185 passed, 1 skipped** (was 159; +26 new).
- `flutter build apk --debug` -> built.
- `cd android && ./gradlew :app:testDebugUnitTest` -> 92 tests, 0 failures.
- `:app:connectedDebugAndroidTest` on the SM-A366B -> 14 tests, 0 failures.
- **End-to-end re-proved against the real backend** after the repository
  changes: `bootRun` on port 18081 against PostgreSQL 16.15 in Docker, then
  `flutter test test/sync_end_to_end_test.dart --dart-define=FOCUSTRACE_SYNC_BASE_URL=http://localhost:18081`
  -> 2 passed.
- **On the device**, with a build made using
  `--dart-define=FOCUSTRACE_SYNC_BASE_URL=https://sync.invalid`: the section
  renders in place, the empty-field guard fires, the password field obscures and
  is cleared after a failed attempt, and a sign-in against an unreachable host
  shows "Could not reach the sync service..." with no hostname, exception type
  or stack trace on screen. Nothing from our process appeared in logcat for
  `hunter2pw`, `refreshToken`, `accessToken` or `Bearer` - the password string
  appears zero times anywhere in the buffer.
- Not exercised on a device: a real signed-in session. The phone cannot reach a
  localhost backend, and pointing it at one over cleartext would mean a
  network-security-config change this task had no business making. The signed-in
  paths are covered by the widget and view-model suites and by the end-to-end
  run on the host.

Decisions made:
- Turning sync off disables Sync now as well. Opt-in that still allowed manual
  uploads would not be opt-in.
- Sign-out leaves `sync_usage_watermark_ms` alone: the server still holds what
  this device uploaded, and signing back in should not re-send all of it.
- A sync run that finds nothing to send still stamps the clock, so "last synced"
  does not look permanently stale on an idle device.
- A `sessionExpired` result drops the UI to signed out, because the credential
  store has already cleared the token by then.

Remaining:
- No scheduler and no background sync; `isSyncEnabled` exists for it.
- The opt-in gate is not enforced inside `syncNow()`. Any future caller that is
  not this view model must check it.
- `display_name` is still the fixed string `'Android device'`.

Risks / unresolved questions:
- With the soft keyboard open, an injected `KEYCODE_BACK` exited the app rather
  than closing the keyboard. Under targetSdk 36 that key is no longer dispatched
  to the app, so an injected event is not the same path a real gesture takes,
  and an attempt to reproduce it with the on-screen back button did not register
  the tap. Unverified either way; worth one manual check on a device.

Relevant commit: (uncommitted at time of writing)

---

## 2026-09-20 — Android 16 / API 36 targeting

Not sync work. Recorded here because it closes the follow-up the Phase 3 entry
below left open, and there is no separate Android stage document.

Date: 2026-09-20
Agent: Claude Code
Goal: Move targetSdk 35 -> 36 and compileSdk 35 -> 36 without regressing usage
tracking, blocking, overlays, restrictions, lifecycle or WorkManager.

Completed:
- `compileSdk = 36`, `targetSdk = 36`, `minSdk = 23` unchanged. Both were
  sourced from Flutter's defaults (35) and are now pinned explicitly.
- **AGP 8.7.3 -> 8.9.1**, required: 8.9.1 is the minimum that supports
  compileSdk 36. Gradle 8.12 and JDK 21 already met its requirements, so the
  wrapper and toolchain are untouched.
- **Back handling in `BlockActivity`, required.** For targetSdk 36 the platform
  stops calling `onBackPressed` and stops dispatching `KEYCODE_BACK`, so the
  override guarding "back must not drop the user into the blocked app" would
  have gone dead and the system's own predictive back would have run instead.
  It now registers an `OnBackInvokedCallback` on API 33+, with `onBackPressed`
  kept for 23-32.
- `SecureCredentialStoreTest` pinned to `@Config(sdk = [35])`: Robolectric
  4.15.1 refuses an SDK above its maximum, and the package now targets 36. The
  existing `UsageHistoryRecoveryTest` already pinned its SDK the same way. The
  real API 36 coverage for that class is the instrumented suite.

Deliberately not changed, having checked the code rather than assuming:
- Edge-to-edge: no `windowOptOutEdgeToEdgeEnforcement` anywhere, and targetSdk
  35 already enforced it. Verified visually on device - no bar overlap.
- Adaptive layouts: no `screenOrientation`, `resizableActivity` or aspect-ratio
  attributes are declared, so there is nothing for API 36 to ignore.
- `android:pageSizeCompat`: unnecessary. The APK passes `zipalign -c -P 16` and
  the test device reports `PAGE_SIZE=4096`.
- Ordered-broadcast priority, `scheduleAtFixedRate`, intent-redirection
  hardening, health/Bluetooth/MediaStore/local-network changes: none of the
  APIs involved appear in this repository.
- JobScheduler quota tightening applies to every app on Android 16 regardless of
  targetSdk, so it already applied before this change.

Verification (Samsung SM-A366B, Android 16, API 36):
- `flutter analyze` -> No issues found. `flutter test` -> 159 passed, 1 skipped.
- `:app:testDebugUnitTest` -> 92 tests, 0 failures, 1 ignored.
- `:app:connectedDebugAndroidTest` -> 14 tests, 0 failures.
- `flutter build apk --debug` -> built; merged manifest `minSdkVersion="23"`
  `targetSdkVersion="36"`, APK badging `compileSdkVersion='36'`.
- Exercised on the device against the real app: launch; usage tracking (the
  dashboard read real UsageStats, and launches rose 8 -> 10 across the session);
  a "block now" rule on Calculator producing the `TYPE_APPLICATION_OVERLAY`
  block screen, with back going to the launcher rather than back into the app;
  a rule on TikTok producing `BlockActivity`, where logcat shows the
  `ACTION_MAIN`/`CATEGORY_HOME` intent started from our own uid on back - proof
  the new callback ran rather than a system default; `BlockerService` running as
  a foreground service with `types=0x40000000` (specialUse) under
  `targetSdkVersion:36`; background/foreground transitions; process death and
  relaunch leaving the database intact and the restriction still applied;
  `#UsageSnapshotWorker#` registered with JobScheduler and RUNNABLE.
- Not exercised as a user flow: sign-out, because sync still has no UI. Its
  credential clearing is covered by the connected tests and the Dart suite.

Remaining:
- `docs/` has no Android platform stage; if this area grows, it needs one.

Relevant commit: (uncommitted at time of writing)

---

## 2026-09-20 — Phase 3: secure credential persistence

Date: 2026-09-20
Agent: Claude Code
Goal: Persist the sync refresh token in OS-backed storage so a restart no longer
forces a new sign-in, using the existing `SyncCredentialStore` seam. No UI, no
scheduler, no background sync, no change to the backend API contract.

Completed:
- **`minSdk` 21 -> 23, and the open decision from Phase 2 is closed.**
  `KeyGenParameterSpec` and AES in `AndroidKeyStore` are API 23; below it the
  credential could only be stored in the clear, which baseline section 8
  forbids. Android 5.0/5.1 are dropped. Nothing else in FocusTrace needed API
  21: tracking, restrictions, blocking, schedules, the widgets and the WorkManager
  2.10.x pin all work unchanged at 23.
- **`SecureCredentialStore.kt`**: AES-GCM under an `AndroidKeyStore` key that
  never leaves the keystore, ciphertext (12-byte nonce prefixed) base64 in a
  private `SharedPreferences` file. Every failure path deletes the value and
  reports "no credential".
- **`SecureSyncCredentialStore`** implements `SyncCredentialStore` over the
  existing `focustrace/usage` channel; `syncRepositoryProvider` now builds it.
  `InMemorySyncCredentialStore` was deleted with its last caller. The access
  token is unchanged: a field on `FocusTraceSyncApi`, never written.
- **Backup exclusion**, which was a real gap: the manifest sets no
  `android:allowBackup`, so Auto Backup would have uploaded the credential file.
  `@xml/backup_rules` (API 23-30) and `@xml/data_extraction_rules` (API 31+)
  exclude it from cloud backup and device-to-device transfer, and nothing else
  changes. Portable export/import already stripped every `sync` key
  (`SyncSettingKeys.isDeviceLocal`) and the token was never in SQLite.
- **No dependency added.** `flutter_secure_storage` and
  `androidx.security:security-crypto` were both rejected: the platform provides
  the primitive directly, and the latter is deprecated. `pubspec.yaml` and
  `pubspec.lock` are unchanged; the only Gradle additions are
  `androidx.test:runner` and `androidx.test.ext:junit`, both
  `androidTestImplementation`, for the instrumented tests below.
- **Instrumented coverage on a real device, which found a real defect.**
  `write` used `SharedPreferences.apply()`, which returns before the value
  reaches disk. On a rotation that window does not cost a sign-in: the file
  still holds the refresh token the server has just consumed, and presenting a
  consumed token trips replay detection and revokes the session chain
  (architecture D10). Now `commit()`, in `write` and in `clear`, with a test
  that fails if the value is not on disk when the call returns.

Files materially changed:
- new: `android/app/src/main/kotlin/.../SecureCredentialStore.kt`,
  `android/app/src/main/res/xml/backup_rules.xml`,
  `android/app/src/main/res/xml/data_extraction_rules.xml`,
  `lib/src/data/datasources/secure_sync_credential_store.dart`,
  `android/app/src/test/kotlin/.../SecureCredentialStoreTest.kt`
- `android/app/build.gradle.kts` (`minSdk = 23`),
  `android/app/src/main/AndroidManifest.xml`, `.../MainActivity.kt` (three
  channel methods), `lib/src/data/datasources/focus_trace_sync_api.dart`
  (`InMemorySyncCredentialStore` removed), `lib/src/presentation/providers.dart`,
  `lib/focus_trace.dart`
- tests: `test/sync_repository_test.dart` (+7), `test/data_transfer_test.dart`
  (+1), `test/sync_end_to_end_test.dart` (+1)

Verification:
- `flutter analyze` -> No issues found.
- `flutter test` -> 159 passed, 1 skipped (the end-to-end proof, skipped without
  a backend URL).
- `cd android && ./gradlew :app:testDebugUnitTest` -> BUILD SUCCESSFUL, 92 tests,
  0 failures, 1 ignored.
- `flutter build apk --debug` -> built. Merged manifest: `minSdkVersion="23"`,
  `targetSdkVersion="35"`, both backup-rule attributes present.
- `cd android && ./gradlew :app:connectedDebugAndroidTest` on a Samsung
  SM-A366B (Android 16, API 36, arm64-v8a) -> **14 tests, 0 failures**. Covers
  the real AndroidKeyStore: round trip, rotation, clear, nothing readable at
  rest with a fresh nonce per write, a corrupted blob and a blob whose key was
  deleted both failing closed and being removed, the backup and
  device-transfer exclusions, and the file being unreachable outside the app
  uid. Installed as `minSdk=23 targetSdk=35` with `ALLOW_BACKUP` set, which is
  what makes the exclusion load-bearing.
- **Persistence across a real process death**, not across two Kotlin objects:
  `am instrument` run three times with `am force-stop` between, writing in pid
  17315 and reading the value back in pid 17367.
- **Key security level actually observed on that device** (reported, never
  asserted): `securityLevel=1` (`SECURITY_LEVEL_TRUSTED_ENVIRONMENT`),
  `origin=1` (`ORIGIN_GENERATED`), AES-128, with
  `android.hardware.hardware_keystore=300` and no StrongBox feature present.
  This is one device's property, not a guarantee the code can make.
- **End-to-end against the real backend**: `server` under `bootRun` on port
  18080 against PostgreSQL 16.15 in Docker, then
  `flutter test test/sync_end_to_end_test.dart --dart-define=FOCUSTRACE_SYNC_BASE_URL=http://localhost:18080`
  -> 2 passed. The new case signs in, discards every Dart object, rebuilds from
  the keystore value alone, uploads and reads back through real rotation, then
  signs out and finds the next launch anonymous.

Decisions made:
- **The crypto path is covered by instrumented tests, not JVM ones.** There is
  no `AndroidKeyStore` provider off-device, so Robolectric cannot exercise
  encrypt/decrypt, and adding a seam to production code so a test could inject a
  JCE key would be a test defining the implementation. `SecureCredentialStoreTest`
  covers what that environment does reproduce exactly - a value that cannot be
  decrypted - and `SecureCredentialStoreInstrumentedTest` covers the rest on a
  device.
- **`commit()` over `apply()`** costs a small synchronous write on the channel's
  thread, on sign-in and rotation only. Correctness on a credential is worth
  more than that.
- **`targetSdk` stays 35.** It was 35 before this work, not 36; raising it is an
  Android 16 behaviour change across overlay, foreground service and
  edge-to-edge, which is a product decision about blocking and tracking, not a
  credential one.
- A write failure degrades to a process-lifetime session rather than failing the
  sign-in, matching `syncNow`'s rule that sync never surfaces as an app failure.

Remaining:
- `display_name` is still the fixed string `'Android device'`.
- Still no UI, no scheduler and no background sync; nothing calls `syncNow()`.
- **`targetSdk` 35 -> 36 is a required follow-up with its own verification.**
  The product requirement is Android 16 / API 36; the repository targets 35 and
  did so before this work. It was deliberately not changed here: Android 16
  changes overlay, foreground-service and lifecycle behaviour, so it needs a
  blocker/overlay/lifecycle regression pass of its own rather than riding along
  with a credential change. The test device already runs API 36, so the app runs
  there today in compatibility mode.

Risks / unresolved questions:
- A user who restores a backup onto a new device, or whose keystore is wiped,
  is silently signed out. That is the intended fail-closed behaviour, but with
  no UI there is nothing to tell them yet.

Relevant commit: (uncommitted)

---

## 2026-09-20 — Phase 2: Flutter sync client and the end-to-end proof

Date: 2026-09-20
Agent: Claude Code
Goal: Resolve the versionless-day version policy, build the smallest complete
Flutter sync slice behind `domain -> sync repository -> remote data source`, and
prove Device B reads Device A's history through the real API. No UI, no
scheduler, no scope beyond Sync v1.

Completed:
- **Version policy resolved and written down before client code depended on it**
  (architecture 7.2). A day with no `usage_snapshot_days` row uploads under
  `sync_imported_version_ms`, one settings value holding the wall clock at the
  moment that versionless content was last established. The old rule
  (`snapshot_version = 1`) regressed below any real uploaded version and reused
  one version across two different imports; both are permanent `STALE`/`CONFLICT`
  states the server cannot repair.
- **Architecture risk 3 verified and closed.** `importPortableData` replaces
  `daily_app_usage` rows in place and advances no `queried_at_ms`, so a
  watermark alone would never re-offer them. `_invalidateUsageRecovery` now
  advances the stamp and resets `sync_usage_watermark_ms` to `0` in the same
  transaction that clears the snapshot rows and rotates
  `usage_recovery_generation`.
- **Found and fixed a portability defect while implementing it.**
  `exportPortableData` excluded only `usage_recovery_generation`, so a backup
  would have carried `sync_installation_id`; restoring it onto a second
  installation would have made two installations upload as one device, each
  overwriting the other under one `(device_id, local_date)` key. Every `sync`
  key is now excluded from export and dropped on import.
- **Client** (architecture 8.4): `SyncRepository` (domain), `SyncRepositoryImpl`
  (selection, sanitization, batching, watermark), `FocusTraceSyncApi` (the only
  HTTP in FocusTrace, plus the access-token lifecycle with one coordinated
  refresh), `UsageSyncDataSource` (read-only local selection). Installation UUID
  v4 in `settings`, app-generated, never hardware-derived. `syncNow` never
  throws; sync is opt-in through `--dart-define=FOCUSTRACE_SYNC_BASE_URL` and is
  `null` without it.
- **No new dependency.** Transport is `dart:io` `HttpClient` with
  `dart:convert`; tests drive a real local `HttpServer`. `pubspec.yaml` and
  `pubspec.lock` are unchanged.

Files materially changed:
- new: `lib/src/domain/models/sync_usage.dart`,
  `lib/src/domain/repositories/sync_repository.dart`,
  `lib/src/data/datasources/focus_trace_sync_api.dart`,
  `lib/src/data/repositories/sync_repository_impl.dart`
- `lib/src/data/datasources/focus_trace_local_data_source.dart`:
  `SyncSettingKeys`, `UsageSyncDataSource.readSyncUsageDays`, portable
  export/import filter, `_invalidateUsageRecovery`
- `lib/src/presentation/providers.dart` (`syncSupportedProvider`,
  `syncRepositoryProvider`), `lib/focus_trace.dart`
- new tests: `test/sync_local_selection_test.dart` (10),
  `test/sync_repository_test.dart` (19), `test/sync_end_to_end_test.dart` (1,
  skipped without a live backend)
- architecture 7.2, 8.2, 8.4 and risk 3; plan 5

Verification:
- `flutter analyze` -> No issues found.
- `flutter test` -> **151 passed, 1 skipped** (the end-to-end proof, which is
  skipped unless a backend URL is supplied, so the suite needs no Docker).
- `flutter build apk --debug` -> built.
- `cd android && ./gradlew :app:testDebugUnitTest` -> BUILD SUCCESSFUL.
- **End-to-end against the real backend**: `server` running under `bootRun` on
  port 18080 against PostgreSQL 16.15 in Docker, then
  `flutter test test/sync_end_to_end_test.dart --dart-define=FOCUSTRACE_SYNC_BASE_URL=http://localhost:18080`
  -> passed. Two independent installations, one account: A registered and
  uploaded two days, a second run sent nothing, a forced re-upload answered
  `DUPLICATE` twice, B registered and uploaded the same date with different
  content, B read A's days back with `deviceId` and `deviceName` intact, both
  re-ran with no change, A's local rows were byte-identical, and a third account
  saw nothing (including with A's `deviceId` as the filter).
- Verified directly in PostgreSQL afterwards: each run left exactly 2 devices,
  3 `usage_days` rows and 3 `usage_day_apps` rows, with `2026-09-18` present
  once per device at 222 s and 999 s - two measurements, never summed.
- Mutation checks, each restored byte-identical: removing the single-flight
  refresh, disabling NUL/surrogate stripping, and advancing the watermark on a
  transient failure each fail `sync_repository_test.dart`.

Decisions made:
- **Credentials are not persisted, and no dependency was added for them.** Both
  tokens are memory-only. Baseline section 8 requires OS-backed storage, and
  every Android mechanism that provides it - `EncryptedSharedPreferences`, a
  Keystore AES key, `flutter_secure_storage` - requires API 23. FocusTrace
  targets API 21 on purpose (the WorkManager 2.10.x pin). `flutter_secure_storage`
  was added, failed the APK build on exactly that, and was removed; `pubspec` is
  back to its original state. Storing nothing is stronger than storing it in the
  clear. `SyncCredentialStore` is the seam a real store slots into.
  **Raising `minSdk` to 23 drops Android 5.x and is a product decision, not a
  sync one. It is open.**
- A deterministic `400` is counted as rejected and the watermark advances past
  it. Resending an identical request forever is the retry loop architecture 9.1
  forbids. Those days stay local and authoritative.
- A transient failure leaves the watermark alone; already-sent batches simply
  answer `DUPLICATE` next time.
- Device registration runs once per sync run, not once ever: `POST /devices` is
  idempotent and it keeps `last_seen_at` current.
- A versionless day's `timezoneId` is `UTC`. `usage_snapshot_days` is not
  portable, so an imported or pre-v5 day genuinely has no recorded zone.
- Windows is out of scope for the client. Every Windows day is Dart-written with
  no snapshot row and the current day mutates within the day, which one stamp
  cannot express. The Windows shell is on a parked branch (risk 8).

Remaining:
- The `minSdk` 21-vs-23 decision above.
- No UI and no scheduler: `syncNow()` works but nothing calls it yet. Sign-in, an
  opt-in switch and a background trigger are the next client stage.
- `display_name` is the fixed string `'Android device'`; architecture section 3
  wants `Build.MODEL`, which needs a platform call this stage did not add.
- A versionless day holding no app rows is never offered (that selection is
  driven by `daily_app_usage`).
- Backend release hardening is unchanged: device lifecycle and an active-device
  quota, a persistent-storage bound per account, authenticated per-user limits
  for `PUT /sync/usage-days` and `GET /usage`, and the `README.md` /
  `docs/privacy.html` statements that sync makes inaccurate.

Risks / unresolved questions:
- A wall-clock regression can put `sync_imported_version_ms` below a version
  already uploaded, which reads as `STALE` until the next advance. Same
  consequence as risk 1: a stale server copy, never local corruption.
- A full re-upload after an import loads every selected day into memory at once.
  Acceptable at this data scale; risk 4 already records the trade-off.

Relevant commit: `97236e3`.

---

## 2026-09-20 — Phase 1 Step 5: usage history read; Phase 1 complete

Date: 2026-09-20
Agent: Claude Code
Goal: Commit the pending Step 4 work, implement `GET /api/v1/usage` per
architecture 9.3, and close plan criteria 11 and 13. No Flutter work.

Completed:
- **Step 4 committed unchanged** after re-running the full gate on the working
  tree. The `timezoneId <= 64` bound is ratified and settled; no document now
  describes it as open.
- **Step 5** (`usage/UsageHistoryController` + `UsageDays.history`):
  `GET /api/v1/usage?from=&to=[&deviceId=]`, authenticated, `from` inclusive,
  `to` exclusive, range 1-400 days. Response per architecture 9.3, carrying
  `deviceId` and `deviceName` so source identity survives the read.
- One SQL statement per request: `usage_days JOIN devices` (ownership is the
  predicate, D16) `LEFT JOIN usage_day_apps`. No N+1, and a day whose snapshot
  holds no apps is returned with `"apps": []` rather than disappearing.
- Architecture section 10's layout sketch corrected to the tree as built.

Files materially changed:
- `server/src/main/java/.../sync/usage/UsageHistoryController.java` (new)
- `server/src/main/java/.../sync/usage/UsageDays.java`: `MAX_HISTORY_DAYS`,
  `HistoryDay`, `history(...)`, `toHistory(...)`
- `server/src/test/java/.../sync/usage/UsageHistoryIT.java` (new, 16 tests),
  `UsageTestSupport.java` (`newDevice(account, displayName)` overload)
- architecture 9.3 and 10, plan 3 and 5, baseline status clarification, this document

Verification (Docker 25.0.3, Testcontainers PostgreSQL 16.15):
- Before committing Step 4: `cd server && ./gradlew clean build` -> exit 0;
  189 tests, 0 failures, 0 errors, 0 skipped, 18 suites. Committed as `93f6da4`.
- `./gradlew test --tests '*UsageHistoryIT'` -> 16 tests, 0 failures.
- `cd server && ./gradlew test --rerun` -> exit 0.
- `cd server && ./gradlew clean build` -> exit 0; **205 tests, 0 failures, 0
  errors, 0 skipped, 19 suites**.
- Mutation checks on the history SQL, each restored byte-identical afterwards:
  dropping `dev.user_id = :userId`, making `to` inclusive, and ignoring the
  `deviceId` predicate each fail `UsageHistoryIT`.

Decisions made (architecture 9.3):
- `to <= from` is `400`, not an empty result. `to` is exclusive, so such a range
  asks for nothing and is a client bug worth reporting.
- Ordering is contract: days by `localDate` then `deviceId`, apps by `appKey`.
  An unchanged stored day always reads back identically.
- A `deviceId` the caller does not own and one that does not exist both return
  `{"days":[]}`, from the same query, with no preceding lookup. That is D16's
  "collections filter, they do not fail" - `404` would have needed an extra
  statement to say the same thing.
- The history read reuses the upload's `App` record. Same contract, same shape;
  a second identical model would have no boundary reason.
- Response DTOs, not entities; there is no JPA entity to expose.

Acceptance criteria: Phase 1 criteria 1-18 (including 16a-16e) are all PROVEN by
tests executed against PostgreSQL. Criterion 11's history half and criterion 13's
usage-read half were the last two open, and `UsageHistoryIT` closes both.

Remaining:
- Phase 2 (Flutter sync client). Before upload code exists: the client version
  policy for imported, legacy and Dart-written days (architecture 9.2) and client
  pre-validation/sanitization (9.1). Note that `usage_recovery_generation`
  rotation (portable import and clear-all) mutates historical days without
  advancing any `queried_at_ms`, so a watermark alone would miss them.
- Before public release: device lifecycle and an active-device quota, a
  persistent-storage bound per account, and authenticated per-user limits for
  `PUT /sync/usage-days` and `GET /usage` (baseline section 11).

Risks / unresolved questions:
- The 400-day cap bounds one response along the date axis only. An account with
  many devices still gets one entry per device per date, so the response is
  bounded by what that account itself uploaded, not by the request. Baseline
  section 9 already reserves a page bound for the point where that matters.

Relevant commits: `93f6da4` (Step 4, usage upload) and `1d27ab2` (Step 5, history
read). Both were verified before committing; neither includes unrelated files.

---

## 2026-09-20 — Step 4 contract-conformance review

Date: 2026-09-20 (session spanned midnight; the Step 4 entry below is dated 2026-09-19)
Agent: Claude Code
Goal: Check three suspected contract-conformance issues in the uncommitted Step 4
work: the `timezoneId` bound, the control-character rule, and response ordering.
No redesign, no scope expansion.

Completed:
- **`timezoneId <= 64`: kept, justification corrected.** No bound existed before
  Step 4 anywhere - `V1__baseline.sql:39` and the client's `timezone_id` are both
  unbounded `TEXT`, and the architecture said only "resolvable by `ZoneId.of`". The
  docs justified 64 with "the longest resolvable region ID is 32", which is an
  observation about the current JDK tzdb, not a durable contract. Now documented as
  a bounded API/storage limit with ample room, validity still decided by `ZoneId.of`.
- **Control characters: narrowed (contract expansion, reverted).** Step 4 rejected
  all of `\p{Cc}` in `appKey`/`appName`, copied from the `displayName` rule
  (`DeviceController.java:41`), which is a device contract for a user-typed string.
  Nothing in the schema, the client or the architecture required it for app keys or
  labels, and an OS label containing a newline would have failed that day's upload
  on every retry. Now `[^\x{0}\p{Cs}]*`: only NUL (PostgreSQL text cannot hold it)
  and unpaired surrogates (the driver would store `?`, breaking retry equality).
  Other control characters are stored verbatim.
- **Response ordering: already correct, proof strengthened.** `UsageDays.upload`
  processes a sorted copy (line 84) and builds the response by walking the original
  `request.days()` list (line 86); dates are unique per request, so the lookup is
  exact. Internal ascending-date lock ordering unchanged.

Files materially changed:
- `server/src/main/java/.../sync/usage/UsageUploadController.java` (`PRINTABLE` ->
  `STORABLE`, narrowed pattern)
- `server/src/test/java/.../sync/usage/UsageUploadIT.java`: dropped the "tab is
  rejected" case; added `storesOtherControlCharactersExactlyAndRetriesAsDuplicate`;
  replaced the ordering test with `unsortedRequestIsAnsweredInRequestOrder`
- `backend-sync-architecture.md` 9.1 (string rule, `timezoneId` justification,
  client sanitization obligation), `backend-security-baseline.md` section 9 table,
  this document

Verification:
- `./gradlew test --tests '*UsageUploadIT'`: 24 tests, 0 failures.
- `cd server && ./gradlew clean build`: exit 0; 189 tests, 0 failures, 0 errors,
  0 skipped, 18 suites; Testcontainers PostgreSQL 16.15, Docker 25.0.3.
- `unsortedRequestIsAnsweredInRequestOrder` submits 09-10, 09-08, 09-09 against a
  stored 09-08 v5 and asserts results in that request order (`APPLIED`, `STALE`,
  `APPLIED`) plus the persisted rows per day. Mutation: answering in sorted order
  fails it; code restored byte-identical.
- Control-character test asserts tab, newline, CR, ESC, DEL and paired surrogates
  persist byte-for-byte and re-upload as `DUPLICATE`.

Decisions made:
- `appKey`/`appName` reject only NUL and unpaired surrogates. No Unicode
  normalization, no broader sanitization.
- Response order is request order; processing order is ascending `localDate`. The
  two are independent and both are now contract.

Remaining:
- Nothing. The `timezoneId <= 64` bound was ratified on 2026-09-20 and is now
  settled contract: a bounded API/storage limit, with validity still decided by
  `ZoneId.of`.

Risks / unresolved questions: none from this review.

Relevant commit: none; still uncommitted with the Step 4 work.

---

## 2026-09-19 — Phase 1 Step 4: usage upload implemented

Date: 2026-09-19
Agent: Claude Code
Goal: Implement `PUT /api/v1/sync/usage-days` per architecture 7.3 and 9.1-9.2,
settling D13. No history read, no Flutter work.

Completed:
- `usage/UsageUploadController` (record DTOs, Bean Validation) and `usage/UsageDays`
  (JdbcClient SQL, one `@Transactional` unit): owner gate `FOR KEY SHARE` (404 per
  D16), request-wide validation before any write, days sorted by `localDate`,
  owner-scoped guarded upsert, whole-day app replacement, equal-version content
  comparison. Outcomes `APPLIED`/`DUPLICATE`/`STALE`/`CONFLICT`, one per day, in
  request order. `CONFLICT` is new to the section 9.2 response.
- Limits (D13 resolved): Jackson document length 2,097,152; 1-31 days; 500 apps/day;
  1,000 rows/request; duration 0-90,000; date `2026-01-01` to UTC today + 1;
  `timezoneId` at most 64 units and resolvable; string bounds 255/200 with no
  NUL or lone surrogates (other control characters are stored verbatim).
- `V3__usage_duration_dst.sql`: duration CHECK `<= 86400` -> `<= 90000` (25-hour DST day).
- `ApiException.notFound()`; UTC `Clock` bean (tests pin it); backend CI job.

Files materially changed:
- `server/src/main/java/.../sync/usage/{UsageUploadController,UsageDays}.java` (new),
  `common/ApiException.java`, `FocusTraceSyncApplication.java`,
  `resources/application.yml`, `resources/db/migration/V3__usage_duration_dst.sql` (new)
- `server/src/test/java/.../sync/usage/{UsageTestSupport,UsageUploadIT,UsageConcurrencyIT}.java`
  (new), `IntegrationTest.java` (PUT helper), `FlywayBaselineIT.java` (V3),
  `auth/AuthSchemaIT.java` (V2 test now targets V2 explicitly instead of latest)
- `.github/workflows/ci.yml` (backend job)
- architecture 6.2/7.3/9.1/9.2/12/14, plan 3 and 5, baseline status note and sections 9, 17, 19, 20

Verification:
- Baseline before changes: `./gradlew test --rerun`: 160 tests, 0 failures, 0 skipped.
- Final `cd server && ./gradlew clean build`: exit 0; 189 tests, 0 failures, 0 errors,
  0 skipped, 18 suites; Testcontainers PostgreSQL 16.15, Docker 25.0.3.
- `UsageUploadIT` (24): contract; unsorted request answered in request order;
  supersede; empty replaces non-empty; stale; duplicate with reordered apps;
  conflict on each content field; mixed outcomes in one request; every limit at its
  accepted edge and one past it, with zero writes; NUL and lone surrogates (raw
  JSON escapes) rejected, tab/newline stored verbatim; 401;
  foreign device = unknown device (same 404 body), A's rows byte-identical; same
  date across devices and accounts; DB failure on a later day rolls back earlier
  days; failure after the app delete restores the day; max contract request (about
  1.44 MB, 3-byte strings) is 200; 3 MiB body is 400 with and without Content-Length.
- `UsageConcurrencyIT` (4, 8 rounds each, real parallel HTTP): newer vs older;
  equal identical = `APPLIED` + `DUPLICATE`; equal differing = `APPLIED` +
  `CONFLICT` with the winner's rows; four overlapping 10-day batches in opposite
  JSON order: no 5xx, highest version and its complete app set on every day.
- Mutation checks, all restored byte-identical: removing the date sort ->
  PostgreSQL `deadlock detected`, test fails; guard `<` -> `<=` fails 5 tests;
  owner gate `AND` -> `OR` fails the foreign-device test; document limit raised
  to 20 MiB -> the oversized test fails (proves the configured limit rejects it).
- CI job not executed here (no push); it runs `bash ./gradlew build` because
  `server/gradlew` is tracked as 100644.

Decisions made:
- D13: 1,000 app rows and 31 days per request (architecture 9.1).
- `timezoneId` length bound 64: new in Step 4 (no bound existed; column is `TEXT`).
  A generous API/storage limit; validity is `ZoneId.of`. Ratified 2026-09-20 -
  see the conformance-review entry above.
- Oversized document stays the framework's generic 400; no 413 mapping.
- Upload does not touch `devices.last_seen_at` (not in the contract).
- Layout: `usage/` package; `UsageDays` owns the SQL as `Devices` does. No JPA entity
  and no separate service (section 10 sketch named `sync/SyncController`).

Remaining:
- Step 5 `GET /api/v1/usage`; criterion 11's history half; criterion 13's read half.
- Before Flutter sync: client version policy for imported/legacy/Dart-written days;
  client pre-validation and sanitization (architecture 9.1, 9.2).
- Before public release: device lifecycle and active-device quota, a persistent
  storage bound, authenticated per-user limits for upload/history (plan 5).

Risks / unresolved questions:
- Baseline section 11 asks for an authenticated per-user limit on upload; not in
  Step 4 scope, recorded as a release item.

Relevant commit: none yet; changes are uncommitted.

---

## 2026-09-19 — Readiness review briefing

Date: 2026-09-19
Agent: Codex
Goal: Inspect current backend docs and implementation; prepare context for an
external ChatGPT review and next-step recommendation.

Completed:
- Added `backend-sync-v1-review-brief.md`, a dated assessment at `d2b7271`, not a
  replacement architecture. Steps 1–3 exist; upload/history/client remain open.
- Distinguished confirmed resource-control gaps, accepted auth trade-offs,
  planned-sync questions, historical test results and unverified deployment state.
- Corrected documentation framing: PostgreSQL owns session state; only limiter
  state is in-process. Auth throttling does not cover device/sync/read traffic.

Files materially changed:
- `docs/backend/backend-sync-v1-review-brief.md` (new), this progress document,
  `backend-sync-v1-plan.md`, `docs/security/backend-security-baseline.md`.

Verification:
- Inspected Git status/diffs/history, backend sources/config/migrations/test
  sources, CI, and local snapshot/import code.
- BLOCKED: `cd server; .\gradlew.bat test --rerun-tasks` exited 1 while downloading
  Gradle 9.5.1 (`SocketException: Permission denied: connect`). No compilation or
  tests ran; Docker availability was not established. Prior 160-test PASS remains
  historical evidence only. Build not run because bootstrap was blocked.
- `git diff --check`: PASS. No runtime files modified.

Decisions made:
- No architecture or security policy changed; briefing recommendations are proposals.

Remaining:
- Resolve D13 and upload semantics, implement Steps 4–5, complete Phase 1 tests,
  then Phase 2. Re-run server verification in a network-enabled Java 21/Docker
  environment. Add backend CI; current CI covers Flutter/Android only.

Risks / unresolved questions:
- Device growth/list bounds, JSON body cap, future upload/read budgets, limiter
  saturation/proxy handling, token retention and deployment readiness.
- Imported-day version 1 cannot propagate later edits by merely resetting a
  watermark; future portable backups must not copy installation identity/state.

Relevant commit: inspected `d2b7271`; this documentation review is uncommitted.

---

## 2026-09-18 — D16 resolved; Phase 1 Step 3: devices implemented

Date: 2026-09-18
Agent: Claude Code
Goal: Settle D16, then implement `POST /api/v1/devices` and `GET /api/v1/devices`
per architecture sections 3 and 9 and D12. No usage upload.

Completed:
- D16 recorded in architecture 5.1: private user-owned objects are resolved with the
  owner in the query; foreign = nonexistent = generic `404`, no side effect, never
  `403`. Scope limit: D12's `409` on `POST /devices` stays, as the one documented
  existence-disclosing contract. Baseline register updated.
- `device/Devices` (JdbcClient SQL) + `device/DeviceController` (record DTOs).
  Registration is two statements deciding by returned row:
  `INSERT ... ON CONFLICT (id) DO NOTHING RETURNING` (201), else
  `UPDATE ... WHERE id = :id AND user_id = :userId RETURNING` (200), else `409` with a
  generic body and a `device_id_conflict` security log line. No statement assigns
  `user_id` to an existing row. Listing is `WHERE user_id = :userId`.
- Contract details (architecture 9): v4 UUID required; `platform` fixed at first
  registration; `displayName` 1-100, no control chars, no lone surrogate; response
  has no owner field. No schema change: `V1` `devices` already had
  `user_id NOT NULL REFERENCES users ON DELETE CASCADE`.

Files materially changed:
- `server/src/main/java/.../sync/device/{Devices,DeviceController}.java` (new)
- `server/src/test/java/.../sync/device/DeviceIT.java` (new, 14 tests)
- `docs/backend/backend-sync-architecture.md` (status, D16, 5.2, section 9 device
  contract), `backend-sync-v1-plan.md` section 5,
  `docs/security/backend-security-baseline.md` section 19.

Verification:
- `cd server && ./gradlew test --rerun`: 160 tests, 0 failures, 0 skipped, 16 suites
  (Testcontainers PostgreSQL 16.15, Docker 25.0.3). `./gradlew build`: exit 0.
- `DeviceIT` covers: 201 create under caller; 401 unauthenticated / bad token with no
  row; same-user re-registration 200, one row, `user_id` and `registered_at`
  unchanged; listing isolation (A, B, fresh account); B's UUID from A is 409, body
  free of B's name/id/device id, row byte-identical, A's list empty, B still works;
  repeated takeover attempts; two-thread races (two users: exactly one 201 + one 409,
  one row, winner owns it, 5 rounds; same user: 201 + 200, one row); `userId`,
  `user_id`, `ownerId`, `registeredAt`, `lastSeenAt` in the body are 400 with no row;
  non-v4 / nil / malformed UUID, blank/overlong name, bad platform, control chars,
  lone surrogate, malformed JSON all 400 with no row and no stack trace; GET/PUT/
  PATCH/DELETE on `/devices/{B's id}` are 404/405 with B's row unchanged; schema
  refuses NULL and dangling `user_id` on insert and update; deleting a user cascades
  only their devices.
- Mutation checks: dropping `AND user_id = :userId` from the update fails 3 tests;
  dropping the `displayName` pattern fails the lone-surrogate case. Both restored
  byte-identical.

Security review (device surface): authentication, BOLA, ownership transfer,
cross-user mutation, mass assignment, query scoping, DTO binding and error leakage
checked against the code and the tests above. One confirmed defect, fixed: a JSON
`\ud800` in `displayName` was accepted (201) and stored as `?` by the driver; now
400. NUL and other controls were already 400 (Jackson) and are now also rejected
by the DTO constraint.

Decisions made:
- D16 (above). No other decision changed. Deviation from the section 10 layout
  sketch: no `Device` JPA entity or separate service; `Devices` owns the SQL, as
  `AuthSessions` does.

Remaining:
- Step 4 `PUT /api/v1/sync/usage-days`: settle D13 (total rows per request) first;
  it is the first route to exercise D16's `404` (upload to a foreign `deviceId`).
- `TestEndpoints` stays; its `/boom` route backs the generic-500 test.

Risks / unresolved questions:
1. No cap on devices per account, and no rate limit on authenticated endpoints: an
   account can create device rows at request rate (API4). Not in any decision yet;
   candidate for a small per-account cap alongside D13.
2. The 409 confirms that a given UUID is registered somewhere (D12, accepted): only
   meaningful to someone who already holds that 122-bit value.
3. `displayName` may contain Unicode format characters (for example bidi controls);
   it is only ever returned to its owner.

Relevant commit:
- The `feat(server): add authenticated device management` commit that carries this
  entry. Previous checkpoint: `ca25d2f` (Flutter trend fix), `2a971d1` (backend).

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
4. Rate-limit state is in-process: single-instance limiter assumption (D15).
   Session and refresh-token state are persisted in PostgreSQL (clarified 2026-09-19).
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
