# FocusTrace Backend Sync v1 - Architecture

Status: Phase 1 Steps 1-4 implemented (bootstrap, authentication, devices, usage
upload). History read (Step 5) is designed, not implemented.
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

Short-lived access tokens plus a revocable refresh token is the reason there is a
token table at all: a 30-day non-revocable JWT would be simpler and is the wrong
trade for data this sensitive.

No custom cryptography anywhere: `SecureRandom`, Spring Security's encoders, and a
maintained JWT library.

The decisions below were resolved on 2026-09-17, before Phase 1 Step 2, so the
implementation does not invent security behaviour while writing code. They are
**implemented in Phase 1 Step 2** (2026-09-18); `backend-sync-v1-progress.md` records what
actually exists. Requirements and OWASP rationale live in
`docs/security/backend-security-baseline.md`, which references these decisions by
identifier rather than restating them.

Throughout: a value marked **configuration** may be tuned per deployment without
review; a value marked **policy** is fixed in code and changing it is a reviewed
change.

#### D01 Password hashing

Argon2id via Spring Security's `Argon2PasswordEncoder`, wrapped in a
`DelegatingPasswordEncoder` whose default prefix is `{argon2}`. Parameters:
memory 19456 KiB, iterations 2, parallelism 1, salt 16 bytes, hash 32 bytes.

These are OWASP's current baseline Argon2id parameters. At 19 MiB per in-flight
hash, and with login rate-limited per D15, peak transient memory stays trivial
for a single small instance. **Policy, not configuration:** a work factor exposed
as an environment variable is a work factor that can be silently weakened.

Consequence: Step 2 adds Bouncy Castle, which `Argon2PasswordEncoder` requires.
That is the only new dependency the decision forces.

Verification: database assertion that the stored hash begins `{argon2}` and
encodes `m=19456,t=2,p=1`; round-trip test through the configured encoder.

#### D02 Password bounds

**Minimum 15 characters, maximum 128**, counted in Unicode **code points**,
enforced by Bean Validation on the registration DTO. Over-length input is
rejected with a 400 that states the limit. No composition rules, no forced
rotation.

15, not 12: FocusTrace authenticates with a password and nothing else. There is
no MFA, no email verification, no second factor of any kind, so the password is
the entire barrier in front of a user's complete behavioural history. Where a
second factor absorbs the weak-password case, 12 is defensible; here nothing
absorbs it, so the one knob available is turned up. D01's cost per guess and D15's
cap on guess rate are the other two, and all three are needed.

**Unicode processing: NFC, and nothing else.** The password is normalised to
Unicode NFC and then hashed as UTF-8. It is **not** trimmed, **not** case-folded,
**not** NFKC-folded, **not** truncated, and no character is dropped. Leading and
trailing spaces are part of the password.

NFC is applied because FocusTrace accepts Unicode passwords and Android keyboards
do not agree on composition: the same visible password typed on two keyboards can
arrive as precomposed `U+00E9` or as `e` + `U+0301`, and without normalisation the
second one silently fails to log in. SP 800-63B-4 recommends normalising for
exactly this reason. NFC rather than NFKC because NFKC also folds compatibility
characters, which changes what the user typed rather than how it was encoded.

**Registration and verification must apply byte-identical processing.** One
method produces the value handed to the encoder, and both paths call it. A hash
written with normalisation and checked without it fails to verify, and the
failure looks like a wrong password.

This is the opposite of D03's treatment of the email address only in degree, not
in kind: an identifier is canonicalised so that two spellings mean one account; a
secret is normalised only so that one typed password has one encoding, and is
otherwise left alone, because any further folding discards entropy the user
intended to supply.

**Length is validated after normalisation**, in code points, so the number
checked is the number hashed - NFC can compose two code points into one. Code
points rather than `String.length()` so the rule means what it says: a
16-code-unit `@Size` counts one astral character as two and would reject a
password the user believes is within the limit. SP 800-63B-4 likewise counts each
code point as one character. 128 code points is at most 512 UTF-8 bytes, which is
what the request-size bound sees.

**Policy.** Length carries the strength here; Argon2id has no bcrypt-style
72-byte truncation point, so the maximum exists only to bound work.

Verification: 14 rejected, 15 accepted, 129 rejected with the limit stated, 128
accepted; a password of 15 astral code points is accepted; a password with
leading and trailing spaces authenticates only when those spaces are supplied
again; the same password submitted in decomposed and precomposed form
authenticates the same account; length is measured after normalisation.

#### D17 Compromised-password blocklist

**Resolved: a local, versioned blocklist, in Step 2. No outbound network access.**

A length minimum does not stop a user choosing a 15-character password that
appears in every breach corpus, so D02 narrows this gap without closing it.

The earlier framing here - that closing it meant adding the first outbound HTTP
call in the service - was wrong. A k-anonymity range query against an external
service is *one* way to do this, not the only way; a bundled list checked in
memory is an equally recognised option, and SP 800-63B-4 notes that an
excessively large list adds little once authentication attempts are rate-limited,
which D15 ensures they are. So the reason to defer evaporated.

Design:

- **Provenance.** A published, freely redistributable list of the most common
  passwords, plus a short FocusTrace-specific set (`focustrace` and obvious
  variants, and any password equal to the local part of the account's email
  address). The specific source is selected at implementation from candidates
  whose licence permits redistribution in this repository; **the licence and its
  terms are checked before the file is added**, and the source URL, version and
  retrieval date are recorded in a header comment alongside the resource.
- **Size.** On the order of 10,000 entries - large enough to cover what attackers
  actually try first, small enough to hold in a `Set<String>` loaded once at
  startup (a few hundred KB). Not the full multi-hundred-million corpus, which
  would buy little here and could not be bundled.
- **Update strategy.** The list is a tracked resource file, versioned with the
  application and updated by a deliberate commit. There is no runtime fetch, no
  scheduled refresh, and no network access - which is exactly what keeps API7
  "not exposed" in the security baseline.
- **Comparison.** Against the NFC-normalised password from D02 and against its
  lower-cased form, so `Password123456` is caught by `password123456`. Rejection
  is a 400 telling the user the password is too common, with no hint about which
  entry matched.
- **Enforcement scope (decided 2026-09-18).** The blocklist is an **admission
  control for prospective passwords**, not an authentication-time check. It is
  applied whenever a new password is established: registration, and any future
  password-change or password-reset/recovery flow. Only the prospective new
  password is checked; a current password supplied to authenticate, or to authorize
  a password change, is verified against its stored Argon2id hash and is never
  rejected for appearing in the blocklist. Ordinary login **must not** consult the
  blocklist.
- **No retroactive effect.** Updating the bundled list does not invalidate stored
  credentials: an existing password that appears in a newer version does not, by
  that fact alone, prevent authentication or revoke sessions. Actual evidence that an
  account's authenticator is compromised is a separate security event, handled by a
  remediation flow (forced replacement, session revocation) if one is built - never
  by turning the login path into a blocklist check.

Verification: a known blocklisted 15-character password is rejected at
registration; a password equal to the email local part is rejected; a strong
15-character password is accepted; a unit test asserts the resource loads and its
entry count matches the recorded version; an unknown-account login with a
blocklisted value follows the generic 401 / dummy-Argon2id path; an existing
account whose stored password later joins the list still authenticates. When a
password-change or reset endpoint is added, it must carry a test that a blocklisted
prospective password is rejected.

#### D03 Account identity (resolves C5)

The account identifier is the email address. The canonicalisation algorithm is
defined once, precisely, and both layers implement **that** algorithm rather than
each approximating it.

**Canonicalisation, in order:**

1. Remove leading and trailing **`U+0020` SPACE only**. Not `String.trim()`,
   which removes every character at or below `U+0020`, and not `String.strip()`,
   which removes Unicode whitespace. Exactly one code point is stripped.
2. Reject the result unless every character is printable ASCII,
   `U+0021`-`U+007E`, and it satisfies the email-shape validation. Any remaining
   whitespace, any control character and any non-ASCII character makes the
   address invalid input, returning 400 - it is never silently removed.
