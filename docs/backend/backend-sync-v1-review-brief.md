# Backend Sync v1 — readiness and next-step review brief

Prepared: 2026-09-19 by Codex. Reviewed branch: `feature/backend-sync-v1`.
Code checkpoint: `d2b7271a87f91f947c4445673dd18859348aee95`.

## Purpose and conclusion

This is a dated briefing for ChatGPT to review the recent backend work and
recommend the next implementation steps. It is not a second architecture or a
security certification. The canonical plan, architecture and progress documents
remain authoritative; recommendations below are not adopted decisions.

**The server is ready to continue backend development, subject to resolving the
Step 4 contract questions. It is not a complete sync server and is not ready for
public production use.** Bootstrap, authentication and device registration exist.
Usage upload, history retrieval and the Flutter sync client do not. Existing
security controls are substantial, but resource-consumption gaps remain.

The inspection found no demonstrated cross-account access or authentication bypass.
That is a limited finding from source and test inspection, not proof that none
exists. Confirmed missing controls and untested concerns are separated below.

## Essential project context

- FocusTrace is a local-first wellbeing app: Flutter UI, Android/Kotlin usage
  tracking and blocking, local SQLite. Tracking, enforcement, restrictions and
  normal UI must work with no account and with the server disabled or unavailable.
- Cloud sync is optional. This stage copies normalized per-app daily totals,
  preserving source-device identity. It does not synchronize restrictions,
  settings, intervals, raw UsageEvents, window titles or session-level traces.
- Fixed stack: Java 21, Spring Boot, PostgreSQL, Flyway, Spring Security,
  Gradle Kotlin DSL, JUnit and Testcontainers. No stack redesign is requested.
- `server/` is independent of the Android build. Pins in the build are Spring
  Boot 4.1.0, Gradle 9.5.1, Testcontainers 2.0.5 and Bouncy Castle 1.86.
  These are repository facts, not a statement that the versions are vulnerability-free.
- Phase 1 proves the server API against PostgreSQL. Phase 2 proves Device B can
  read Device A's history through a real Flutter sync integration. Flutter sync
  work starts only after the API is stable and Phase 1 acceptance tests pass.

## What changed recently

| Commit | Change | Relevance |
| --- | --- | --- |
| `a2ba175` | Server bootstrap and V1 schema | Standalone service; usage tables already exist, but their endpoints do not. |
| `ed7f182` | Authentication and sessions | Register/login/refresh/logout, V2 session schema, validation, rate limits and security tests. |
| `2a971d1` | Step 2 documentation checkpoint | Records the authentication implementation commit. |
| `ca25d2f` | Flutter usage-trend comparison fix | Intervening app work; not a backend capability. |
| `d2b7271` | Authenticated device management | Latest backend change; resolves D16 and completes Step 3. |

### Implemented surface

| Endpoint | Current behavior |
| --- | --- |
| `POST /api/v1/auth/register` | Creates account, 201; canonical email uniqueness, duplicate 409, password admission checks. |
| `POST /api/v1/auth/login` | Returns access and refresh tokens; generic 401 for invalid credentials. |
| `POST /api/v1/auth/refresh` | Rotates a hashed refresh token transactionally; replay policy is session-scoped. |
| `POST /api/v1/auth/logout` | Requires bearer authentication; revokes the caller's session identified by the supplied refresh token; idempotent 204. |
| `POST /api/v1/devices` | New installation UUID: 201; same owner: update name/last-seen, 200; foreign owner: 409 without changing ownership. |
| `GET /api/v1/devices` | Lists only the caller's devices. |

There are no implemented usage upload/read, account deletion, password reset,
password change, or standalone device deletion endpoints. Device rename currently
occurs through re-registration. Tests rejecting unused device verbs do not prove
authorization for future implementations of those verbs.

### Security controls actually present

- Argon2id (`m=19456,t=2,p=1`), NFC processing, registration bounds of 15–128
  Unicode code points and a bundled common-password list. The list controls new
  passwords only; login does not retroactively reject an existing password.
