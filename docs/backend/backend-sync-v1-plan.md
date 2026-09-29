# Backend Sync v1 - Stage Plan

Stage: FocusTrace optional cloud synchronization, first vertical slice.
Branch: `feature/backend-sync-v1`.
Companion documents: `backend-sync-architecture.md` (decisions), `backend-sync-v1-progress.md` (state).

This document owns scope, sequence, and acceptance criteria. It does not restate
architecture; the architecture document owns the data model, API contract, and
synchronization semantics.

---

## 1. Scope

Prove one thing end to end: a FocusTrace installation can push its local daily
usage history to a Spring Boot service backed by PostgreSQL, repeatedly and
safely, and a second installation on the same account can read it back.

Fixed technology (do not revisit): Java 21, Spring Boot, Spring Web, Spring Data
JPA, Spring Security, Bean Validation, PostgreSQL, Flyway, Gradle Kotlin DSL,
JUnit 5, Testcontainers. Backend lives under `server/`.

### In scope

- User registration and login.
- Device registration using an app-generated installation UUID.
- Idempotent upload of complete daily usage snapshots.
- Server-side validation and transactional persistence.
- Authenticated retrieval of synchronized history, per device.
- PostgreSQL-backed integration tests.
- A Flutter sync client layered behind a repository (Phase 2).

### Non-goals for this stage

Blocking rules, restriction state, realtime usage, app settings, cloud
enforcement, cross-device restriction sync, full backup/restore, interval sync,
change feeds or cursors, WebSockets, Kafka, Redis, Kubernetes, microservices,
analytics dashboards, remote configuration.

### Product invariant

Local tracking, local persistence, restriction enforcement, blocking, scheduled
restrictions, and normal UI must keep working with the backend unreachable,
misconfigured, or switched off. Sync is opt-in and off the critical path.

---

## 2. Implementation sequence

Each step ends with the previous steps still passing.

**Phase 1 - backend vertical slice**

1. Bootstrap `server/` as a standalone Gradle Kotlin DSL build. Spring Boot
   starts, Flyway `V1__baseline.sql` creates the schema, `ddl-auto=validate`.
2. `users` + registration/login. Argon2id hashing, JWT access token, rotating
   hashed refresh token. `SecurityFilterChain` stateless; protected routes 401
   without a valid token.
   Read `docs/security/backend-security-baseline.md` first. Step 2 must satisfy
   its sections 5 to 7 and 13 and carry the Step 2 tests in its section 18.
   The security decisions it depends on are resolved in
   `backend-sync-architecture.md` section 5.1 (D01-D11, D14, D15) - implement
   those decisions, do not re-decide them.
   Step 2 also covers, per those decisions: the `V2` migration sketched in
   architecture 6.1 (`auth_sessions`, `refresh_tokens.session_id`, the
   `users_email_canonical` check), `POST /api/v1/auth/logout`, per-source /
   per-account rate limiting on register, login and refresh, and the local
   common-password blocklist resource (D17). Bouncy Castle is the one new
   dependency, required by `Argon2PasswordEncoder`; the blocklist is a tracked
   resource file, not a dependency, and involves no runtime network access.
3. `devices`. `POST /api/v1/devices` idempotent on installation UUID,
   `GET /api/v1/devices` scoped to the caller.
4. `usage_days` + `usage_day_apps`. `PUT /api/v1/sync/usage-days` with Bean
   Validation, one transaction per request, guarded upsert on
   `(device_id, local_date)` keyed by `snapshot_version`.
5. `GET /api/v1/usage?from=&to=` returning per-device days.
6. Testcontainers integration suite covering section 3.

**Phase 2 - multi-device proof**

7. Register Device B under the same account.
8. Device B retrieves Device A's history with source device identity intact.
9. Flutter sync client: installation UUID in `settings`, watermark upload
   selection, `domain -> sync repository -> remote data source` layering, no HTTP
   in widgets or view models.
10. Persist remote history locally where appropriate; re-run sync; prove nothing
    duplicates.

Flutter work does not begin until the API contract is stable and Phase 1 tests
pass.

---

## 3. Acceptance criteria

Phase 1 is done when all of these are proven by tests that actually run against
PostgreSQL via Testcontainers:

