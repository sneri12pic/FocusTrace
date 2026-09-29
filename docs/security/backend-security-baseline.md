# FocusTrace Backend Security Baseline

Applies to the Spring Boot service under `server/` and to the Android client's
interaction with it. Written before Phase 1 Step 2 (authentication) so that
implementation and review have a fixed target.

Companion documents: `docs/backend/backend-sync-architecture.md` (decisions),
`docs/backend/backend-sync-v1-plan.md` (scope and acceptance criteria),
`docs/backend/backend-sync-v1-progress.md` (state).

**Status clarification (2026-09-20):** Phase 1 is implemented end to end.
Authentication, PostgreSQL-backed sessions, auth throttling, owner-scoped device
registration/listing, the usage upload (with its JSON document cap) and the
400-day-bounded history read all exist. Sections 2–3 and the pre-Step-2 status
language in sections 12 and 17 are historical inventories, not the current
implementation status. Security requirements remain applicable; use the progress
document for verification evidence. Auth throttling does not establish
authenticated endpoint limits: the per-user budgets required in section 11 for
`PUT /sync/usage-days` and `GET /usage` are still outstanding release work.

This document states FocusTrace requirements. It does not reproduce OWASP
material and it does not claim FocusTrace is "OWASP compliant". References used
for derivation: OWASP Top 10:2025, OWASP API Security Top 10:2023, OWASP ASVS
v5.0.0, OWASP Cheat Sheet Series. ASVS is cited at chapter level (for example
"ASVS v5.0.0 chapter V6, Authentication") rather than by individual requirement
identifier, because individual identifiers could not be verified from this
working copy. Do not invent `v5.0.0-x.x.x` identifiers to make a citation look
precise.

---

## 1. Scope

### Protected assets

| Asset | Where it lives | Why it matters |
| --- | --- | --- |
| Account credentials | `users.password_hash` | Password reuse; account takeover. |
| Session credentials | access JWT (client only), `refresh_tokens.token_hash` | Bearer access to everything below. |
| Behavioural usage history | `usage_days`, `usage_day_apps` | Per-app, per-day attention data. Sensitive by nature: it reveals routine, working hours, health and dating app use, sleep patterns. |
| Device inventory | `devices` | Links an installation UUID and a display name to an account. |
| Server secrets | JWT signing secret, database credentials | Full compromise if leaked. |

### Trust boundaries

```text
Android app process                       untrusted
        |  HTTPS, Authorization: Bearer <access JWT>
        v
[ reverse proxy / TLS termination ]       boundary 1: network edge
        |
        v
Spring Boot service                       boundary 2: authentication
        |                                 boundary 3: authorization (per object)
        v
PostgreSQL                                boundary 4: persistence
```

- **Externally reachable API boundary.** Implemented routes under `/api/v1`
  cover authentication and device registration/listing. Only POST register,
  login and refresh are public; logout and device routes require authentication.
- **Authenticated user boundary.** Established solely by a validated access JWT.
  Crossing it proves *who*, never *what may be accessed*.
- **Device ownership boundary.** `devices.user_id`. A `deviceId` in a request
  body or query string is an untrusted client-controlled identifier.
- **PostgreSQL persistence boundary.** Flyway owns the schema; constraints are
  part of the security model, not decoration.

### The client is untrusted

> The Android client is untrusted from the server's perspective.

A legitimate FocusTrace installation must not be allowed to assert ownership,
identity, authorization or server-controlled fields simply because it is the
official application. The APK is distributable, decompilable and patchable; its
network traffic can be replayed and modified. Client-side validation is a user
experience feature. Every rule that matters is enforced again on the server.

Explicitly out of scope as security controls: certificate pinning, root
detection, Play Integrity attestation, obfuscation. None is required for Phase 1
and none of them would let the server trust a client-supplied field.

---

## 2. Historical state before Step 2

Determined by inspecting `server/build.gradle.kts`,
`server/src/main/resources/application.yml`,
`server/src/main/resources/db/migration/V1__baseline.sql`,
`FocusTraceSyncApplication.java`, `FlywayBaselineIT.java` and the tracked file
list — not by assuming Spring Boot defaults.

**Enforced today**

- Flyway is the schema authority; `spring.jpa.hibernate.ddl-auto: validate` in
  the only profile that exists, proven to start cleanly by `FlywayBaselineIT`.
- `users_email_key UNIQUE (email)` — database-level identity uniqueness.
- `refresh_tokens.token_hash BYTEA NOT NULL` with
  `refresh_tokens_hash_key UNIQUE (token_hash)`, plus `expires_at` and
  `revoked_at` columns. The schema is ready for hashed, expiring, revocable
  tokens.
- `ON DELETE CASCADE` from `users` through `devices`, `usage_days`,
  `usage_day_apps` and `refresh_tokens` — account deletion removes all data.
  Exposed as `POST /api/v1/account/delete` since 2026-09-24 (D19).
- Value bounds in the database: `duration_seconds` in `[0, 86400]`,
  `launch_count >= 0`, `snapshot_version > 0`,
  `platform IN ('android','windows')`,
  `source_status IN ('partial','reconciled','imported')`.
- Composite primary keys that make duplicate upload rows impossible.
- No credentials in tracked configuration: datasource URL, username and password
  come from `FOCUSTRACE_DB_*` environment variables.
- `spring.jpa.open-in-view: false`.
- All dependency versions explicit (Spring Boot 4.1.0, Testcontainers BOM
  2.0.5); no dynamic versions, no third-party SNAPSHOTs.

**Not present today** — stated as absent, not as "Spring will handle it"

- No `spring-boot-starter-security` dependency and no `SecurityFilterChain`.
- No controllers, entities, repositories, services or DTOs of any kind.
- No exception handler, no `ProblemDetail` configuration, no error-attribute
  configuration.
- No logging configuration file; Spring Boot defaults apply.
- No Actuator, no Swagger/OpenAPI, no database console, no CORS configuration,
  no additional Spring profiles.
- No rate limiting of any kind.

**Reachability assessment.** Nothing is actively unsafe right now because
nothing is reachable: the application exposes zero HTTP endpoints. The security
risk begins with the first controller in Step 2. Two items nonetheless needed a
decision before then and have since had one: the database default fallback in
`application.yml` (D14), and application-only email normalization sitting behind
a case-sensitive unique constraint (D03). Neither is implemented; both are now
specified. See section 19.

**Status vocabulary used below**

| Status | Meaning |
| --- | --- |
| `Enforced` | Verified present in the repository today. |
| `Step 2` | Required by Phase 1 Step 2 (authentication). Not yet implemented. |
| `Later` | Required by a later backend/sync phase (devices, sync, history). |
| `N/A` | Not exposed by the current architecture. Revisit if that changes. |

---

## 3. Control status