- HS256 access JWTs with issuer/audience checks, fixed verification algorithm,
  required expiry, UUID subject resolving to an existing account, and `jti`.
  Default lifetime is 15 minutes. Signing-key encoding/length is checked at startup;
  key randomness remains an operational responsibility.
- Random 256-bit refresh tokens stored only as SHA-256 hashes. PostgreSQL stores
  sessions and token history; rotation uses a conditional update and a unique
  index preventing two unrevoked tokens in a session. Defaults: 30-day inactivity,
  90-day absolute session lifetime, 10-second reuse grace.
- Public access is allowed only for POST register/login/refresh. Other routes
  require bearer authentication. No cookie session, form login or HTTP Basic.
- Separate source/account login limits; source limits for registration/refresh.
  Counters are bounded, in-memory and local to one process.
- Device ownership is derived from the principal and included in SQL predicates.
  Requests use DTOs; unknown properties are rejected. Values are bound in SQL.
- Flyway V1/V2, foreign keys, cascading deletion and uniqueness constraints;
  Hibernate uses `ddl-auto=validate`. Device/session persistence uses JdbcClient,
  so Hibernate validation alone does not validate every JDBC-managed table.
- Generic API errors, request correlation IDs, credential-redacted records,
  explicit production configuration checks, and tests for credential leakage.

The latest device change also rejects control characters and unpaired UTF-16
surrogates in display names. It fixes a previously discovered case where the JDBC
driver stored a lone surrogate as `?`.

## Readiness by milestone

| Milestone | Assessment |
| --- | --- |
| Phase 1 Steps 1–3: bootstrap/auth/devices | Implemented; historical PostgreSQL test evidence exists. Fresh verification blocked in this review. |
| Step 4: usage upload | Not implemented. D13 is explicitly unresolved. |
| Step 5: history retrieval | Not implemented. Output bounds and filtered foreign-device behavior need precise handling. |
| Phase 1 complete | No: acceptance criteria 6–12 and usage portions of criterion 13 remain open. |
| Phase 2 / real multi-device sync | Not ready; no client integration or end-to-end proof. |
| Public deployment | Not established: missing resource controls and release/operational evidence described below. |

## Problems and security gaps

Priority describes when to address a finding, not a CVSS score. No exploit/load
test or live deployment inspection was performed.

| Finding and evidence | Impact and recommended disposition |
| --- | --- |
| **Confirmed: no device quota or authenticated device throttling.** `device/Devices.java` inserts every new UUID and returns an unpaged list; `AuthRateLimiter` covers auth flows only. | One authenticated account can grow storage and device-list responses continuously. Before public exposure, set a per-account device cap and request limits. Enforce any cap safely under concurrent registration; keep re-registration possible at the cap. |
| **Confirmed: no explicit total JSON body cap found in server code/config.** DTO validation and auth throttling run after body parsing. No tracked reverse-proxy limit was found. | Large requests can consume parsing resources before those controls apply. Establish an actual byte cap, including requests without Content-Length, and verify safe rejection before controller work. This affects existing public auth routes, not just future uploads. Framework parser constraints are not evidence of the required total-body cap. |
| **Open design gap: D13.** Proposed limits permit 400 days × 2,000 apps = 800,000 app rows in one request. | Resolve total app rows and body bytes before Step 4. Select values using expected history size and measured memory/transaction cost; test boundaries and zero writes on rejection. No upload route exists yet, so this is not an exposed upload vulnerability today. |
| **Open read-amplification gap.** Planned history range is 400 days, across all devices; no result-row/page budget is defined. | A date bound alone does not bound devices × days × apps. Define a response budget and pagination or another explicit bounded contract before Step 5. Do not silently truncate history. |
| **Confirmed limiter limitations.** Full socket address keys, process-local state, LRU eviction of entries at capacity. | Restart resets budgets; replicas multiply them; many IPv6 addresses can create independent source buckets. Key churn can evict active budgets. These are limitations inferred from the implementation, not demonstrated attacks in this review. Test saturation behavior and define trusted-proxy/IPv6 handling with deployment. |
| **Confirmed: session/token records have no cleanup mechanism in the inspected main sources.** Every login creates a session; every refresh adds a retained token row. | Expiration prevents use but does not reclaim storage. Define retention and bounded cleanup before sustained use. Preserve token evidence needed for replay detection while a session can still be used. |
| **Confirmed: no server job in tracked CI.** `.github/workflows/ci.yml` runs Flutter and Android only. | Backend regressions are not covered by that pipeline. Add Java 21 + server Gradle tests/build with Docker/PostgreSQL Testcontainers and retain results; skipped integration tests must not count as acceptance. |
| **Deployment controls are requirements, not demonstrated infrastructure.** No tracked server deployment/proxy setup was found. | Verify HTTPS-only ingress, inaccessible direct service/DB ports, prod profile, secrets, least-privilege DB access, backups/restore, logging access and operational limits before release. An external setup may exist; this review cannot establish it. |