3. Lower-case with `Locale.ROOT`. The default-locale overload maps `I` to a
   dotless `i` under a Turkish locale and would split one identity into two.

So a canonical address **contains no whitespace at all and is lower-case**, which
is the invariant PostgreSQL can state exactly:

```sql
ALTER TABLE users
    ADD CONSTRAINT users_email_canonical
    CHECK (email = lower(email) AND email ~ '^[!-~]+$');
```

`users_email_key UNIQUE (email)` from `V1` is **kept unchanged**. Together the
two make the database the final authority: the `CHECK` admits only canonical
addresses, so uniqueness over the stored value is uniqueness over identities.

**Why this is equivalent and not merely similar.** Step 2 confines the stored
value to `U+0021`-`U+007E`, and over that range PostgreSQL `lower()` and Java
`toLowerCase(Locale.ROOT)` agree exactly - ASCII case mapping is identical in
every collation and locale. "Trimmed" needs no SQL equivalent because a canonical
address cannot contain a space anywhere, which `[!-~]` already excludes. There is
no input a direct `INSERT` can smuggle past the `CHECK` that the application
would have canonicalised differently.

This replaces two earlier formulations, both wrong:

- `UNIQUE INDEX (lower(email))` enforced the case half and ignored trimming, so
  `" user@example.com "` was a separate identity.
- `CHECK (email = lower(btrim(email)))` was claimed to "fail closed" on
  Java/SQL divergence. **It does not.** Bare `btrim` strips `U+0020` only, so a
  direct insert of `E'\tuser@example.com'` satisfies that predicate while
  remaining a distinct value under `UNIQUE (email)` - exactly the divergence the
  constraint was supposed to prevent. Excluding the characters outright, rather
  than trying to reproduce Java's trimming rule in SQL, removes the whole class
  of argument.

**Accepted limitation:** internationalised addresses (RFC 6531 UTF-8 local parts,
IDN domains) are rejected. That is a deliberate trade for an identity rule whose
two enforcement points are provably the same rule. If EAI ever matters, the
upgrade path is a separate stored canonical column with its own normalisation,
not a loosened `CHECK`.

The repository lookup takes an **already-canonical** parameter from the same
canonicalisation method the registration path uses, and reads
`WHERE email = :canonicalEmail` against the existing unique index. One method,
one spelling; a lookup that canonicalises differently from the writer is the bug
this decision exists to make impossible.

Consequence: a migration is required, smaller than previously planned. See 6.1.

Verification: `"user@example.com"`, `"User@Example.com"` and
`" user@example.com "` all resolve to one account, the second and third
registrations are rejected as duplicates, and login with any of the three
spellings authenticates the same account; `"\tuser@example.com"` is rejected as
invalid input rather than canonicalised; a direct insert of any value containing
whitespace, a control character or an upper-case letter violates
`users_email_canonical`.

#### D04 Access token lifetime

15 minutes (**configuration**, default `PT15M`). Confirms the original design
value. Clock skew tolerance is **zero** (**policy**): one process issues and
verifies these tokens, so there is no clock to disagree with.

Verification: a token whose `exp` has passed is rejected with 401.

#### D05/D06 Session lifetime

A login session has an **absolute expiry of 90 days** and an **inactivity expiry
of 30 days**. Both are **configuration** (`PT2160H`, `PT720H`). The refresh token
current at any moment expires at the earlier of `issued_at + 30 days` and the
session's absolute expiry; rotation therefore slides the inactivity window
forward but can never extend the session past 90 days.

This supersedes the flat "TTL 60 days" written here during design. A single flat
window answers neither question it was standing in for: it let an abandoned
installation hold a live credential for two months, and it let an active one hold
one indefinitely. Two bounds, two `TIMESTAMPTZ` comparisons, no extra machinery.

Verification: a refresh presented after the inactivity window fails; a session
older than the absolute window fails even with continuous use.

#### D07 JWT claims (resolves C1)

Algorithm **HS256**; issuer `focustrace-sync`; audience `focustrace-app`; claims
exactly `iss`, `aud`, `sub` (user UUID), `iat`, `exp`, `jti`. Nothing else: no
email, no device list, no roles.

Issuer and audience are **configuration** with those defaults, and both are
**validated on every request**. They cost one string comparison each and they are
what stops a token minted by some other service that happens to share the secret
from validating here. Retrofitting them after clients are in the field is not
free, so they go in now.

HS256 rather than an asymmetric algorithm because exactly one service both issues
and verifies; a public key with no third-party verifier buys nothing and adds key
distribution.

**The verifier accepts only the configured algorithm.** The `alg` header of an
incoming token is attacker-controlled input and must never select the
verification path.

Verification: wrong `iss`, wrong `aud`, `alg: none`, an unexpected algorithm, a
foreign signing key, and a tampered payload each yield 401.

#### D08 Sessions and refresh tokens (resolves C2)

"Revokes the whole chain" was not enforceable: `refresh_tokens` has only
`user_id`, so the only available reading of "chain" was "every token the user
has", which would log a user out of every installation because one was replayed.
A session table fixes that, and it is two columns of real work.

```text
users 1---* auth_sessions 1---* refresh_tokens
```

- **`auth_sessions`** is one login on one installation. It owns
  `absolute_expires_at`, `revoked_at` and `revoked_reason`
  (`logout` | `password_change` | `token_reuse`).
- **`refresh_tokens`** gains `session_id`. Each row is one issued token, stored
  as the SHA-256 of the 256-bit random value (see the security baseline for why
  SHA-256 and not Argon2id here).
- A token is **current** iff `revoked_at IS NULL`, `expires_at > now()`, and its
  session is neither revoked nor past its absolute expiry.
- **At most one current token per session**, enforced by a partial unique index,
  so "rotation invalidated the predecessor" is a database invariant rather than
  an application intention.
- The session is deliberately **not** linked to `devices`: a session exists
  before any device is registered, and coupling them would make login depend on a
  later phase.

**Consumption and rotation are one transaction, and consumption is a single
atomic conditional state transition.** The whole refresh runs inside one
`@Transactional` unit, and the token is claimed by:

```sql
UPDATE refresh_tokens
   SET revoked_at = now()
 WHERE token_hash  = :hash
   AND revoked_at IS NULL
   AND expires_at  > now()
```

Exactly one caller can see one updated row. Under PostgreSQL's default
`READ COMMITTED`, the loser of a race blocks on the row lock, re-evaluates the
predicate against the committed version once the winner commits, finds
`revoked_at` no longer null, and updates zero rows. `SELECT ... FOR UPDATE`
followed by a check and an update is equivalent and acceptable; the conditional
`UPDATE` is preferred because it cannot be written with the check accidentally
outside the lock.

**The row count is the decision.** Zero rows updated means the token was not
current, and the request is refused - it is never retried, never resolved by
catching an exception later. Specifically: relying on the partial unique index
on `(session_id) WHERE revoked_at IS NULL` to raise a constraint violation when
two successors are inserted is **not** the concurrency mechanism. That index is a
last-line invariant proving the design holds; a `DataIntegrityViolationException`
arriving at the controller is a bug, not a control.

Only after a successful claim does the transaction insert the successor row and
return the new token value. A failure anywhere rolls both back, leaving the
presented token still current and the client free to retry.

**Reuse-detection grace window.** RFC 9700's basic rotation model treats any
presentation of an invalidated token as replay and revokes the active token,
because the server cannot tell which party is legitimate. FocusTrace keeps that
rule with one narrow exception: a token consumed within a **reuse-detection
grace window** (configuration, default 10 seconds) whose successor has not itself
been used yet receives a generic 401 and **does not revoke anything**. Outside the
window, or once the successor has been used, D08's replay rule applies in full and
the session dies.

**What this does and does not buy.** It exists so two requests racing from one
client - two parallel API calls both deciding to refresh - cost one 401 instead of
a logout. It is **not** recovery for a lost refresh response, and must not be
described as such: if the server rotated the token and the response never
arrived, the client no longer holds any usable refresh token, and a 401 on the
retry leaves it exactly as stranded as a revocation would. **That client must
sign in again.** Accepted for v1.