| Control | OWASP | Status | Verification |
| --- | --- | --- | --- |
| Flyway owns schema; `ddl-auto=validate` everywhere | A02 / API8 | Enforced | integration test (`FlywayBaselineIT`) |
| Database uniqueness on account identity | A07 / API2 | Enforced | integration test |
| Case-insensitive account identity uniqueness in the database | A07 / API2 | Step 2 | integration test |
| Argon2id password hashing with explicit parameters | A07 / API2 | Step 2 | integration test + database assertion |
| Plaintext password never stored or logged | A04 / A09 | Step 2 | database assertion + code review |
| Generic authentication failure responses | A07 / API2 | Step 2 | integration test |
| Stateless explicit `SecurityFilterChain`, deny by default | A01 / API5 | Step 2 | integration test + configuration test |
| Public endpoints explicitly allow-listed | A01 / API5 | Step 2 | integration test |
| JWT signature, algorithm, `exp`, `iss`, `aud`, `sub` validated | A07 / API2 | Step 2 | integration test |
| Algorithm-confusion and unsigned tokens rejected | A04 / API2 | Step 2 | integration test |
| Signing secret required at startup, never committed | A04 / A02 | Step 2 | configuration test + code review |
| Refresh token opaque, high-entropy, hashed at rest | A04 / API2 | Step 2 | integration test + database assertion |
| Refresh token rotation with replay detection | A07 / API2 | Step 2 | integration test |
| Consistent `ProblemDetail` error model, no internals leaked | A10 | Step 2 | integration test |
| Bean Validation on every request DTO | A05 / API4 | Step 2 | integration test |
| No JPA entity exposed through REST | A01 / API3 | Step 2 | code review |
| Server-controlled fields not writable through DTOs | A01 / API3 | Step 2 | integration test |
| Security event logging without credentials | A09 | Step 2 | code review + log assertion |
| Authentication rate limiting, per source and per account | API4 / API6 | Step 2 | integration test |
| Device ownership checked against authenticated principal | A01 / API1 | Later | integration test |
| Usage operations scoped by the owning device | A01 / API1 | Later | integration test |
| Documented sync bounds enforced server-side | API4 | Later | integration test |
| Request body size limit | API4 | Later | integration test or proxy configuration |
| Parameterized data access only | A05 | Later | code review |
| TLS in production | A04 | Later | deployment review |

---

## 4. Access control

Mandatory rules. They apply to every endpoint, without exception.

1. **Authorization is enforced server-side.** Never by the app, never by hiding
   a screen.
2. **Authentication and authorization are separate concerns.** A validated
   access JWT answers "who is calling". It never answers "may this caller touch
   this object".
3. **A valid JWT does not grant access to every resource.** Possession of a
   token for user A grants exactly user A's objects.
4. **Never trust client-provided ownership information.** `userId`, `ownerId`,
   `deviceOwner`, `accountId` and anything equivalent must not appear as accepted
   request fields. If such a field arrives, it is ignored or the request is
   rejected — never used.
5. **Derive the current user from the authenticated server-side principal**, and
   from nothing else.
6. **Device operations verify ownership.** `deviceId` is client-controlled input.
7. **Usage-data operations verify ownership of the corresponding device**, on
   every request, including repeated and batched ones.
8. **Server-controlled fields cannot be overwritten through request DTOs**:
   `users.id`, `devices.user_id`, `devices.registered_at`,
   `usage_days.received_at`, every `refresh_tokens` column, and any future role
   or entitlement field.
9. **Deny by default.** A new endpoint is authenticated unless it is added to the
   explicit public allow-list.
10. **Resource-level authorization happens every time** an object is reached
    through a client-controlled identifier — not once at the start of a batch.

### How FocusTrace implements rule 10

The architecture (section 5.2) already chose the right mechanism: ownership is a
predicate inside the query, not a check performed after loading.

```sql
... FROM usage_days d JOIN devices dev ON dev.id = d.device_id
WHERE dev.user_id = :userId
```

This is a requirement, not a style preference. A forgotten check in a
load-then-compare design returns another user's row; a forgotten join in this
design returns nothing. Writes follow the same rule: resolve the device by
`(deviceId, authenticatedUserId)` and fail if that resolution returns nothing.

### Unauthorized access to another user's object

**Policy: non-revealing `404`** for reads, writes and deletes targeting an
object the caller does not own. The caller learns nothing about whether the
identifier exists. This matches the architecture's existing choice for uploads
to a foreign device id and is now the general rule.

**One documented exception:** `POST /api/v1/devices` returns `409` when the
installation UUID is already registered to another account, because the client
must be able to distinguish "your device, updated" from "this UUID is taken" in
order to regenerate its installation UUID. See section 19, decision D12, for the
disclosure this accepts and why it is bounded.

`403` is reserved for a caller who is authenticated, whose identity is correct,
and whose request is forbidden for a reason unrelated to object ownership.
FocusTrace has no such case today.

### OWASP mapping

- **A01:2025 / API1:2023 (BOLA).** The primary risk in this system. Every sync
  and history endpoint takes a client-supplied `deviceId`. Mitigation:
  query-level user scoping, `404` on miss, BOLA integration tests in the sync
  phase.
- **API3:2023 (Broken Object Property Level Authorization).** Request DTOs are
  separate record types listing only writable fields; ownership, timestamps and
  version fields are set by the server. Response DTOs list only fields the client
  needs — `password_hash` has no field in any response type.
- **API5:2023 (Broken Function Level Authorization).** FocusTrace has one role
  today, so this reduces to "no endpoint is reachable unauthenticated unless it
  is on the allow-list". If an administrative or support function is ever added,
  it needs its own authorization decision before its first line of code.

### Required authorization test

User A owns Device A. User B is fully authenticated as themselves. User B
attempts to read Device A, rename Device A, delete Device A, upload usage for
Device A, and read usage filtered by Device A. Every one of those is rejected,
and no row belonging to User A is created, modified or returned.

---

## 5. Authentication

Relevant ASVS v5.0.0 chapters: V6 (Authentication), V7 (Session Management).

### Passwords

- Argon2id, through Spring Security's `PasswordEncoder` abstraction. No custom
  cryptography, no hand-rolled salting, no MD5/SHA family for passwords.
- Plaintext is never stored, never written to a log, never returned in a
  response, never placed in an exception message.
- Passwords are never reversibly encrypted. There is no legitimate reason for
  the server to recover a password.
- **Argon2id parameters are configured explicitly**, not inherited from whatever
  the library version happens to default to. Chosen values and rationale go in
  decision D01. Changing them later is a deliberate, recorded change.
- Verification always goes through the configured encoder. No string comparison
  of hashes anywhere.
- A delegating encoder prefix (`{argon2}`) keeps the stored format upgradeable.
- **Implementation note:** Spring Security's `Argon2PasswordEncoder` requires
  Bouncy Castle on the classpath. Step 2 therefore adds one dependency. It is an
  established library and is justified under section 16; add the specific
  artifact, pinned, and nothing else.