No dependency advisory scan or current CVE verification was performed. Do not
interpret pinned versions, tests, or this briefing as supply-chain clearance.

### Accepted trade-offs, not newly discovered defects

- Duplicate registration reveals account existence (D11); email ownership is not
  verified. Login still uses a generic failure and dummy password verification.
- Registration of someone else's installation UUID returns 409 (D12). D16's
  normal rule for a private foreign/missing object is generic 404. The exception
  reveals UUID existence but does not grant ownership.
- Logout/replay revokes refresh capability; already-issued access JWTs remain
  usable until expiry, normally up to 15 minutes. The tests explicitly expect it.
- The 10-second refresh grace avoids revoking a session on a concurrent duplicate.
  It also has an accepted stolen-token race trade-off. A lost successful refresh
  response requires sign-in again; grace does not recover the successor token.
- Email verification, MFA and recovery flows are not Phase 1 requirements. Their
  absence should inform a public-product decision, not trigger an unrelated rewrite.

## Sync questions to settle before freezing the client contract

The following are design concerns derived from the planned protocol and inspected
local writers. They are not defects in an implemented sync endpoint.

1. **Version 1 for all imported/legacy days cannot represent later edits.** The
   contract treats equal versions as duplicates and lower versions as stale.
   Re-importing changed content with version 1 therefore cannot replace version 1,
   and cannot replace a previously uploaded OS snapshot. Resetting an upload
   watermark only resends it; it does not solve server version ordering. Decide
   whether this limitation is acceptable or what version policy handles it.
2. **Wall-clock versions are not strictly monotonic.** Kotlin stores
   `window.nowMs` as `queried_at_ms`. Clock rollback can strand a newer snapshot;
   two differing snapshots with the same value are also duplicates by contract.
   Preserve the accepted limitation or resolve it deliberately, with tests.
3. **Installation identity must stay installation-local.** Portable export
   currently includes settings except `usage_recovery_generation`, and import
   restores allowed settings. Once sync IDs/watermarks are added there, explicitly
   exclude or regenerate them on restore to another installation. Otherwise a
   restored backup can copy device identity or upload state. No sync keys exist
   in that local data source yet; this is a Phase 2 integration requirement.
4. **Unavailable, empty and duplicate dates need explicit semantics.** Local
   status includes `unavailable`; server V1 allows only partial/reconciled/imported.
   Define skipping unavailable measurements, legitimate empty snapshots, and
   rejection or handling of two entries for one date in a request. Avoid replacing
   valid history with an empty failed measurement.
5. **Concurrency must preserve whole-day replacement.** Test competing versions
   for one day, equal-version concurrent uploads and overlapping multi-day batches
   in reversed order. Use consistent locking/write order or defined retry handling
   to avoid deadlocks becoming unexpected 500s. No partial app sets may survive.
6. **History authorization must distinguish listing from explicit targeting.**
   An unfiltered list omits other users' data; an explicitly foreign `deviceId`
   should follow D16's generic 404. Architecture section 12's broad “empty result”
   wording should be clarified before implementing filtered retrieval.

Also specify bounded app-name/key lengths and Unicode handling, numeric limits,
and date-boundary tests. The existing schema caps each app at 86,400 seconds;
check intended behavior on a 25-hour DST day before changing that established cap.

## Recommended next sequence