Making a lost response genuinely recoverable would mean caching the response or
retaining the successor's plaintext so it could be handed out twice - storing a
live bearer credential in recoverable form, which section 7 of the security
baseline forbids, in exchange for a rare failure that costs one login. Not built.

The existence of the window is policy; its length is configuration. Setting it to
zero yields strict RFC 9700 rotation and is a supported configuration.

Replay semantics:

| Presented | Server response | State change |
| --- | --- | --- |
| Current token | new access + refresh token | predecessor revoked |
| Hash not found | 401 generic | none - it cannot be attributed to a session |
| Revoked within the grace window, successor unused | 401 generic | none - duplicate delivery, not theft |
| Revoked token, session still live | 401 generic | **session revoked, reason `token_reuse`, every remaining token in it revoked** |
| Token or session expired, or session already revoked | 401 generic | none |

Only the session that was replayed dies. Other installations keep working, which
is what makes the policy safe to enforce automatically.

Verification: rotation returns a different token; the predecessor stops working;
replaying the predecessor after the grace window kills that session and only that
session; no `refresh_tokens` row ever equals a plaintext token. Plus the
concurrency test required below.

**Required concurrency test.** Issue one refresh token, then submit two refresh
requests with it concurrently, and assert:

- exactly one succeeds - two successful rotations is a failure;
- the other returns a generic 401, and **no 5xx is produced**;
- exactly one successor token exists for the session, and the presented token is
  revoked;
- **the within-grace loser does not invalidate the successor**: the token the
  winner received still refreshes successfully afterwards, and the session is
  neither revoked nor marked `token_reuse`;
- with the grace window set to zero, the same race instead revokes the session
  per the strict rule, and that is the documented behaviour rather than a
  regression.

This is a real integration test against PostgreSQL with two threads, not a
single-threaded approximation. A single-threaded test cannot distinguish a
correct conditional update from a check-then-act that happens to work.

#### D09 Signing key (resolves C6)

One HS256 secret from `FOCUSTRACE_JWT_SECRET`, no default, validated at context
startup.

Requirements on the material itself:

- **Generated by a cryptographically secure RNG**, for example
  `openssl rand -base64 32`. Not typed, not chosen, not derived from a
  passphrase, a hostname, a project name or a date.
- **At least 256 bits of entropy - 32 decoded bytes** - matching HS256's
  output size. Below that the MAC key, not the algorithm, is the weak point.
- Supplied **base64-encoded**, and the length measured **after decoding**.
  Checking that the environment variable's *string* length is at least 32 is a
  different and weaker check; the earlier "shorter than 32 bytes" wording here
  was ambiguous on exactly that point.

Startup fails if the variable is absent, is not valid base64, or decodes to fewer
than 32 bytes. This holds in **every** profile, not only `prod` - there is no
development fallback secret, because a development fallback is exactly the thing
that reaches production by accident.

**What the startup check does and does not establish.** It validates *encoding
and length*. It cannot establish entropy: a memorable phrase that happens to use
only base64 characters and runs to 44 of them decodes to 32 bytes and passes,
while carrying a small fraction of 256 bits. No startup check can tell those
apart, because the difference is in how the value was produced, not in the value.

The CSPRNG requirement is therefore an **operational requirement on whoever
provisions the deployment**, verified by process - a documented generation
command and a deployment review - not by code. Stating it as though the format
check enforced it would be a false assurance, which is worse than no check.

Rotation in v1 is: set the new value, restart. No `kid` header, no overlapping
key window, no JWKS. This is acceptable because of how the two token types
differ: access tokens become invalid for at most one request, and refresh tokens
are opaque database rows that a signing key change does not touch, so every
client repairs itself through the normal refresh flow without the user noticing.

`kid` plus a two-key verification window is the documented upgrade path if
zero-failed-request rotation ever matters. It does not today.

Verification: the context fails to start with the variable absent, with a value
that is not valid base64, and with a value that decodes to 31 bytes; it starts
with one that decodes to 32.

#### D10 Revocation semantics

- **Logout** (`POST /api/v1/auth/logout`, carrying the refresh token) revokes
  **that session only**, reason `logout`. It returns 204 whether or not the token
  was valid, so it is idempotent and is not an oracle.
- **Password change** revokes **every session** for that user, reason
  `password_change`. No password change or reset endpoint exists in Step 2; this
  is the behaviour the endpoint must have whenever it is added. The new password
  passes D02 bounds and the D17 blocklist; the current one is only verified.
- Outstanding **access tokens survive any revocation** until they expire, for at
  most the D04 window. That is the accepted cost of statelessness, and it is
  bounded: an access token cannot renew itself, so the session is dead within 15
  minutes regardless.

Verification: after logout the refresh token fails while a second session
continues to work.

#### D11 Registration and login responses

**Registration discloses.** A duplicate registration returns `409` with a clear
message. A uniform `201` would require an email verification flow FocusTrace does
not have, and would leave a user who forgot they had an account waiting for a
mail that never arrives. The identifier is an address the requester already
possesses, and D15 limits registration hardest precisely because this is the
disclosing endpoint.

**Login does not disclose.** Unknown account, wrong password and malformed
credentials all return the same 401 and the same body. When no user row is found
the service still performs an Argon2id verification against a fixed dummy hash,
so the trivial "no row, instant reply" timing oracle does not exist. This still
matters despite registration disclosing: it stops the login endpoint from
becoming a second, more heavily used enumeration channel.

The duplicate-registration path is driven by the unique index violation (D03),
caught and translated to 409. A pre-insert existence check may improve the
message but is never the authority, because it loses races.

Verification: unknown-account and wrong-password responses are identical; a
duplicate registration returns 409 and creates no second row.

#### D15 Rate limiting (resolves C4)

**Implemented in Step 2, not deferred.** Registration, login and refresh are the
only anonymous flows in the system; leaving them unthrottled while shipping them
is what turns "acceptable for a private deployment" into a habit.

In-process **token buckets** in a bounded map. No Redis, no Bucket4j, no new
dependency: there is one instance, and auth traffic is a handful of requests per
user per day.

A token bucket rather than a fixed window, because a fixed window lets an
attacker spend a full allowance at the end of one window and another immediately
at the start of the next - double the intended rate, at exactly the moment a
limiter is supposed to hold. A bucket is a capacity plus a refill rate and one
`long` of state per key; it smooths that boundary away and gives `Retry-After`
directly from the time to the next token. A sliding-window counter would be
equally acceptable; a plain fixed-window map is not.

The map is **bounded and self-expiring**: entries idle for longer than their full
refill period are evicted, and the map has a hard maximum size with
least-recently-used eviction above it. Both matter. An unbounded IP-keyed map is
itself a memory-exhaustion vector, which would make the anti-abuse control an
abuse vector. Volumetric abuse is the reverse proxy's job; this layer exists to
stop credential stuffing.

Two dimensions counted **independently**, whichever trips first:

| Flow | Per source | Per account identifier |
| --- | --- | --- |
| `POST /auth/register` | 5 / hour | - |
| `POST /auth/login` | 10 / 15 min | 5 / 15 min |
| `POST /auth/refresh` | 60 / hour | - |

A combined `IP + username` bucket is explicitly rejected: it stops neither one
source trying many accounts nor many sources trying one account.

All six values are **configuration** and are **initial operational defaults, not
architecture** - expect to tune them against real traffic. The dimensions, the
independence of the counters, and the fact that the limits exist are **policy**.

**Source identity comes from the transport connection, not from a header.**
`Forwarded` and `X-Forwarded-For` are attacker-controlled strings until something
trustworthy overwrites them; honouring them unconditionally both bypasses the
per-source limit outright and lets an attacker mint unlimited bucket keys to
evict everyone else's.

So the default is `server.forward-headers-strategy: none`, and the client source
is the socket peer address. This corrects the `framework` value written here
earlier, which assumed a proxy that does not exist yet.