Explicit input bounds, enforced by Bean Validation on the registration DTO:

- Minimum and maximum length: decision D02 (15 to 128 Unicode code points).
  The minimum is set where it is because the password is the only factor
  FocusTrace has. Argon2id has no bcrypt-style 72-byte truncation point, so the
  maximum exists to bound work, not to work around the primitive.
- The password is normalised to **Unicode NFC** and then hashed as supplied:
  not trimmed, not case-folded, not NFKC-folded, not truncated. NFC only, so that
  one typed password has one encoding across Android keyboards; nothing beyond
  that, because further folding discards entropy the user supplied. Registration
  and verification apply byte-identical processing, and length is validated after
  normalisation.
- A **local, versioned compromised-password blocklist** is checked whenever a new
  password is established - registration now, password change and reset when they
  exist - and never at login (D17). It has no retroactive effect on stored
  credentials. It requires no outbound network access, so API7 stays "not
  exposed".
- **Passwords are never silently truncated.** A password longer than the maximum
  is rejected with a validation error that states the limit.
- Email is bounded in length and validated in shape before any database work.

### Authentication responses

- Login failure returns one generic response for every cause: unknown account,
  wrong password, malformed credentials that still parse as a login attempt.
  Same status, same body, same wording.
- Where practical, avoid materially different processing behaviour between
  "unknown account" and "wrong password". The common mistake is skipping the
  Argon2id verification entirely when no user row is found, which turns a
  millisecond gap into an account oracle; perform a dummy verification against a
  fixed hash instead. Timing equality is not being guaranteed here — trivial
  enumeration is what is being removed.
- Registration duplicate behaviour is an explicit decision (D11), not an accident
  of where the unique-constraint violation happens to surface.
- **Uniqueness is guaranteed by the database constraint.** A pre-insert existence
  check is a user-experience nicety that loses races; the `users_email_key`
  violation is the authority and must be caught and translated, never allowed to
  surface as a 500.

---

## 6. Access token (JWT)

Relevant ASVS v5.0.0 chapters: V7 (Session Management), V9 (Self-contained
Tokens).

Access tokens are signed, short-lived, sent only over TLS in production, treated
as bearer credentials, and carry no secret or unnecessary personal data. The
architecture's claim set (`sub`, `iat`, `exp`, `jti`) plus `iss` and `aud` per
decision D07 is the whole payload. No email, no device list, no entitlements.

Verification must explicitly check, and reject on failure:

| Check | Rejection reason |
| --- | --- |
| Signature valid | tampered |
| Algorithm is one of the configured allow-list | algorithm confusion, `alg: none` |
| `exp` in the future | expired |
| `iss` matches the configured issuer | token minted elsewhere |
| `aud` matches the configured audience | token minted for another service |
| `sub` present and resolves to an existing account | orphaned or forged identity |
| `nbf`, if present, is in the past | not yet valid |

Hard rules:

- **The accepted algorithm is configured on the server.** The `alg` header of an
  incoming token is an attacker-controlled field and must never select the
  verification path. A token whose header requests anything outside the
  configured set is rejected before signature verification is attempted.
- Unsigned tokens are rejected unconditionally.
- No custom JWT parsing, signing or verification code. Use the maintained
  library together with Spring Security's support.
- The signing secret is supplied at runtime (`FOCUSTRACE_JWT_SECRET`) and never
  committed. Startup fails if it is absent or too short — see section 11.
- The `sub` claim identifies the user and is the only accepted source of caller
  identity. An arbitrary identity claim in a token that does not verify grants
  nothing, and that must be covered by a test.
- Access tokens are **not revocable** before expiry. That is the accepted
  consequence of statelessness, bounded by the short TTL (D04) and by refresh
  revocation. `jti` exists so a denylist could be added later without a token
  format change; no denylist is being built now.
- Key rotation: decision D09.

---

## 7. Refresh token

Refresh tokens are:

- cryptographically random with high entropy, from `SecureRandom`;
- opaque to the client — no claims, no structure to parse;
- rotated on every successful use;
- revocable;
- time-limited (D05, D06);
- stored server-side only as a cryptographic representation, never as plaintext;
- never logged, and never returned except in the authentication responses that
  exist to deliver them.

### Storage representation

A refresh token is a high-entropy random value, not a low-entropy human secret.
Password hashing primitives exist to make brute force expensive against guessable
inputs; there is nothing to guess in 256 random bits. **SHA-256 of the raw token
is the correct representation here** — it prevents a database read from yielding
usable credentials, and it is fast enough to be looked up by an indexed equality
match, which an intentionally slow salted primitive is not. Do not "upgrade" this
to Argon2id by analogy with passwords. This confirms the architecture's existing
choice (section 5.1) and the `token_hash BYTEA` plus unique-index shape already
in `V1__baseline.sql`.

### Rotation and replay

On a successful refresh, in one transaction:

1. Issue a new refresh token and return it once.
2. Mark the consumed token revoked (`revoked_at`); do not delete it — the row is
   the evidence that makes replay detectable.
3. Retain enough state to recognise a later presentation of that same token.

If an already-consumed or already-revoked token is presented, treat it as theft
or replay: reject the request, log the event (section 15), and revoke according
to the family policy in decision D08. Silent re-issue is forbidden — it converts
a detectable compromise into a permanent one.

Expiry of the presented token, absence of a matching hash, and a revoked match
all produce the same generic failure to the client. Only the server log
distinguishes them.

Absolute expiry (D05), inactivity expiry (D06), logout and password-change
revocation (D10) and the family/replay model (D08) are decided in architecture
5.1. In particular, the revocation unit is a **login session**, not the user: a
replayed token kills the session it belonged to and leaves the user's other
installations working.

---

## 8. Client-side token handling (cross-component requirement)

Not implemented in this task; stated here so the Android work has a fixed target.

Refresh tokens and any other long-lived credential on the device must be held in
OS-backed secure storage (Android Keystore-backed — for example
`EncryptedSharedPreferences` or the current equivalent mechanism), and must never
be written to:

- ordinary application logs;
- analytics events;
- crash reports;
- plaintext `SharedPreferences` or plaintext files;
- Android auto-backup or cloud backup (exclude the credential store explicitly).

The access token may be held in memory for its short lifetime.

The backend does not depend on any of this being done correctly. It assumes any
bearer token may eventually be stolen, and therefore enforces expiry, rotation,
replay detection, revocation and per-object authorization server-side. Client
storage reduces the probability of theft; it is not a server control.

---

## 9. API boundaries

Relevant ASVS v5.0.0 chapters: V2 (Validation and Business Logic), V4 (API and
Web Service).

- Explicit request DTOs and explicit response DTOs, as Java records, in the
  package owning the endpoint.
- **JPA entities are never accepted by, or returned through, a controller.**
  This is already a CLAUDE.md rule; it is also the main defence against mass
  assignment and against leaking `password_hash` or `token_hash`.