| # | Criterion |
| --- | --- |
| 1 | Spring Boot starts and Flyway creates the schema; context loads with `ddl-auto=validate`. |
| 2 | A user registers and logs in; a wrong password is rejected. |
| 3 | A request to a protected route without a valid access token is 401. |
| 4 | A refresh token rotates on use; a reused refresh token revokes the chain. |
| 5 | A device registers; re-registering the same installation UUID updates rather than duplicates; a UUID owned by another user is 409. |
| 6 | A valid day snapshot is accepted and persisted. |
| 7 | Invalid data is rejected with 400 and writes nothing: negative duration, duration above 90000, duplicate `appKey` within a day, unresolvable `timezoneId`, empty `days`, and every other architecture 9.1 bound. |
| 8 | Uploading the same snapshot twice leaves server state identical to uploading it once; the second response outcome is `DUPLICATE`. |
| 9 | Uploading version 2 after version 1 replaces the day wholesale: only version 2's app rows exist, no accumulation, outcome `APPLIED`. |
| 10 | Uploading version 1 after version 2 leaves version 2 intact, outcome `STALE`. |
| 11 | Devices A and B on the same user, same date, remain two independent rows, each labelled with its source device in the history response. |
| 12 | A batch whose last day violates a constraint leaves zero rows from that batch. |
| 13 | User A cannot read, rename, delete, or upload usage for User B's device, and cannot read User B's usage. Every verb is rejected with no side effect. |
| 14 | A tampered, expired, unsigned or unexpectedly-signed access token is rejected; an arbitrary identity claim grants nothing. |
| 15 | The stored password is not the plaintext and verifies through the configured Argon2id encoder; no response or log contains a password or hash. |
| 16 | No `refresh_tokens` row holds a plaintext token; rotation invalidates the consumed token; replaying it revokes that session and leaves the user's other session working. |
| 16a | Logout revokes only the presented session and is idempotent. |
| 16b | Registration, login and refresh return 429 once their configured limit is exceeded, and one account's exhausted budget does not lock out another from the same source. |
| 16c | `"user@example.com"`, `"User@Example.com"` and `" user@example.com "` cannot create separate identities, and all three log in to the same account; `"\tuser@example.com"` is rejected as invalid input rather than canonicalised. |
| 16d | Two concurrent refresh requests carrying the same valid token produce exactly one successful rotation, no 5xx, one successor, and the within-grace loser does not invalidate that successor. |
| 16e | A blocklisted common password is rejected at registration, and the same password in decomposed and precomposed Unicode form authenticates the same account. |
| 17 | The context fails to start with a missing or too-short JWT signing secret. |
| 18 | Malformed requests and forced internal failures return the common error model with no stack trace or internal detail. |

Phase 2 is done when Device B reads Device A's history through the real API, the
Flutter client re-runs sync, and criterion 8 still holds end to end.

---

## 4. Verification commands

```bash
# backend
cd server && ./gradlew test          # unit + Testcontainers integration
cd server && ./gradlew build

# flutter (Phase 2 only)
flutter analyze
flutter test
```

Testcontainers requires a running Docker daemon. If Docker is unavailable, the
integration suite is **blocked**, not passing - report it as such.

---

## 5. Remaining work

Phase 1 is complete. Bootstrap, authentication (criteria 2-4, 14-18, 16a-16e),
devices (criterion 5; D16 resolved), usage upload (criteria 6-10 and 12; D13
resolved) and the history read (criteria 11 and 13 now closed on both halves),
every one proven by `server/` tests executed against PostgreSQL via Testcontainers.
See `backend-sync-v1-progress.md` for current state.

Phase 2 is complete as a vertical slice. The version policy for versionless days
and the watermark/import interaction are resolved (architecture 7.2, 8.2, risk
3); the client is layered `domain -> sync repository -> remote data source` with
no HTTP above the repository (architecture 8.4); client pre-validation and
deterministic sanitization are implemented (architecture 9.1); and Device B
reading Device A's history through the real API is proven by
`test/sync_end_to_end_test.dart` against the running backend and PostgreSQL.

Remaining for Sync v1 correctness, none of it blocking the slice:

- Phase 5 reads `Build.MODEL` for cosmetic `display_name`; installation identity
  remains a random UUID. User editing is not implemented in this slice.
- ~~**Decision needed: `minSdk` 21 or 23.**~~ Resolved: `minSdk` is 23. The
  refresh token is persisted in `AndroidKeyStore`-sealed storage through
  `SyncCredentialStore`, so a restart no longer forces a new sign-in. Android
  5.0/5.1 are dropped; nothing else in FocusTrace required API 21.
- Phase 4 supplies sign-in, opt-in and manual sync. Phase 5 adds six-hour unique
  WorkManager execution through the existing repository and process gate.
  The startup/completion lifecycle blocker is closed with bounded pre-admission
  startup and post-release cleanup, preserving safe protected-operation drain.
  Headless execution against the real backend was verified on an SM-A366B on
  2026-09-29 (progress entry of that date), including a cold process started
  only for the job.
- Windows days are out of scope. Every Windows day is Dart-written with no
  snapshot row and the current day mutates within the day, which the single
  imported-version stamp cannot express (architecture 7.2). The Windows shell is
  on a parked branch.
- A versionless day that holds no app rows is never offered, because the
  versionless selection is driven by `daily_app_usage`.

Before public release (backend):