**When a reverse proxy is introduced** - it will be, since it terminates TLS -
trusted-proxy handling must be configured explicitly **in the same change** that
puts the proxy in front of the service: the proxy set to overwrite rather than
append the forwarded header, and the application configured to accept it only
from that proxy's address. Deploying behind a proxy without that step silently
turns every rate limit into a per-attacker-chosen-string limit, and every log
entry's client address into a fiction.

Exceeding a limit returns `429` with `Retry-After` and the standard problem body,
revealing neither which dimension tripped nor whether the account exists.

Verification: with limits configured low, the request after the limit returns
429; exhausting one account's login budget does not lock out a different account
from the same source.

#### D14 Configuration and fail-fast

The `prod` profile supplies **no fallback** for `FOCUSTRACE_DB_URL`,
`FOCUSTRACE_DB_USER`, `FOCUSTRACE_DB_PASSWORD` or `FOCUSTRACE_JWT_SECRET`. A
missing or blank value fails context startup, not the first request that needs
it. The default profile keeps today's localhost development values, which is why
they must never be the production path.

Enforced by a `@Validated @ConfigurationProperties` record
(`@NotBlank`, `@Size(min = 32)` on the signing secret), so the failure is a
startup binding failure with a clear message and no secret in it.

Also asserted for `prod`: `ddl-auto` is `validate`, `server.error.include-*` are
all off, no Actuator on the classpath, CORS disabled, CSRF disabled because the
transport is the `Authorization` header.

Verification: a configuration test starting the context under `prod` with each
required variable missing in turn, expecting startup failure each time.

#### Implementation notes (Phase 1 Step 2)

Recorded where the implementation had to choose within, or discovered a limit of, a
decision above. None changes a decision's behaviour.

- **D17 source.** The SecLists `10k-most-common` list holds exactly one entry of 15+
  characters, so under D02 it would block nothing. The resource
  (`server/src/main/resources/auth/common-passwords.txt`, version 1, 10,912 entries)
  is the SecLists `xato-net-10-million-passwords-1000000` list (MIT) filtered to
  15-128 printable-ASCII characters, lower-cased and de-duplicated, plus 14
  FocusTrace-specific entries. Commit, upstream checksum, transform and licence text
  are in its header.
- **D07 serialisation.** A single `aud` serialises as a JSON string, not an array
  (RFC 7519 allows either). The header carries `alg` only: the encoder is built so
  that no `kid` (which would be a thumbprint of the HMAC secret) is written, per D09.
  D07's six-claim set defines **issued** tokens. Acceptance is defined by D07's
  verification list and baseline section 6, neither of which requires `iat` or
  `jti`. `jti` is required on acceptance anyway, because baseline section 6 reserves
  it for a future denylist; `iat` is not, so an otherwise valid token without `iat`
  is accepted. (Verified at runtime, `AccessTokenIT`: Spring synthesises the missing
  `iat` as `exp - 1 s` before validation.)
- **D10 logout** takes two credentials with separate jobs. The **refresh token** in
  the body identifies the session (hashed, then looked up in `refresh_tokens`); the
  access JWT cannot, since it carries no session claim and no `jti`-to-session record
  exists. The **bearer access token** is required because baseline section 13 makes
  exactly register, login and refresh public; its `sub` is the ownership predicate in
  the lookup (`... WHERE token_hash = :hash AND user_id = :sub`). A token that is
  unknown, already revoked or another user's matches nothing: silent 204, per D10.
  Consequence: a client whose access token has expired refreshes before logging out.
- **D14 mechanism.** Not a validated `@ConfigurationProperties` record for the
  datasource: Boot binds an unresolvable `${FOCUSTRACE_DB_URL}` as its literal text,
  and a blank password would reach the DataSource. A `prod`-only bean-factory
  post-processor rejects missing or blank `FOCUSTRACE_*` values before any bean is
  created. The signing secret is checked in every profile when the key is built.
- **Malformed UTF-16.** A JSON escape can deliver an unpaired surrogate, which the
  Argon2 encoder cannot convert to UTF-8. Registration rejects it (400); login treats
  it as a wrong password after a dummy verification (401). Found by the Step 2
  security review.

#### Deferred, and why it is safe to defer

- **D13/C3** (total app rows per upload request) belonged to the sync endpoint.
  Resolved in Step 4: at most 1,000 app rows per request (section 9.1).
- **C7** (broadening the BOLA criterion to all four verbs) is already recorded in
  the plan.

#### D16 Foreign-object authorization response

**Resolved 2026-09-18, before Step 3.** Applies to every **private, user-owned
object** reached through a client-supplied identifier: devices, usage days, and
anything added later that belongs to one account.

- **Ownership is a query predicate.** Every statement that reads or writes such an
  object carries the authenticated `user_id` (directly, or through a join to
  `devices.user_id`). No endpoint loads an object by its global identifier and
  compares its owner afterwards.
- **Foreign resolves as nonexistent.** An object owned by another account is
  indistinguishable from one that does not exist: **`404`** with the same generic
  problem body, never `403`, never a different message, header or timing path
  that depends on whether the identifier exists.
- **No side effect.** A request that resolves to a foreign object writes nothing:
  no row created, updated, touched (`last_seen_at` included) or deleted.
- **Collections filter, they do not fail.** A listing or history read returns the
  caller's objects only; a foreign `deviceId` filter yields an empty result or `404`
  exactly as an unknown one would.
- **`403`** stays reserved for an authenticated caller refused for a reason
  unrelated to object ownership. There is no such case today.

**Scope limit.** D16 does not override an endpoint whose contract deliberately
discloses existence. The one such endpoint is `POST /api/v1/devices` (D12, section
9): a client-generated UUID that another account already owns returns `409`, so the
installation can regenerate its UUID. That response still reveals nothing about the
owner, changes nothing, and confirms only a 122-bit random value the caller already
holds.

Rationale: a `403` for "exists but not yours" turns every identifier endpoint into
an existence oracle; returning the same `404` costs nothing, and putting ownership
in the query means a forgotten check returns nothing instead of another user's row.

Verification, for every endpoint that addresses a private object: User B, fully
authenticated, targets User A's object with every supported verb; the response is
the same status and body as for a random unknown identifier; User A's rows are
byte-for-byte unchanged; User A still reaches the object. Step 3 exposes no route
that addresses a single device by id (`POST` is D12's exception and `GET` is a
scoped collection), so D16's `404` path is first exercised by the Step 4 upload and
Step 5 history endpoints.

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
  API does not confirm that someone else's device id exists (D16).

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
- `duration_seconds <= 86400` was a cheap sanity bound, and too tight: see 6.2.
  `V3` makes it `<= 90000`.
- `source_status` gains `imported` beyond the local vocabulary - see 7.2.
  `unavailable` days are never uploaded, so the server does not model them.

### 6.1 `V2` - authentication schema (`V2__auth_sessions.sql`)

Required by D03 and D08. **Implemented as `V2__auth_sessions.sql`**, verbatim below;
`V1__baseline.sql` has been applied to real PostgreSQL and is not edited.