- No arbitrary property binding. Writable fields are exactly the record
  components; anything else in the JSON is either ignored or rejected, and which
  of the two is a configured, tested choice rather than a Jackson default nobody
  checked.
- Bean Validation on every request DTO, with bounded collection sizes, bounded
  string lengths and bounded numeric ranges.
- Malformed JSON, unsupported enum values and unresolvable identifiers produce a
  400 through the common error model — never a 500, never a stack trace.
- Request body size is capped. Note that Spring Boot's
  `max-http-form-post-size` does not apply to JSON bodies. Since Step 4 the cap is
  Jackson's document-length constraint,
  `spring.jackson.factory.constraints.read.max-document-length: 2097152`, which
  applies to every JSON body, including chunked ones. It is a parser bound
  enforced at buffer granularity, not an exact byte cap; a reverse-proxy limit
  remains a deployment decision.

### Sync limits

Implemented in Step 4; architecture section 9.1 is authoritative and has the full
field table:

| Bound | Value |
| --- | --- |
| JSON document | 2,097,152 input units (Jackson constraint) |
| Days per upload request | 1-31, `localDate` unique |
| Apps per day | at most 500, `appKey` unique within the day |
| App rows per request | at most 1,000 (D13) |
| `durationSeconds` | `[0, 90000]` — also a database `CHECK` (`V3`) |
| `launchCount` | non-negative — also a database `CHECK` |
| `snapshotVersion` | positive — also a database `CHECK` |
| `localDate` | `2026-01-01` to UTC today plus one |
| `timezoneId` | at most 64 UTF-16 units, resolvable by `ZoneId.of` |
| `appKey`, `appName` | non-blank, at most 255 / 200 UTF-16 units, no NUL or lone surrogates |
| History read range | at most 400 days (Step 5) |
| History response | at most 20,000 result rows (app rows, plus one per app-less day); more is `400`, never truncated (architecture 9.3) |
| Stored usage days per account | at most 3,650 across all devices; a request that would create more is `403` and writes nothing (D18) |
| Active devices per account | at most 10 seen within 90 days; a new device or a reactivated inactive one past that is `403` and writes nothing (D18) |

D13 closed the earlier gap, where 400 days times 2,000 apps allowed 800,000 app
rows in one transaction.

No unbounded, client-controlled bulk endpoint is added. The history read is
bounded by its 400-day range and, since per-device fan-out made that range
insufficient, by a hard response bound of 20,000 result rows (architecture 9.3).
The query orders the caller's candidate days first and fetches apps per day, so
the database stops at the bound instead of expanding and sorting the whole range
(measured on a budget-sized account: about 20 ms instead of 1.7-3.4 s with a
231 MB sort spill; architecture 9.3).

---

## 10. Injection

Relevant ASVS v5.0.0 chapters: V1 (Encoding and Sanitization), V2 (Validation and
Business Logic).

- All data access is parameterized: Spring Data derived queries, `@Query` with
  named parameters, or `JdbcTemplate` with bind arguments.
- No SQL assembled by concatenating untrusted strings. This includes the guarded
  upsert in architecture section 7.3 — its values are bound, not interpolated.
- Any client-controlled sort or filter key maps through an explicit server-side
  allow-list to a column name. A request value never reaches an `ORDER BY` or a
  column position directly.
- No dynamic command execution and no shell or process execution derived from
  request values. The service has no reason to invoke a process at all.
- Enum-like parameters (`platform`, `sourceStatus`, `outcome`) are parsed into
  real enums at the boundary; an unknown value is a 400. The database `CHECK`
  constraints are the second line of the same defence.
- If native SQL becomes necessary, parameters are still bound. "It is only an
  internal value" is how this control fails.

FocusTrace has no HTML rendering, no template engine, no LDAP, no XML parsing and
no expression evaluation over request data, so the remaining injection families
in A05:2025 are not currently exposed.

---

## 11. Cryptography and secrets

Relevant ASVS v5.0.0 chapters: V11 (Cryptography), V12 (Secure Communication),
V14 (Data Protection).

- No credential of any kind is committed to Git: no JWT signing secret, no
  production database password, no API key, and no test fixture that looks like a
  production secret.
- Secrets are supplied through runtime configuration (environment variables
  today). Tracked `application.yml` contains references, never values.
- **Startup fails rather than falling back to an insecure default** when a
  required secret is missing. Specifically, `FOCUSTRACE_JWT_SECRET` has no
  default in any profile, and the service refuses to start unless it is valid
  base64 decoding to at least 32 bytes (D09). The existing empty-string default
  for the database password is a local development convenience covered by
  decision D14.
- **Signing material is generated by a CSPRNG, never human-selected.** This is an
  operational requirement verified by process, not by the startup check: the
  check establishes encoding and length only and cannot establish entropy, since
  a 44-character memorable phrase drawn from the base64 alphabet decodes to 32
  bytes and passes. Do not present the format check as proof of randomness.
- Refresh tokens are never persisted in plaintext (section 7). Password hashes
  are never returned or logged.
- Production traffic is HTTPS only. TLS terminates at the reverse proxy; the
  service is not exposed directly. HTTP is not accepted in production.
- Established library facilities only: `SecureRandom`, Spring Security's
  encoders, a maintained JWT library, the JDK's `MessageDigest` for SHA-256. No
  custom password hashing, no custom token signing, no custom cipher modes.
- No hard-coded production secret, and no example value in tracked configuration
  that could be mistaken for one or copied into a deployment.

---

## 12. Resource consumption and abuse

Explicitly addresses **API4:2023 (Unrestricted Resource Consumption)** and
**API6:2023 (Unrestricted Access to Sensitive Business Flows)**.

Current state (2026-09-24): D15 throttles the anonymous flows and D18 the
authenticated device, upload and history routes. When this section was written no
endpoint existed yet. The earlier deferral to "before a public deployment" has
been withdrawn: D15 puts throttling on registration, login and refresh in Step 2,
alongside the endpoints themselves. Registration and login are the sensitive business flows here —
unthrottled login is credential stuffing, unthrottled registration is unbounded
anonymous account creation — and they are the only anonymous flows the system
has.

Required protection, per flow:

| Flow | Risk | Required control |
| --- | --- | --- |
| `POST /auth/register` | anonymous account creation, resource exhaustion | per-source rate limit |
| `POST /auth/login` | credential stuffing, password brute force | per-source **and** per-account limits |
| `POST /auth/refresh` | token brute force, rotation storm | per-source limit |
| `POST /devices` | device-row growth, write amplification | active-device quota plus an authenticated per-user limit (D18) |
| `PUT /sync/usage-days` | database work amplification, storage growth | authenticated per-user limit, the section 9 bounds and the per-account stored-day budget (D18) |
| `GET /usage` | read amplification | authenticated per-user limit plus the 400-day range cap (D18) |
| `POST /account/delete` | password guessing with a stolen access token | re-authentication with the current password, per-user limit of 5 / 15 min (D19) |

