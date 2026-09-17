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
| 7 | Invalid data is rejected with 400 and writes nothing: negative duration, duration above 86400, duplicate `appKey` within a day, unresolvable `timezoneId`, empty `days`. |
| 8 | Uploading the same snapshot twice leaves server state identical to uploading it once; the second response outcome is `DUPLICATE`. |
| 9 | Uploading version 2 after version 1 replaces the day wholesale: only version 2's app rows exist, no accumulation, outcome `APPLIED`. |
| 10 | Uploading version 1 after version 2 leaves version 2 intact, outcome `STALE`. |
| 11 | Devices A and B on the same user, same date, remain two independent rows, each labelled with its source device in the history response. |
| 12 | A batch whose last day violates a constraint leaves zero rows from that batch. |
| 13 | User A cannot read User B's usage and cannot upload to User B's device. |

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

Everything. As of the last progress entry, no `server/` code exists; only the
architecture design is complete. See `backend-sync-v1-progress.md` for current
state.

---

## 6. Release blockers outside the backend

These are not backend tasks but must be resolved before sync ships to users:

- `README.md:102` and `docs/privacy.html` currently state that FocusTrace never
  sends tracked data to a server. Both become inaccurate the moment sync ships.
- Account deletion must be reachable from the UI. `ON DELETE CASCADE` from
  `users` already makes the server-side deletion correct.
- `POST /auth/login` and `POST /auth/register` are unauthenticated and
  unthrottled. Acceptable for a private deployment, not for a public one.