```sql
-- D03: the database, not the service layer, is the final authority on identity.
-- users_email_key UNIQUE (email) from V1 is kept; this CHECK is what makes the
-- value it indexes always canonical, so uniqueness over it is uniqueness over
-- identities.
--   lower(email) = email  : stored lower-case. Over U+0021-U+007E this is
--                           exactly Java toLowerCase(Locale.ROOT).
--   ~ '^[!-~]+$'          : printable ASCII only. Excludes whitespace and
--                           control characters outright, which is why no SQL
--                           equivalent of Java's trimming rule is needed.
ALTER TABLE users
    ADD CONSTRAINT users_email_canonical
    CHECK (email = lower(email) AND email ~ '^[!-~]+$');

-- D08: a login session is the revocation unit. A replayed token kills its own
-- session, not every session the user has.
CREATE TABLE auth_sessions (
    id                  UUID PRIMARY KEY,
    user_id             UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    absolute_expires_at TIMESTAMPTZ NOT NULL,
    revoked_at          TIMESTAMPTZ,
    revoked_reason      TEXT CHECK (revoked_reason IN ('logout', 'password_change', 'token_reuse')),
    CONSTRAINT auth_sessions_revocation_consistent
        CHECK ((revoked_at IS NULL) = (revoked_reason IS NULL)),
    CONSTRAINT auth_sessions_id_user_key UNIQUE (id, user_id)
);
CREATE INDEX auth_sessions_user_id_idx ON auth_sessions (user_id);

ALTER TABLE refresh_tokens
    ADD COLUMN session_id UUID NOT NULL,
    ADD CONSTRAINT refresh_tokens_session_fk
        FOREIGN KEY (session_id, user_id)
        REFERENCES auth_sessions (id, user_id) ON DELETE CASCADE;

-- At most one live token per session: rotation invalidating its predecessor is a
-- database invariant, not an application intention.
CREATE UNIQUE INDEX refresh_tokens_one_current_per_session
    ON refresh_tokens (session_id) WHERE revoked_at IS NULL;
```

Three constraints here are load-bearing rather than tidy:

- `users_email_canonical` is what makes `users_email_key` a uniqueness constraint
  over *identities* rather than over byte strings. Without it, `" user@example.com "`
  and `"user@example.com"` are two accounts.
- The **composite** foreign key `(session_id, user_id)` makes it impossible to
  attach a refresh token to a session belonging to a different user. The
  redundant `refresh_tokens.user_id` from `V1` is kept for exactly this reason.
- The **partial unique index** is a last-line invariant behind D08's rotation
  guarantee. It is not the concurrency mechanism - the conditional `UPDATE` in
  D08 is - but without it, a bug that forgets to revoke the predecessor would
  leave two usable tokens and no test would necessarily notice.

`ALTER TABLE ... ADD COLUMN session_id UUID NOT NULL` requires the table to be
empty, which it is: no authentication code has ever run. If that stops being
true, the column arrives nullable and is backfilled.

Whether this ships as `V2` or is folded into `V1` while nothing is deployed is the
developer's call. `V2` is the default answer, because `V1` has been applied to a
real database.

### 6.2 `V3` - DST-safe duration bound (`V3__usage_duration_dst.sql`)

Implemented in Step 4. A local day is 25 hours on a DST fall-back date, and the
client attributes foreground time exclusively within the local-midnight window
(`UsageDayWindow`, `aggregateEvents`), so one app's total can legitimately reach
90,000 s. Under the V1 bound that day, and with it the whole batch, would be
rejected on every retry.

```sql
ALTER TABLE usage_day_apps
    DROP CONSTRAINT usage_day_apps_duration_seconds_check,
    ADD CONSTRAINT usage_day_apps_duration_seconds_check
        CHECK (duration_seconds >= 0 AND duration_seconds <= 90000);
```

A fixed bound, not one derived per `localDate` and `timezoneId`: the extra precision
is not worth the complexity. Relaxing a CHECK cannot invalidate existing rows.
`V1` and `V2` are not edited. The DTO bound (`@Max(90000)`) matches it.

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

Legacy pre-v5 days, days restored from a portable backup, and Windows days have no
`usage_snapshot_days` row, so they have no `queried_at_ms` to use as a version.
They upload with `source_status = 'imported'`.

**Version policy. Resolved 2026-09-20, before the Phase 2 client** (the
prerequisite named in 9.2). Such a day uploads with
`snapshotVersion = sync_imported_version_ms`: one value in `settings` holding the
local wall clock at the moment that versionless content was last established. It
is written by `_invalidateUsageRecovery`, the single transaction through which
both `importPortableData` and `clearAllData` rewrite that content and rotate
`usage_recovery_generation`, and is initialised to "now" the first time a sync run
needs it.

This replaces the earlier `snapshot_version = 1`, which failed both halves of the
9.2 requirement. Once a real snapshot for a day had been uploaded, re-importing
that day would carry version 1, be answered `STALE`, and leave the server holding
the superseded content permanently. And two different imports would both carry
version 1 with different content, which is a permanent `CONFLICT`.

Why one epoch-millisecond scalar is enough:

- **It cannot regress.** The stamp comes from the same wall clock that produced
  every `queried_at_ms` already uploaded, read at a later instant, so it exceeds
  them. An import can supersede a real snapshot instead of being rejected.
- **It cannot repeat across changed content.** Versionless content changes only
  inside `_invalidateUsageRecovery`, which advances the stamp in that same
  transaction.
- **It is stable when nothing changed.** A re-run sends the same version with the
  same content, which is `DUPLICATE`, exactly like a real snapshot.
- **Per install, not per day.** Every versionless day shares the stamp, which is
  correct: `snapshot_version` orders one `(device, local_date)`, never two dates.
- Wall-clock regression has the consequence already described in section 14,
  risk 1: a `STALE` day that the next advance repairs. Local data is untouched.

**Deliberately not covered: open Dart-written days.** On Windows every day is
written by `saveDailySummaries` with no snapshot row, and the current day changes
through the day without passing through `_invalidateUsageRecovery`; the stamp
would then repeat for changed content, which is `CONFLICT`. The Sync v1 client
therefore uploads from Android only, where the current day always has a
`usage_snapshot_days` row. The Windows shell is on a parked branch (section 14,
risk 8); when it returns it needs its own version for the open day, not this
stamp.

### 7.3 Write path

**Implemented in Step 4** (`usage/UsageDays`). The whole request is one
`@Transactional` unit, in this order:

1. Resolve the device under the caller:
   `SELECT 1 FROM devices WHERE id = :deviceId AND user_id = :userId FOR KEY SHARE`.
   No row -> `404` (D16), nothing written. `KEY SHARE` stops the device being
   deleted under the transaction without blocking other uploads to it.
2. Request-wide validation (section 9.1). Any failure -> `400`, nothing written.
3. Sort the days by ascending `localDate`, then per day:

```sql
INSERT INTO usage_days (device_id, local_date, snapshot_version, timezone_id, source_status)
SELECT id, :localDate, :version, :tz, :status
  FROM devices WHERE id = :deviceId AND user_id = :userId
ON CONFLICT (device_id, local_date) DO UPDATE
    SET snapshot_version = EXCLUDED.snapshot_version,
        timezone_id      = EXCLUDED.timezone_id,
        source_status    = EXCLUDED.source_status,
        received_at      = now()
WHERE usage_days.snapshot_version < EXCLUDED.snapshot_version
RETURNING snapshot_version;
```

| Stored version | Result | Writes |
| --- | --- | --- |
| none | `APPLIED` | parent inserted; app rows inserted |
| lower than incoming | `APPLIED` | parent updated; all app rows deleted, new set batch-inserted |
| higher than incoming | `STALE` | none |
| equal, same content | `DUPLICATE` | none |
| equal, different content | `CONFLICT` | none |

"Same content" compares the persisted representation: `timezone_id`,
`source_status`, and the app rows as a set keyed by `app_key` with `app_name`,
`duration_seconds` and `launch_count`. Incoming array order is irrelevant. There is
no payload hash and no Unicode normalization: strings compare exactly. An equal
version with different content is reported, never hidden as `DUPLICATE` and never
applied.

Whole-day replace, never accumulate. `duration_seconds` is a total, not a delta, so
adding would inflate usage on every retry - the exact failure this design must not
have. A newer snapshot with `apps: []` replaces an older non-empty one.

Every statement carries the caller's `user_id` (D16): the upsert inserts only via
the owner-filtered `SELECT`, and the delete and equal-version reads join `devices`.

**Concurrency.** Relies on PostgreSQL READ COMMITTED, which is not overridden.
`ON CONFLICT DO UPDATE` locks the conflicting row even when its `WHERE` is false,
and holds the lock to commit. A concurrent insert of the same key waits for the
first transaction, then takes the conflict path against the committed row. So two
equal versions cannot both apply; the loser's equal-version read sees the committed,
locked row and its app rows, which only the lock holder can change. Newer and older
racing cannot pair one version's metadata with another's app rows. Sorting the
days gives every request the same lock order, so overlapping batches cannot
deadlock. No `SELECT ... FOR UPDATE`, application lock or retry loop.