**Authenticated limits (D18, implemented 2026-09-24).** The three authenticated
rows above use the same in-process buckets as D15, keyed by the authenticated
account id taken from the verified token, never from request input or the source
address. They are charged before the request body is parsed and after
authentication, so an unauthenticated request never touches an account's budget.
Values, sizing and the single-instance limitation are in architecture 5.1, D18.
The two account quotas are enforced in the write transaction under a lock on the
account row, so concurrent requests cannot race past them, and a refused request
writes nothing.

**Throttling dimensions must be independent.** A single combined `IP + username`
bucket defeats neither attack that matters: one source trying many accounts stays
under a per-pair limit, and many sources trying one account also stay under it.
Count per source and per account identifier separately, and enforce whichever
trips first.

Behaviour when a limit is exceeded: `429 Too Many Requests` using the same
`ProblemDetail` error model, optionally with `Retry-After`. The response must not
reveal which dimension tripped or whether the targeted account exists.

Limits are configuration-backed (`@ConfigurationProperties`), so tests can set
them low and production can tune them without a code change. The chosen values
and the counter model are D15 in architecture 5.1; the values there are initial
operational defaults, not architecture. Do not bury permanent constants in the
implementation.

No rate-limiting framework and no new dependency: one instance, tiny auth
traffic, in-process token buckets in a bounded, self-expiring map (D15). A plain
fixed-window map is explicitly rejected — it permits a double-rate burst across
the window boundary, and unbounded it is itself a memory-exhaustion vector.
Volumetric abuse is the reverse proxy's job; this layer exists to stop credential
stuffing.

The source identity a bucket is keyed on comes from the transport connection.
`Forwarded` and `X-Forwarded-For` are untrusted input except, since D20
(2026-09-26), `X-Forwarded-For` from an explicitly listed reverse-proxy address in
`trusted-proxy` mode, where the rightmost entry that is not a listed proxy is the
client. From any other peer, honouring them would let an attacker both evade the
limit and evict other callers' buckets. The application port must be reachable
only from that proxy (architecture 5.1, D20).

Usage synchronization keeps bounded request size, days per request, apps per day,
duration values, retries, and database work per request. The retry path in
particular must not amplify: the upload is idempotent by construction
(architecture section 7), so a client retry storm costs the server repeated work
but never corrupted data — the rate limit is what bounds the work.

---

## 13. Security configuration

Explicitly addresses **A02:2025** and **API8:2023**. Relevant ASVS v5.0.0
chapter: V13 (Configuration).

For Step 2:

- REST authentication is **stateless**: `SessionCreationPolicy.STATELESS`, no
  `JSESSIONID`, no server-side HTTP session.
- The `SecurityFilterChain` is explicit and is the only source of HTTP
  authorization rules.
- Public endpoints are an explicit allow-list: `/api/v1/auth/register`,
  `/api/v1/auth/login`, `/api/v1/auth/refresh`. Nothing else.
- `anyRequest().authenticated()` is the terminal rule. A new endpoint is
  protected by default; making it public is a visible diff in one place.
- The JWT filter must not silently bypass a protected endpoint. Absent or invalid
  credentials leave the `SecurityContext` empty and let the chain reject the
  request with 401 — the filter never makes its own "allow" decision, and never
  swallows a verification failure into an anonymous success.
- Development conveniences do not become production defaults. Any relaxation
  lives behind a non-default profile, and the production profile is the one
  without exceptions.

Spring-specific configuration risks, assessed against what is actually present:

| Risk | Current state | Requirement |
| --- | --- | --- |
| Actuator | Not on the classpath | If added: `/actuator/health` at most; everything else authenticated. Never expose `env`, `heapdump`, `threaddump`, `loggers`, `configprops` or `mappings` publicly. |
| Swagger / OpenAPI | Not on the classpath | If added, not publicly reachable in production. |
| Database console | Not present, no H2 | Never add one. |
| Stack traces in responses | No error configuration at all | Set `server.error.include-stacktrace: never`, `include-message: never`, `include-binding-errors: never`, `include-exception: false` explicitly. Do not rely on the defaults happening to be safe. |
| Profiles | Only the default profile | Introduce `prod` with no fallback defaults for secrets when deployment begins. |
| Hibernate schema generation | `ddl-auto: validate` | Stays `validate` in every profile including tests. Flyway is the only schema authority; production never depends on Hibernate creating or altering a table. |
| CORS | Not configured | See below. |
| Debug endpoints | None | Do not add. |

### CORS

CORS is not an authentication or authorization mechanism. It constrains what a
*browser* permits a page from another origin to do; it constrains nothing about a
request from `curl`, a script, or a patched Android app.

FocusTrace's client is native Android, which is not subject to the same-origin
policy and does not need CORS at all. Therefore **CORS stays disabled** until a
browser-based client genuinely exists. If one appears, configure allowed origins
explicitly, never `*` together with credentials, and never treat the resulting
policy as protecting an API resource.

### CSRF

The chosen authentication transport is the `Authorization: Bearer <token>`
header. Credentials are attached explicitly by the client; the browser is never
the agent that attaches them ambiently. With no cookie-based authentication and
no server-side session, CSRF does not apply to these endpoints, and CSRF
protection is disabled deliberately — not because a tutorial said to.

If cookie-based authentication is ever introduced, this conclusion is void and
CSRF protection must be reassessed as part of that change.

---

## 14. Persistence and data integrity

Explicitly addresses **A08:2025**.

- Flyway owns the schema. `ddl-auto=validate` in every profile.
- A migration that has been applied outside a local scratch database is not
  edited; schema evolution is a new numbered migration. `V1__baseline.sql` has
  been committed and applied against real PostgreSQL, so the default answer for
  any change is `V2__...`.
- Security-relevant uniqueness is a database constraint, not an application
  check. Account identity and `refresh_tokens.token_hash` already are.
- Multi-table operations that must be atomic run in one transaction. The whole
  upload request is one `@Transactional` unit (architecture section 7.3).
- Conflict and version validation happens server-side: the guarded upsert
  compares `snapshot_version` in SQL, so a stale or duplicate upload is decided
  by the database, not by the client's assertion about what is newer.
- Ownership relationships are server-generated: `devices.user_id` comes from the
  authenticated principal, never from the request body.
- Server-controlled timestamps (`created_at`, `registered_at`, `received_at`,
  `issued_at`) are set by the database or the server. `last_seen_at` is server
  time, not client time.

Client input must never override resource ownership, server security state,
refresh-token revocation state, server version or conflict fields, or any
privilege or role information.

`snapshot_version` is the one client-supplied ordering value, and it is
deliberately so — it is the device's own `queried_at_ms`. It orders that device's
snapshots of its own days and confers no authority beyond that. It cannot cross a
device boundary, because the row is keyed by `(device_id, local_date)` and the
device is resolved through its owner. The known consequence — a device with a
rewound clock stalls its own updates — is architecture risk 1: a data-freshness
issue, not a security boundary issue.