1. **Restore reproducible verification and settle a small decision set.** Run the
   existing server suite, add backend CI, resolve D13, body bytes and authenticated
   request/device limits. Resolve imported-day version semantics before declaring
   the upload contract final. Record decisions in the canonical architecture.
2. **Implement Step 4 only:** owner-scoped device resolution, validated bounded
   upload DTOs, guarded upsert, transactional whole-day app replacement and
   APPLIED/DUPLICATE/STALE results. Include no-side-effect BOLA, rollback,
   replacement, stale/equal version and concurrency tests against PostgreSQL.
3. **Implement Step 5 and finish Phase 1:** bounded authenticated history reads,
   inclusive `from`/exclusive `to`, source-device labels, explicit foreign-device
   behavior and the full acceptance suite. Prove same-date devices stay separate.
4. **Then build Phase 2:** secure credential storage, serialized refresh attempts,
   installation-local identity, account-scoped upload bookkeeping, retry-safe
   watermarks, remote/local history separation and actual Device A → Device B proof.
   Test network failure, import/clear, account switching and offline enforcement.
5. **Before public release:** finish deployment controls, token retention,
   account deletion API and UI, privacy/README changes and production verification.
   Database cascades support deletion but are not a user-accessible deletion flow.

Do not pull restrictions sync, realtime events, Redis, microservices or a new auth
framework into these steps without a demonstrated requirement.

## Verification and review limits

- **Historical PASS:** the 2026-09-18 progress entry and latest commit report 160
  tests, zero failures/skips, PostgreSQL 16.15 via Testcontainers, and a passing
  Gradle build. Test sources include real HTTP, cross-user/race cases, auth failure
  cases, DB constraints and token leakage checks. This review inspected the sources
  but did not independently reproduce that result.
- **Current BLOCKED:** on 2026-09-19, `cd server; .\gradlew.bat test --rerun-tasks`
  exited 1 downloading Gradle 9.5.1 with `java.net.SocketException: Permission
  denied: connect`. Compilation and tests never started. Docker availability was
  not established. This is an environment blocker, not a failing application test.
- To verify outside this restricted environment, with Java 21 and Docker running:
  run `cd server`, then `.\gradlew.bat test --rerun-tasks`, then
  `.\gradlew.bat build`. Record counts, skips and results in the progress document.
- No runtime code changed in this review. No live service, production database,
  penetration test, load test or dependency advisory scan was inspected/run.
- Initial tracked worktree was clean. Existing untracked `.agents/` and
  `skills-lock.json` were preserved. No commit or push was made.

## Reading guide and cautions for ChatGPT

Read this file as a snapshot at the commit above. Primary references:

- [Stage plan](backend-sync-v1-plan.md): acceptance criteria and release blockers.
- [Architecture](backend-sync-architecture.md): D01–D17 and planned sync contract.
- [Progress](backend-sync-v1-progress.md): historical verification and recent work.
- [Security baseline](../security/backend-security-baseline.md): security requirements.
- Implementation: `server/src/main/java/com/stepandemianenko/focustrace/sync/`
  (`auth`, `device`, `common`); migrations/config under `server/src/main/resources/`;
  tests under the corresponding `server/src/test/java/` tree.
- Local semantics: `lib/src/data/datasources/focus_trace_local_data_source.dart`,
  `android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageSnapshotStore.kt`.

Documentation contains historical language: the security baseline's initial
control inventory predates authentication; the architecture's class-layout sketch
is not a current file inventory; V2 is now implemented, not proposed. In the old
Step 2 progress risks, “session state is in-process” is inaccurate: session/token
state is in PostgreSQL; rate-limit state is in-process. The plan's statement that
rate limiting is no longer a release blocker refers to delivered authentication
limits, not coverage of device/sync/read traffic or deployment abuse.

Please assess: (1) which confirmed gaps should precede Step 4 versus release;
(2) concrete D13/body/device/read budgets and acceptance tests; (3) whether the
version/import semantics are sufficient; and (4) the smallest next implementation
slice. Keep recommendations within the fixed stack and local-first invariant,
and distinguish adopted decisions from proposed changes.