**Transactionality.** `STALE`, `DUPLICATE` and `CONFLICT` are outcomes, not errors:
they do not roll back other days. An actual failure on any day (a constraint, the
database) rolls back the whole request, including a day whose app rows were already
deleted. Deterministically invalid input never gets that far: step 2 rejects it
first.

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

**Import and clear reset the watermark.** This settles risk 3 in section 14.
`importPortableData` replaces `daily_app_usage` rows in place and advances no
`queried_at_ms`, so a watermark alone would never re-offer the mutated days.
`_invalidateUsageRecovery` therefore sets `sync_usage_watermark_ms` to `0` in the
same transaction that deletes the snapshot rows, rotates
`usage_recovery_generation` and advances `sync_imported_version_ms` (7.2). The
next run re-offers everything: unchanged days answer `DUPLICATE`, mutated ones
carry the new stamp and are `APPLIED`.

**`sync_` settings are device-local and not portable.** `exportPortableData`
already excludes `usage_recovery_generation` on the grounds that a backup carries
data, not device-local evidence. Every `sync_` key is excluded for the same
reason, and `importPortableData` drops them from an incoming backup as well.
Otherwise restoring one installation's backup onto another would clone
`sync_installation_id`, and two installations would upload as one device - each
overwriting the other's days under a single `(device_id, local_date)` key.

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

### 8.4 Client sync layering

**Implemented in Phase 2.** Section 13's constraint, made concrete:

```text
domain/repositories/sync_repository.dart        the interface the app sees
data/repositories/sync_repository_impl.dart     selection, sanitization, watermark
data/datasources/focus_trace_sync_api.dart      the only HTTP in FocusTrace
data/datasources/focus_trace_local_data_source.dart
                                                UsageSyncDataSource, read-only
```

- `FocusTraceSyncApi` is the one place the app speaks HTTP. It owns the Sync v1
  endpoints, JSON, status mapping and the access-token lifecycle. No widget,
  screen or view model can reach it: `syncRepositoryProvider` exposes only the
  domain interface.
- Transport is `dart:io`'s `HttpClient` with `dart:convert`. **No HTTP
  dependency was added.** Four endpoints do not need a package, and the tests
  drive a real local `HttpServer` instead of a mock, which is closer to the real
  thing anyway.
- `syncNow` never throws. Every failure becomes a `SyncRunResult`, the same way
  `recoverUsageHistory` swallows its own, so an unreachable, misconfigured or
  disabled backend cannot touch tracking, restrictions, blocking, schedules,
  local history or the UI.
- Sync is opt-in at build time through
  `--dart-define=FOCUSTRACE_SYNC_BASE_URL=...`. Without it
  `syncRepositoryProvider` is `null` and no sync object is constructed.
- **Credentials: the refresh token is persisted in OS-backed storage, and no
  dependency was added for it.** The access token stays a field on
  `FocusTraceSyncApi` for its short life and is never written. The refresh token
  goes through `SyncCredentialStore`, whose Android implementation
  (`SecureSyncCredentialStore` -> `SecureCredentialStore.kt`) seals it with
  AES-GCM under an `AndroidKeyStore` key that never leaves the keystore, and
  keeps the ciphertext in a private `SharedPreferences` file excluded from both
  cloud backup and device-to-device transfer. `flutter_secure_storage` and
  `androidx.security:security-crypto` were both rejected: the platform already
  provides the primitive, and the latter is deprecated. This is what set
  `minSdk` to 23 - `KeyGenParameterSpec` is API 23 - which drops Android 5.x.
- **The credential is written synchronously.** `SecureCredentialStore` uses
  `commit()`, not `apply()`. `_adoptSession` stores the rotated token before
  returning, and that guarantee is only real if the value is on disk by then:
  the token the rotation replaced has already been consumed server-side, so a
  file still holding it would present a consumed token on the next launch and
  trip the replay detection in D10, revoking the session chain.
- **Every credential failure fails closed.** An absent, undecryptable or
  rejected refresh token all resolve to "not signed in": the native store
  deletes a value it cannot decrypt, a `401` on refresh clears the store, and a
  platform error on read is indistinguishable from no credential. Nothing
  retries a dead token, and no path leaves the app believing it is
  authenticated when it is not. A write that fails degrades to a session that
  ends with the process; it never fails the sign-in.
- **One refresh at a time.** Requests that see a `401` await a single in-flight
  rotation. Racing it would present the same refresh token twice, and the
  server's replay detection would revoke the whole session chain.
- **Deterministic rejections are not retried.** A `400` on a batch is counted
  and passed over, and the watermark advances past it, because resending the
  identical request is the loop 9.1 forbids. Those days stay local and
  authoritative; nothing is deleted to satisfy the remote contract. A transient
  failure instead leaves the watermark alone, so the next run re-offers the work
  and the server answers `DUPLICATE`.

Known limits of the Phase 2 slice, tracked in the plan rather than fixed here:
`display_name` is a fixed string because `Build.MODEL` needs a platform call
this stage does not add; a day with a `usage_snapshot_days` row is offered even
when it holds no app rows, but a versionless day with none is not; and a full
re-upload after an import loads every selected day into memory at once, which is
acceptable at this data scale (risk 4).

---

### 8.5 Android cross-engine execution boundary

Implemented by the cross-engine prerequisite, before Phase 5 scheduling.
`SyncRepositoryImpl` requires a `SyncExecutionGate`. Production injects
`AndroidSyncExecutionGate`, whose `focustrace/sync_execution` method channel
reaches one JVM `SyncExecutionGate` object shared by all engines in the process.
Source and merged Android manifests declare no separate process. Moving sync
to another OS process requires revisiting this assumption.

Every engine that uses sync must attach `SyncExecutionGateChannel(engine)` once,
before running its sync entrypoint. It needs no Activity. MainActivity attaches
the foreground engine through `attachSyncChannels`; Phase 5 uses the same
registration for its headless engine.

The repository holds one lease across each complete sync run (session check,
selection, registration, refresh, upload, watermark and success timestamp),
history request, sign-in, registration plus sign-in, and logout. Session reads
also participate because a failed secure read can clear an unreadable token.
Installation-ID creation and opt-in writes use the same gate; sync calls the
private ID helper to avoid nested acquisition. API and credential helpers do
not acquire the gate themselves. The ViewModel guard remains immediate UI
feedback, not the correctness boundary.

Acquisition waits asynchronously in FIFO order. No thread waits for network
work, no polling, timeout or persistent lock exists. A native client identity
bound to the engine and a fresh per-acquisition lease must both match on
release. Foreign, duplicate and stale releases do not unlock another operation.
Dart releases in `finally`, including errors. Gate unavailability fails closed.

Whichever operation acquires first completes its session mutation first.
On acquisition the API reconciles its memory-only access-token cache with the
current persisted refresh credential, discarding stale access after another
engine rotates, replaces or clears the session. Logout clears local credentials
and its cache in `finally`; a subsequent sync sees no session. No new credential
store or credential-bearing gate arguments are introduced.

Engine teardown stops new gate calls and posts native ownership/queue cleanup
to the platform loop after the synchronous teardown callback returns, rather
than granting another engine while the old engine is still being destroyed.
The channel also retires its client on engine restart. Process death destroys
the gate naturally. Future worker cancellation must finish the operation or
destroy its engine, never merely release a lease while Dart continues running.
As before, process/engine death during a server refresh can lose its response
and require sign-in; the gate does not roll back remote HTTP effects.

---

### 8.6 Android periodic synchronization

WorkManager invokes `SyncWorker`, which creates an Activity-free Flutter engine,
attaches the shared sync/credential/gate channels, and runs the retained
`backgroundSync` Dart entrypoint. A fresh ProviderContainer uses the existing
production repository and API. The background SQLite connection is explicitly
non-singleton so closing it cannot close the foreground engine's connection.
No HTTP client, upload selection or authentication logic is implemented in Kotlin.