A failure part-way through a transactional operation must not leave partially
applied security-sensitive state: no orphaned device, no consumed-but-not-revoked
refresh token, no user row without a password hash. The rollback is the control,
and tests assert it (plan criterion 12).

---

## 15. Logging, monitoring and exceptional conditions

Explicitly addresses **A09:2025** and **A10:2025**. Relevant ASVS v5.0.0 chapter:
V16 (Security Logging and Error Handling).

### What to log

| Event | Why |
| --- | --- |
| Authentication failure | credential stuffing, brute force |
| Authorization failure (the 404-on-foreign-object path) | BOLA probing |
| Refresh token rotation and revocation | session lifecycle |
| **Detected refresh token reuse** | strongest available theft signal |
| Rate limit enforcement | attack in progress |
| Repeated validation failures from one principal | malformed or hostile client |
| Registration of a device UUID already owned by another account | collision or probing |

Each record carries: event type, timestamp, internal user or resource UUID where
appropriate, a request or correlation identifier, and a non-sensitive outcome.

### What never appears in a log

Plaintext passwords; password hashes; JWT values, whole or partial; refresh token
values; `Authorization` header contents; secret configuration values; database
credentials; connection strings containing a password; and detailed usage data
beyond what an operator actually needs.

Two practical traps, both worth an explicit code-review check:

- **Exception objects.** An exception constructed with the offending value in its
  message leaks that value through any handler that logs the message. Never put a
  credential into an exception.
- **HTTP request logging.** Do not enable a request-logging filter that dumps
  headers. `Authorization` is a header.

### Error model

One consistent REST error model: RFC 9457 `application/problem+json` through
Spring's `ProblemDetail`, as the architecture already specifies (section 9).

Responses must not expose stack traces, SQL statements, database or driver
details, Java exception class names where they add nothing, signing keys,
configuration values, token contents, or internal implementation structure.

| Condition | Response |
| --- | --- |
| Validation failure, malformed JSON, bad enum | 400, field-level detail repeating only what the client sent |
| Missing, malformed, expired or invalid token | 401, generic |
| Object not owned by the caller | 404, generic (section 4) |
| Duplicate registration | per decision D11 |
| Rate limit exceeded | 429, generic |
| Unexpected exception | 500, generic body with a correlation id and nothing else |

An unexpected exception produces a safe generic 5xx to the client while the
server-side log keeps a full diagnostic that itself contains no credentials. The
correlation id is what ties the two together — it is the reason a user report can
be investigated without the response body carrying internals.

A transaction that fails rolls back completely before the error response is
produced.

---

## 16. Supply chain

Explicitly addresses **A03:2025** at a level proportional to this project.

The current state is good and must stay that way: every dependency has an
explicit version, versions come from the Spring Boot BOM or a pinned BOM
(`testcontainers-bom:2.0.5`), and there are no dynamic (`+`, `latest.release`) or
third-party SNAPSHOT dependencies. The `0.1.0-SNAPSHOT` project version is
FocusTrace's own artifact version, not a dependency.

Requirements:

- Explicit versions; no dynamic ranges; no third-party SNAPSHOT for anything on a
  security path.
- Dependency and security alerts are reviewed rather than dismissed.
- Security-sensitive functionality uses established libraries — Spring Security,
  Bouncy Castle, a maintained JWT library — never an obscure or hand-written
  implementation.
- Gradle wrapper changes are reviewable. `gradle-wrapper.jar` is a tracked
  binary; a change to it must be an intentional, explained wrapper upgrade, never
  an incidental diff. `gradle-wrapper.properties` currently has no
  `distributionSha256Sum`; adding one makes the distribution download verifiable
  and is a cheap improvement at the next wrapper change.
- New dependencies follow the CLAUDE.md test: does the repository already solve
  it, does the framework already provide it, and only then is it justified.
- A known-vulnerable dependency is not knowingly introduced without a written
  justification and a removal plan.
- The test container image `postgres:16-alpine` is a floating tag. Pinning it to
  a digest makes the suite reproducible — low priority while it is test-only, but
  the production PostgreSQL version must be fixed before deployment.

Future CI checks, recorded here and deliberately not built now: a dependency
vulnerability scan over the `server/` build, and dependency alerts enabled for
the repository. Neither is a supply-chain platform; both are a single job.

---

## 17. OWASP relevance to FocusTrace

Not every category is equally relevant. Controls are not built for attack
surfaces this system does not have.

### OWASP Top 10:2025

| Risk | Relevance | Note |
| --- | --- | --- |
| A01 Broken Access Control | **High, now and permanently** | Every sync and history endpoint takes a client-supplied `deviceId`. The dominant risk in this design. |
| A02 Security Misconfiguration | **High from Step 2** | The filter chain, the error attributes and the profile split are all configuration. `ddl-auto=validate` is already correct. |
| A03 Software Supply Chain Failures | Moderate | Small, explicit, BOM-managed dependency set. Maintain the discipline; Step 2 adds Bouncy Castle and a JWT library. |
| A04 Cryptographic Failures | **High from Step 2** | Password hashing, token signing, token hashing, TLS, secret handling. |
| A05 Injection | Low but non-negotiable | JPA and parameterized access throughout; no templating, no HTML, no shell. Cheap to keep at zero. |
| A06 Insecure Design | Moderate | The choices that matter — local-first, daily totals only, no window titles, no intervals, no hardware identifiers — are already made and are the strongest privacy control in the system. Preserve them. |
| A07 Authentication Failures | **High from Step 2** | The whole of sections 5 to 7. |
| A08 Software or Data Integrity Failures | Moderate | Flyway authority, guarded upsert, transactional batches, server-owned ownership fields. |
| A09 Security Logging and Alerting Failures | Moderate | Nothing is logged today because nothing runs. Refresh-token reuse detection is worthless without a log. |
| A10 Mishandling of Exceptional Conditions | Moderate | No error handling exists yet; a constraint violation surfacing as a detailed 500 is the realistic failure. |

### OWASP API Security Top 10:2023