- ~~Active-device quota~~, ~~persistent-storage bound~~ and ~~authenticated
  per-user limits for upload and history~~: resolved 2026-09-24 as architecture
  5.1, D18. Accepted when: at most 10 devices per account are ever active - a new
  device or a reactivated inactive one past the quota is `403` with no write, while
  re-registering an active device stays `200` and a foreign UUID stays `409`; a request that would
  take an account past its stored-day budget is `403` and changes nothing, while
  replace/duplicate/stale/conflict are unaffected; both quotas admit exactly one
  of several requests racing for the last slot; upload, history and device
  registration return `429` past their per-account limit with no write and no
  effect on another account. All proven against PostgreSQL (`DeviceQuotaIT`,
  `StorageBudgetIT`, `PerUserRateLimitIT`).
- Device lifecycle beyond D18: explicit retirement or deletion. D18 frees a slot
  after 90 days of inactivity, but device rows and their history are never
  removed. A hard delete cascades the device's synced history and must take the
  D18 account lock.
- Session and refresh-token retention: every login adds an `auth_sessions` row and
  every refresh a `refresh_tokens` row, never reclaimed (review brief, 2026-09-19).
- ~~A page bound for the worst-case history response~~: resolved 2026-09-26 as a
  hard bound of 20,000 result rows (architecture 9.3); with the
  `refresh_tokens(session_id)` index (V4, architecture 6.3). Accepted when a read
  at the bound succeeds, one row past it is `400` with nothing truncated, rows
  spread over devices cannot escape it, the device filter and D16 behaviour are
  unchanged, and the index exists beside V2's partial one (`HistoryBoundIT`,
  `FlywayBaselineIT`). The residual full-range sort was removed by ordering
  candidate days before fetching apps (architecture 9.3, 2026-09-26).
- The Sync v1 client restarts a failed run from its first batch, so an upload
  larger than the 300-request burst could never finish. The limit is sized above
  realistic full uploads; advancing the watermark per accepted batch would remove
  the coupling (client change, not done).
- ~~Trusted-proxy client address~~: resolved 2026-09-26 (architecture 5.1, D20).
  Accepted when source buckets separate clients behind the configured proxy,
  forwarded headers from any other peer change nothing, and every invalid network
  configuration fails startup.
- The staging/production deployment itself: proxy product and host, TLS
  certificates, private-only application port, volumetric limits at the proxy,
  PostgreSQL backups and their retention, log persistence.
- D18's buckets are in-process: one instance only.
- ~~Installation identity copied by Android backup or device transfer~~:
  resolved 2026-09-26 (architecture section 3). Accepted when a restored copy of
  the database gets its own identity and loses the copied opt-in while keeping
  local history and the watermark, restart and update keep the identity, a signed-in
  pre-marker installation keeps its identity, marker failures fail the operation,
  and both rule files exclude the marker and the credential in every section
  (`sync_repository_test.dart`, `SyncInstallationMarkerTest`). A real restore and
  device transfer on hardware is still outstanding.
- ~~Upload progress inherited across accounts~~: resolved 2026-09-26
  (architecture 8.2). Signing out of one account and into another, or a restored
  copy signing into another account, uploaded none of the earlier history.
  Accepted when another account receives the whole local history, the same account
  re-sends nothing, legacy progress without an owner is discarded once, and an
  interrupted switch completes on retry (`sync_repository_test.dart`, real-backend
  E2E).
- ~~Account switch on one installation fails permanently~~: resolved 2026-09-29
  (architecture section 3). Found on a physical device: the installation's id
  belonged to the first account, so every registration for the second was `409`
  and sync failed with no recovery; the unit fake had not enforced device
  ownership. Accepted when the second account's run binds a new id, uploads the
  whole local history under it, and leaves the first account's device untouched
  (`sync_repository_test.dart` with an ownership-enforcing fake; SM-A366B against
  the real backend). Known cost: switching back duplicates history across the
  first account's two devices.

## 6. Release blockers outside the backend

These are not backend tasks but must be resolved before sync ships to users:

- `README.md:102` and `docs/privacy.html` currently state that FocusTrace never
  sends tracked data to a server. Both become inaccurate the moment sync ships.
- ~~Account deletion must be reachable from the UI.~~ Resolved 2026-09-24
  (architecture 5.1, D19): "Delete account" in the sync card, confirmed with the
  current password; the server deletes the whole account graph; local usage
  history is kept. Accepted when the server graph is empty after deletion, old
  access and refresh tokens are dead, deletion races with upload, registration
  and refresh neither deadlock nor resurrect anything, and a new account on the
  same installation uploads the full local history (`AccountDeletionIT`, Flutter
  repository/view-model/card tests, real-backend E2E). Still open around it: the
  Google Play web deletion page, and the privacy copy above.
- Email addresses are never verified. Registration therefore discloses that an
  account exists (architecture 5.1, D11). Revisit if verification is added.
- Authentication rate limiting landed in Step 2 (architecture 5.1, D15).
  Authenticated budgets for device registration, upload and history followed in
  D18 (2026-09-24); device listing is deliberately unthrottled. Deployment
  controls still require verification before public release; see the dated
  `backend-sync-v1-review-brief.md` for the 2026-09-19 assessment.