The unique periodic work `focustrace_periodic_sync_v1` uses KEEP, a six-hour
implementation-policy interval, and only NetworkType.CONNECTED. Opt-in writes
and logout reconcile scheduling under the same repository gate; logout retains
the existing policy of disabling sync. Startup reconciles persisted consent to
repair interrupted scheduling and enroll previously opted-in installations.
It never changes consent. Background sync checks consent again inside the whole
logical run's lease. Existing manual UI eligibility remains unchanged.

Uploads and successful no-ops complete successfully. Signed-out, revoked,
disabled and deterministically refused runs also complete without retry.
Transport failures and HTTP 408/429/500/502/503/504 request exponential backoff
starting at 30 minutes, capped at three retries per period. Other failures,
including unknown bugs, return failure without retry. Periodic work remains
eligible at the next cadence; failure is not a Settings error notification.

Each invocation owns an in-memory, main-thread lifecycle:
`STARTING -> READY -> AUTHORIZED -> RUNNING -> DRAINED -> COMPLETED -> CLOSED`.
READY follows Dart bindings, provider construction, native channel registration
and a successful database-plugin probe (no connection or credential is opened).
Dart awaits a boolean authorization reply before calling the repository. READY
alone cannot acquire the gate. Unconfigured builds complete without RUNNING.

A 60-second startup deadline covers asynchronous loader initialization, Dart and
plugin readiness, and the interval between authorization and gate admission.
This allows generous cold-start time; it is not a network/sync timeout. The gate
channel admits exactly one background acquisition, only in AUTHORIZED, and
changes the lifecycle to RUNNING **before** queuing or granting its lease. That
is the exact boundary where the engine owns or may later own the gate. The
deadline is disabled until the validated owner releases normally. No native
cleanup forges a release. Foreground gate behavior and caller/lease validation
are unchanged.

After release, DRAINED permanently closes admission and allows another 60 seconds
for Dart resource disposal and its final result. A missing completion then fails
safely without an active or possible future lease. Startup/disposal deadlines
and initialization exceptions map to failure, without WorkManager retry. Ordinary
transport/server retry mapping remains unchanged. A premature completion during
RUNNING is ignored. Worker cancellation before admission closes immediately;
after admission it drains protected work and awaits completion (or the bounded
post-release wait). WorkManager discards the stopped result.

One finally path closes admission, cancels both deferred waits and the deadline,
detaches completion/platform handlers and destroys the owned engine once. Engine
teardown retires its gate caller through section 8.5's existing listener. Late
loader/READY/completion callbacks cannot revive an invocation or affect another
engine's messenger. No lifecycle state is persisted and no completed engine is
stored globally. No engine is destroyed while its execution owns or may own the
gate. Active protected work is intentionally drained without a blanket timeout;
as with Android lifecycle delivery generally, deadlines require a responsive
platform looper. Process death retains section 8.5's refresh-response-loss
limitation. No credentials or error strings enter the handshake, WorkManager
input/output or new logs; sync remains silent.

Device registration reads Android Build.MODEL as cosmetic display text. The
random UUID v4 remains the sole installation identity.

---

## 9. REST API contract

All endpoints under `/api/v1`. JSON in, JSON out. Errors use RFC 9457
`application/problem+json` via Spring's `ProblemDetail`.

```text
POST /api/v1/auth/register        {email, password}                -> 201 {userId}
POST /api/v1/auth/login           {email, password}                -> 200 {accessToken, expiresIn, refreshToken}
POST /api/v1/auth/refresh         {refreshToken}                   -> 200 {accessToken, expiresIn, refreshToken}
POST /api/v1/auth/logout          {refreshToken}                   -> 204 (idempotent, see D10;
                                  requires a bearer access token - baseline section 13)

POST /api/v1/devices              {deviceId, displayName, platform} -> 200/201 {device}
GET  /api/v1/devices                                                -> 200 [{device}]

PUT  /api/v1/sync/usage-days      {deviceId, days:[...]}            -> 200 {results:[...]}

GET  /api/v1/usage?from=&to=[&deviceId=]                            -> 200 {days:[...]}
```

`POST /devices` is idempotent on `deviceId`: a new UUID is created under the caller
(201); re-registering an installation the caller already owns updates `display_name`
/ `last_seen_at` and returns 200. Registering a `deviceId` owned by someone else
returns 409 without disclosing the owner and without writing anything (D12, D16
scope limit). Ownership never moves: no statement assigns `user_id` to an existing
row.

Device contract details (Step 3): `deviceId` must be a version-4 (random) UUID;
`platform` is `android` or `windows` and is fixed at first registration, so a
re-registration does not rewrite it; `displayName` is 1-100 UTF-16 units, not blank,
with no control characters and no unpaired surrogate. The response is
`{deviceId, displayName, platform, registeredAt, lastSeenAt}` with no owner field;
`GET` returns the caller's devices ordered by `registeredAt`. The endpoint reads and
writes through `JdbcClient` SQL (as `AuthSessions` does), so there is no `Device` JPA
entity to expose.

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

**Limits (Step 4, resolves D13/C3).** Every violation is `400` with the common
error model and zero writes. Unknown properties are `400`.

| Field / bound | Rule |
| --- | --- |
| request document | Jackson `spring.jackson.factory.constraints.read.max-document-length: 2097152` |
| `deviceId` | UUID of a device the caller owns; otherwise `404` (D16) |
| `days` | 1-31 entries, `localDate` unique within the request |
| total app rows | at most 1,000 across all days |
| `localDate` | ISO date, `2026-01-01` <= date <= UTC today + 1 (a device can be a day ahead; UTC+14 is exactly that) |
| `timezoneId` | non-blank, at most 64 UTF-16 units, resolvable by `ZoneId.of` |
| `snapshotVersion` | positive `int64` |
| `sourceStatus` | `partial`, `reconciled` or `imported`; `unavailable` is never uploaded |
| `apps` | required, 0-500 entries, `appKey` unique within the day |
| `appKey` | non-blank, at most 255 UTF-16 units |
| `appName` | non-blank, at most 200 UTF-16 units |
| `durationSeconds` | `[0, 90000]` (6.2) |
| `launchCount` | non-negative `int32` |

`appKey` and `appName` reject only what cannot be stored faithfully: NUL, which
PostgreSQL text cannot hold, and an unpaired UTF-16 surrogate, which the driver
would persist as `?`, so a retry would compare unequal. Other control characters
(tab, newline, ...) are stored verbatim. `displayName`'s broader rule is a device
contract and does not extend here. No Unicode normalization.

The document limit is a Jackson parser constraint counted in input units (bytes
for a servlet body) and checked at buffer granularity, not an exact HTTP byte cap.
It applies equally without `Content-Length`. The largest valid request is about
1.4 MiB (31 days, 1,000 rows, every string at its limit in 3-byte UTF-8). An
oversized document is the framework's generic `400`, like malformed JSON. The
`timezoneId` bound (added in Step 4; the column is unbounded `TEXT`) is an API and
storage limit with ample room for real zone IDs. Validity is decided by `ZoneId.of`,
not by the length.

The `2026-01-01` floor exists because no FocusTrace data predates 2026. It also
bounds how many dates a device can hold. It is not a storage quota; see the plan.

**Client obligations.** One invalid day fails the whole request, and a
deterministic failure repeats on every retry. A sync client must therefore:

- leave out days outside the date range (a clock that was wrong at boot can
  produce them) rather than send them;
- keep `appKey` within the bounds and deterministically sanitize `appName`
  (remove NUL, truncate to 200 UTF-16 units without splitting a surrogate pair),
  so a retry of the same day sends the same content;
- not retry an unchanged request after a `400`.

Filtering or sanitizing applies to the upload only. It never deletes or rewrites
the local record, which stays authoritative.

### 9.2 Upload response