| Risk | Relevance |
| --- | --- |
| API1 Broken Object Level Authorization | **Primary risk.** Device and usage objects are addressed by client-supplied identifiers. |
| API2 Broken Authentication | **High from Step 2.** Registration, login, JWT, refresh rotation. |
| API3 Broken Object Property Level Authorization | **High from Step 2.** Mass assignment into ownership fields; leaking `password_hash` or `token_hash` through a response. |
| API4 Unrestricted Resource Consumption | **High, partly addressed.** Upload size is bounded (JSON document, 31 days, 1,000 rows; D13). D18 adds per-user limits on device registration, upload and history, an active-device quota and a per-account stored-day budget. The history response is bounded to 20,000 rows (architecture 9.3), and the refresh-token replay check is indexed (V4). Still open: session/token row retention, and volumetric limits at the reverse proxy. |
| API5 Broken Function Level Authorization | Moderate. One role today, so it reduces to deny-by-default. Becomes real if any administrative function appears. |
| API6 Unrestricted Access to Sensitive Business Flows | **Relevant to registration and login.** Anonymous account creation and credential stuffing. |
| API7 Server Side Request Forgery | **Not exposed.** The service makes no outbound request from client-controlled input and has no URL-valued field. Revisit only if a webhook, avatar fetch or import-by-URL feature is ever proposed. |
| API8 Security Misconfiguration | **High from Step 2.** See section 13. |
| API9 Improper Inventory Management | Low now, rising later. One version prefix (`/api/v1`), one deployment, no legacy endpoints. Keep it that way: do not leave a `v0` running, and retire endpoints rather than accumulating them. |
| API10 Unsafe Consumption of APIs | **Not exposed.** FocusTrace consumes no third-party API server-side. |

---

## 18. Verification

A control that is only asserted in a document is not a control. Every important
Step 2 control names how it is proven. Integration tests run against real
PostgreSQL via Testcontainers, consistent with the existing suite.

### Registration

| Test | Method |
| --- | --- |
| Successful registration creates exactly one account | integration |
| Duplicate registration behaves per D11 | integration |
| Database uniqueness prevents a duplicate-identity race; the constraint violation is handled, not a 500 | integration + database assertion |
| Stored password differs from the plaintext | database assertion |
| Stored hash verifies through the configured Argon2id encoder and carries the `{argon2}` prefix and the configured parameters | integration + database assertion |
| Malformed registration produces a safe 4xx with no stack trace | integration |
| Password bounds: 14 rejected, 15 accepted, 129 rejected with the limit stated, 128 accepted; 15 astral code points accepted; length measured after NFC | integration |
| A password with leading and trailing spaces authenticates only when those spaces are supplied again | integration |
| The same password in decomposed and precomposed Unicode form authenticates the same account | integration |
| A blocklisted common password is rejected; a password equal to the email local part is rejected; a strong 15-character password is accepted | integration |
| The blocklist resource loads and its entry count matches the recorded version | unit test |
| `"user@example.com"`, `"User@Example.com"` and `" user@example.com "` resolve to one account; the later registrations are rejected as duplicates; login works with all three spellings | integration |
| `"\tuser@example.com"` is rejected as invalid input, not canonicalised | integration |
| A direct insert of a value containing whitespace, a control character or an upper-case letter violates `users_email_canonical` | database assertion |
| Unexpected properties in the request body cannot set `id`, `created_at` or any future role field | integration |

### Login

| Test | Method |
| --- | --- |
| Correct credentials authenticate and return a usable access token | integration |
| Incorrect password fails safely | integration |
| Unknown account fails safely | integration |
| The two responses above are identical apart from anything inherently variable | integration |
| Malformed login produces a safe 4xx | integration |

### Access JWT

| Test | Method |
| --- | --- |
| Valid token is accepted on a protected endpoint | integration |
| Missing token yields 401 | integration |
| Malformed token yields 401 | integration |
| Tampered payload yields 401 | integration |
| Expired token yields 401 | integration |
| Token signed with a different secret yields 401 | integration |
| Unexpected `alg`, including `none`, yields 401 | integration |
| Wrong `iss` or `aud` yields 401 once those claims are configured | integration |
| A self-minted token asserting another user's `sub` grants nothing | integration |

### Refresh token

| Test | Method |
| --- | --- |
| Valid refresh returns a new access token and a new refresh token | integration |
| The token rotates — the returned value differs from the presented one | integration |
| The previous token is unusable afterwards | integration |
| A revoked token cannot be reused | integration |
| Detected reuse revokes the replayed session and **only** that session; the user's other session still refreshes | integration |
| An expired refresh token fails safely | integration |
| A refresh presented after the inactivity window fails | integration |
| A session past its absolute expiry fails even under continuous use | integration |
| No row in `refresh_tokens` equals the plaintext token | database assertion |
| Two live tokens cannot exist in one session (the partial unique index holds) | database assertion |
| **Concurrent refresh with one token:** exactly one succeeds, the other returns a generic 401, no 5xx is produced, one successor exists, and **the within-grace loser does not invalidate the successor** - the winner's token still refreshes and the session is not marked `token_reuse` | concurrent integration test |
| The same race with the grace window set to zero revokes the session per the strict rule | concurrent integration test |
| Logout revokes the presented session; a second session keeps working | integration |
| Logout is idempotent and returns 204 for an unknown or already-revoked token | integration |

### Rate limiting

| Test | Method |
| --- | --- |
| With limits configured low, the request past the limit returns 429 with `Retry-After` | integration |
| Exhausting one account's login budget does not lock out a different account from the same source | integration |
| The 429 body reveals neither the tripped dimension nor whether the account exists, and is identical for an existing and a non-existent account | integration |
| A supplied `X-Forwarded-For` does not change the bucket a request is counted against while no trusted proxy is configured | integration |
| Behind the configured proxy, forwarded clients get separate source buckets; prepended entries, `Forwarded` and `X-Real-IP` do not choose the key (D20) | integration |
| From a peer that is not the configured proxy, `X-Forwarded-For` changes nothing (D20) | integration |
| Proxy mode without an exact proxy address list, with names, ranges or patterns, or with Boot's forwarded-header support re-enabled, fails startup (D20) | configuration test |
| Bucket entries expire once idle beyond their refill period | unit test |
| Upload, history and device registration past their per-user limit return 429 with `Retry-After`, write nothing, and do not affect another account (D18) | integration |
| An unauthenticated request is 401 and consumes no account's budget; a rejected upload body still consumes one (D18) | integration |
| A per-user bucket refills on its own schedule, keyed per account (D18) | unit test, fake clock |

### Account deletion (D19)

| Test | Method |
| --- | --- |
| Deletion with the right password is 204 and leaves no row in `users`, `auth_sessions`, `refresh_tokens`, `devices`, `usage_days` or `usage_day_apps` for the account | integration |
| A wrong password is 403 and changes nothing; unauthenticated is 401; malformed input, or a body naming another account, is 400 | integration |
| After deletion the old access token is 401 on every route and the old refresh token cannot refresh | integration |
| Another account is byte-for-byte unchanged | integration |
| Deletion racing an upload that holds its rows, a registration, and a refresh completes without deadlock and leaves nothing | concurrent integration test, lock order proven by mutation |
| The client clears account state only on 204, never local usage, and a later account uploads the full local history | Flutter tests and real-backend E2E |

### Account quotas (D18)

| Test | Method |
| --- | --- |
| A new device past the active-device quota is 403 with no row; re-registration of an active device at quota is 200; a foreign UUID is still 409; another account is unaffected | integration |
| A device unseen for the active window frees its slot; reactivating it takes a slot and at quota is the same 403 with the row unchanged | integration |
| Concurrent reactivations, and a reactivation racing a new device, for the last slot admit exactly one | concurrent integration test |
| Concurrent registrations for the last slot admit exactly one, proven queued together by a test-held account lock | concurrent integration test |
| A request that would exceed the stored-day budget is 403 and leaves every row unchanged; replace, duplicate, stale and conflict are unaffected at the budget | integration |
| Concurrent uploads for the last stored-day slot admit exactly one | concurrent integration test |

### Configuration

| Test | Method |
| --- | --- |
| The context fails to start with no JWT secret configured | configuration test |
| The context fails to start with a secret that is not valid base64, and with one decoding to 31 bytes; it starts with one decoding to 32 | configuration test |
| Every required `prod` variable, removed in turn, fails startup | configuration test |
| `ddl-auto` is `validate` in the test profile (already proven by `FlywayBaselineIT` starting) | configuration test |
| The public endpoint allow-list contains exactly the intended paths | integration |

### Information leakage

| Test | Method |
| --- | --- |
| No authentication response contains a password | integration |
| No response contains a password hash | integration |
| Refresh tokens appear only in the login and refresh responses | integration |
| A forced internal failure returns a generic 500 with no exception detail | integration |
| Malformed requests never return a stack trace | integration |

### Later phases

The device and sync stages add the BOLA suite from section 4: User A owns Device
A, User B is authenticated, and every read, write, delete and usage submission by
User B against Device A is rejected with no side effect. Plan criterion 13 is the
existing hook and must be expanded to all four verbs rather than read-and-upload
only.

---

## 19. Decision register

Decisions are **owned by `backend-sync-architecture.md`**, which is where the
chosen behaviour, rationale, consequence and verification for each one live. This
table is the index and the status, not a second copy.

Resolved on 2026-09-17, before Phase 1 Step 2. Every resolved decision except D12
(devices, Step 3) is implemented as of Phase 1 Step 2 (2026-09-18) and verified by the
section 18 tests; see the progress document. Section 2 and the section 3 status column
describe the pre-Step-2 state and are not updated entry by entry.

| # | Decision | Status | Where |
| --- | --- | --- | --- |
| D01 | Argon2id parameters | Resolved | architecture 5.1, D01 |
| D02 | Password length bounds | Resolved | architecture 5.1, D02 |
| D03 | Account identity and case-insensitive uniqueness | Resolved | architecture 5.1 D03, schema 6.1 |
| D04 | Access token lifetime | Resolved | architecture 5.1, D04 |
| D05 | Session absolute lifetime | Resolved | architecture 5.1, D05/D06 |
| D06 | Session inactivity expiry | Resolved | architecture 5.1, D05/D06 |
| D07 | JWT algorithm, issuer, audience, claim set | Resolved | architecture 5.1, D07 |
| D08 | Session/family model and replay semantics | Resolved | architecture 5.1 D08, schema 6.1 |
| D09 | Signing key and rotation model | Resolved | architecture 5.1, D09 |
| D10 | Logout and password-change revocation | Resolved | architecture 5.1, D10 |
| D11 | Registration and login enumeration behaviour | Resolved | architecture 5.1, D11 |
| D12 | Foreign device UUID on registration | Resolved earlier | architecture 9 |
| D13 | Total app rows per upload request | Resolved (Step 4): 1,000 | architecture 9.1 |
| D14 | Development versus production configuration | Resolved | architecture 5.1, D14 |
| D15 | Authentication rate limits | Resolved | architecture 5.1, D15 |
| D16 | `403` versus non-revealing `404` for a foreign object | Resolved (2026-09-18) | architecture 5.1, D16 |
| D17 | Compromised-password blocklist | Resolved | architecture 5.1, D17 |
| D18 | Authenticated per-user limits, active-device quota, stored-day budget | Resolved (2026-09-24) | architecture 5.1, D18 |
| D19 | Account deletion: contract, re-authentication, lock order, client cleanup | Resolved (2026-09-24) | architecture 5.1, D19 |
| D20 | Network edge: topology, TLS termination, trusted-proxy client address | Resolved (2026-09-26) | architecture 5.1, D20 |

D16 was resolved before Step 3 (devices), which implements D12 and scopes every
device query by owner. D13 was settled with Step 4 (the upload endpoint): at most
1,000 app rows and 31 days per request.

D17 was briefly held open on the mistaken premise that closing it required an
outbound password-checking API. It does not - a local versioned blocklist is an
equally recognised approach, and a large corpus buys little once D15 rate-limits
attempts. It is resolved and lands in Step 2 with **no runtime network access**,
so API7 stays "not exposed" in section 17.

---

## 20. Conflicts with the current architecture and plan

| # | Conflict | Status |
| --- | --- | --- |
| C1 | JWT claim set had no `iss` or `aud`, so a token minted by another service sharing the secret would verify | **Resolved.** Both claims added and validated - architecture 5.1, D07 |
| C2 | "Revokes the whole chain" was not enforceable: `refresh_tokens` had only `user_id`, so the only available reading was "every token the user has" | **Resolved.** `auth_sessions` is the revocation unit - architecture 5.1 D08 and schema 6.1 |
| C3 | Architecture 9.1 caps 400 days and 2000 apps per day independently, permitting 800,000 rows in one transaction | **Resolved.** 31 days, 500 apps per day, 1,000 rows per request - D13 |
| C4 | Rate limiting deferred to "before a public deployment" with no gate that would stop it shipping | **Resolved.** Throttling moves into Step 2 - architecture 5.1, D15 |
| C5 | Email normalization was application-side while `users_email_key` was case-sensitive | **Resolved.** `users_email_key` kept, plus `CHECK (email = lower(email) AND email ~ '^[!-~]+$')` so the indexed value is always canonical - architecture 5.1 D03, schema 6.1 |
| C6 | Signing key rotation undefined | **Resolved.** Single-key, rotate-by-restart, self-healing through refresh - architecture 5.1, D09 |
| C7 | Plan criterion 13 covered read and upload only | **Resolved.** Criterion 13 broadened to all four verbs in the plan |

None required an architecture rewrite. C1, C4, C6 and C7 were decisions left
implicit and are now written down; C2 and C5 add schema that section 6.1 plans
and no one has yet written. C3 stays open with the sync phase that will reach it.

---

## 21. Out of scope

This baseline defines requirements. It does not authorize implementation.

Not covered and not implied: OAuth or social login, MFA, password reset, email
verification, account lockout as distinct from rate limiting, device
attestation, certificate pinning, end-to-end encryption of usage data, audit log
retention policy, GDPR process documentation, intrusion detection, WAF.

Some of these become relevant if FocusTrace's sync deployment ever becomes
public. None is a Phase 1 requirement, and adding any of them now would build for
an attack surface that does not exist.