```json
{
  "results": [
    { "localDate": "2026-09-17", "outcome": "APPLIED",   "storedVersion": 1758124800123 },
    { "localDate": "2026-09-16", "outcome": "DUPLICATE", "storedVersion": 1758038400000 },
    { "localDate": "2026-09-15", "outcome": "STALE",     "storedVersion": 1758000000000 },
    { "localDate": "2026-09-14", "outcome": "CONFLICT",  "storedVersion": 1757900000000 }
  ]
}
```

Per-day outcomes rather than a single status: the client learns exactly what
happened without a follow-up read, and the integration tests assert on this
directly. Exactly one result per submitted day, in request order. `storedVersion`
is the version the server holds after the request. `CONFLICT` was added in Step 4
(7.3).

**Version policy before a client ships.** The server trusts `snapshotVersion` as
the device's own ordering and makes divergence visible (`STALE`, `CONFLICT`) rather
than compensating with server-side versioning. Imported, legacy and Dart-written
days (7.2) need a client version policy that can neither regress below a version
already uploaded nor reuse the same version for changed content. That is a
prerequisite for the Flutter sync client, not a backend change.

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

**Implemented in Step 5** (`usage/UsageHistoryController`, `UsageDays.history`).
`from` and `to` are required ISO dates; a missing or malformed parameter, and a
malformed `deviceId`, are the framework's generic `400`.

| Rule | Behaviour |
| --- | --- |
| range | `to - from` must be 1 to 400 days. `to <= from` is `400`, not an empty result: `to` is exclusive, so such a request asks for nothing and is a client bug worth reporting. |
| ordering | Days ascending by `localDate`, then by `deviceId`; apps ascending by `appKey`. An unchanged stored day therefore always reads back identically. |
| `deviceId` | A predicate in the query, never a lookup. A device the caller does not own and a device that does not exist both yield `{"days": []}` - D16's "collections filter, they do not fail". Nothing runs before the query, so there is no side effect and no existence oracle. |
| apps | One `LEFT JOIN`, so a day whose snapshot has no app rows is returned with `"apps": []` instead of disappearing, and no day costs a second query. |

The 400-day cap bounds one response along the date axis only. It is not a
per-account storage bound: an account with many devices still gets one entry per
device per date. The storage bound and the authenticated per-user rate limits
remain release work; see the plan.

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
    │   │   ├── auth/       AuthController, AuthService, AuthSessions, AccessTokens, SecurityConfig, User, ...
    │   │   ├── device/     DeviceController, Devices
    │   │   ├── usage/      UsageUploadController, UsageHistoryController, UsageDays
    │   │   └── common/     ApiException, ApiExceptionHandler, RequestIdFilter, ProductionConfiguration
    │   └── resources/
    │       ├── application.yml
    │       └── db/migration/V1__baseline.sql, V2__auth_sessions.sql, V3__usage_duration_dst.sql
    └── test/
```

The tree above is the layout as built, corrected from the design sketch. Two
deviations are deliberate. There is no `sync/` package: `PUT /sync/usage-days` is
usage code and lives in `usage/` with the history read. And there are no entity or
`*Service` classes: one component per aggregate (`AuthSessions`, `Devices`,
`UsageDays`) owns that aggregate's SQL through `JdbcClient`, which is why no JPA
entity exists to leak through a controller.

Controllers -> services -> repositories -> entities. DTOs are records in the
package that owns the endpoint. **JPA entities are never returned from a
controller.** No interface with a single implementation, no service that only
forwards to a repository.

`server/` is a standalone Gradle build, not part of the Android `settings.gradle.kts`.
It must be possible to build the app without a JDK-for-server toolchain and vice
versa.

**Gradle over Maven**, Kotlin DSL, same build tool as `android/`. One build tool in
the repository is worth more than matching the Spring tutorial convention.

**Selected and pinned at bootstrap (2026-09-17): Java 21 (LTS) + Spring Boot 4.1.0
+ Gradle 9.5.1.** These are pins, not a claim about what is current today - re-check
before any upgrade. They supersede the "Spring Boot 3.5.x" written here during
design, per that paragraph's own instruction to pin the actual version at bootstrap
rather than trusting a version in a design document. Boot 4.1.0 requires Gradle
8.14+ or 9.x, so `server/` runs Gradle 9.5.1 while `android/` stays on 8.12 - the
two are separate builds, which is exactly why that is allowed.

Boot 4 renamed several starters. Use `spring-boot-starter-webmvc` (not `-web`) and
`spring-boot-starter-flyway`. Testcontainers 2.x likewise moved
`PostgreSQLContainer` to `org.testcontainers.postgresql` and made it non-generic.

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
| Auth | register, login, wrong password rejected, unauthenticated request to a protected route is 401, expired access token is 401, refresh rotation, reused refresh token revokes its own session. Per-decision expectations are listed with each decision in 5.1 and enumerated in the security baseline, section 18. |
| Authorization | User A reading User B's usage gets an empty result; User A uploading to User B's device gets 404 |
| Device | registration succeeds; re-registering the same installation UUID updates rather than duplicates; a UUID owned by another user is 409 |
| Validation | every section 9.1 bound at its accepted edge and one past it (negative duration, duration above 90000, 32 days, 501 apps, 1,001 rows, dates outside the range, duplicate `localDate` or `appKey`, unknown `timezoneId`, `unavailable` status, over-long and control-character strings, empty `days`) rejected with 400 and no rows written |
| Idempotency | upload a snapshot twice; assert row counts and totals identical to a single upload, and the second response is `DUPLICATE` |
| Supersede | upload version 1, then version 2 with different apps; assert only version 2's rows exist, app row count matches version 2, no accumulation, outcome `APPLIED` |
| Stale | upload version 2, then version 1; assert version 2 survives and outcome is `STALE` |
| Device isolation | Devices A and B, same user, same date; assert two independent `usage_days` rows and that the history response labels each one |
| Transaction safety | a database failure on the last day leaves zero rows from that batch; a failure after a day's app rows were deleted restores that day |
| Concurrency | real parallel requests: newer vs older, equal identical (`APPLIED` + `DUPLICATE`), equal differing (`APPLIED` + `CONFLICT`), overlapping batches in opposite order (no deadlock, no mixed app sets) |
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

3. **The watermark can miss days. Resolved in Phase 2.** A day mutated by
   something that does not advance `queried_at_ms` - a portable-data import -
   would never be selected again. Verified during implementation:
   `importPortableData` replaces `daily_app_usage` rows in place and advances no
   version. `_invalidateUsageRecovery` now resets `sync_usage_watermark_ms` to
   `0` and advances `sync_imported_version_ms` in the same transaction that
   clears `usage_snapshot_days` and rotates `usage_recovery_generation` (7.2,
   8.2), so the next run re-offers every day and the mutated ones apply.

4. **No local per-day upload state.** The watermark is a single scalar. Losing it
   causes a full re-upload, which is safe but heavy. Acceptable at this scale.

5. **An account is a new attack surface on sensitive data.** Mitigated by Argon2id,
   short access tokens, revocable rotating refresh tokens, query-level ownership
   scoping, no secret defaults, and TLS terminated in front of the service. The
   service refuses to start without a configured JWT secret.

6. **Email verification is absent in v1.** An address is never proven to belong
   to the account holder, which is also why duplicate registration discloses
   (D11). Rate limiting is no longer deferred: D15 puts per-source and
   per-account throttling on registration, login and refresh in Step 2.

7. **Assumption: one day per device is small.** Roughly 50-200 app rows. If some
   device produces more, the 500-app cap rejects it rather than degrading
   quietly.

8. **Assumption: Windows devices participate.** `platform` allows `windows`, but
   the Windows shell currently lives on the parked `feat/sync-server` branch. If
   Windows is dropped from scope, the `CHECK` constraint narrows to `android` and
   the `app_key` risk in item 2 disappears.

9. **`README.md` and `docs/privacy.html` are currently inaccurate about sync.**
   Tracked as a release blocker in section 11, not a backend task.
