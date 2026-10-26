# Health Connect integration: architecture

Implemented decisions only. Scope and open questions are in
`health-connect-plan.md`.

## Boundaries

Health Connect is never on the critical path. Usage tracking, restrictions,
blocking, schedules and the Flutter database do not read or depend on it. All
Health Connect code is native and isolated:

| File | Role |
| --- | --- |
| `HealthConnectStore.kt` | Settings (SharedPreferences `focustrace_health_connect`) and imported workouts (SQLite `focustrace_health_connect.db`). |
| `HealthConnectImporter.kt` | Availability, permissions and the import algorithm. One run at a time per process (mutex). |
| `HealthConnectWorker.kt` | `HealthConnectWorker` (periodic, 6 h) and `HealthConnectScheduler.reconcile`. |
| `HealthConnectBridge.kt` | `focustrace/health_connect` MethodChannel, permission requests through `MainActivity.onActivityResult`. |
| `HealthConnectRationaleActivity.kt` | Health Connect's privacy-policy link (action up to Android 13, `VIEW_PERMISSION_USAGE` alias on 14+). Opens the published privacy policy. |

Flutter: `HealthConnectChannel` (platform edge), `HealthConnectStatus` /
`ImportedWorkout` (domain models), `HealthConnectViewModel` (shared by Settings
and onboarding), `HealthConnectScreen`, the Settings tile and the onboarding
page. `healthConnectSupportedProvider` hides everything off Android.

Settings live natively so the worker can recheck them without a Flutter engine.
Every channel call returns the full status, so Flutter never caches it.

## Library and SDK

- `androidx.health.connect:connect-client:1.1.0` (stable). It declares minSdk
  26; the app is minSdk 24, so the manifest uses
  `tools:overrideLibrary="androidx.health.connect.client"` and the importer
  reports Health Connect unavailable below API 26. The Health Connect app
  itself needs Android 9+; `getSdkStatus` covers that.
- connect-client brings full Guava at runtime, which replaces WorkManager's
  `listenablefuture` with the empty stub at compile time. `compileOnly` Guava
  31.1-android (the version already on the runtime classpath) keeps
  `ListenableFuture` resolvable for existing code. No new runtime dependency.
- Tests use `connect-testing:1.0.0-alpha03` (`FakeHealthConnectClient`).

## Permissions

- `android.permission.health.READ_EXERCISE`: requested when the user turns
  the integration on.
- `android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND`: requested only
  when the user turns on automatic import, and only if
  `FEATURE_READ_HEALTH_DATA_IN_BACKGROUND` is available.
- No write permission, no route permission, no history permission.

Permissions are rechecked at the start of every run. A `SecurityException`
mid-run is reported as `permissionMissing`.

## Data imported

Per `ExerciseSessionRecord`: Health Connect record id (primary key), source
package (`metadata.dataOrigin`), exercise type, title, start and end instants,
start zone offset, last-modified time. The UI shows title (or a localized
category from the exercise type), start in the device's current time zone,
duration and the source app's label. Hevy-specific details such as sets and
weights are not available through Health Connect and are not shown.

## Import algorithm

1. Stop if disabled. Resolve the client; report `unavailable` or
   `updateRequired` if there is none.
2. Require `READ_EXERCISE`; a background run also requires the background
   feature and permission (`backgroundPermissionMissing` otherwise).
3. With a stored changes token: page through `getChanges`. Upsertions replace
   by id unless `lastModifiedTime` is unchanged; deletions delete by id;
   records whose origin is FocusTrace's own package are skipped.
4. Without a token, or when Health Connect reports `changesTokenExpired`:
   take a new token first, then read every session in [now - 30 days,
   now + 1 day), upsert each and delete local rows in that window that Health
   Connect no longer has. Older local rows are kept.
5. Save the token only after the run completed. An interrupted run leaves the
   old token, and replaying is safe because every write is keyed by record id.
6. Before every write batch and before saving the token the importer checks
   that the integration is still on; turning it off mid-run aborts without
   recording an outcome.

Outcomes: `imported` (n added, updated or removed), `noNew`, `unavailable`,
`updateRequired`, `permissionMissing`, `backgroundPermissionMissing`,
`failed`. Only `imported` and `noNew` update "last successful import".

Late-arriving records (a source app syncing days later) arrive through the
change log regardless of their start time. Time zones: instants are stored in
UTC with the record's own offset; display uses the device's zone.

## Turning off and deleting

- Off: `enabled = false`, periodic work cancelled. The worker also checks the
  flag and cancels itself. Imported workouts stay; the screen says so and that
  the system permission and Health Connect data are unchanged, with a link to
  Health Connect's own management screen.
- "Delete imported workouts" clears the table and the changes token.
- Settings > Delete local data also turns the integration off and deletes
  imported workouts.

## Privacy and backups

Health data is kept outside every existing transfer: not in the Flutter
database (so not in cloud sync or the portable backup) and excluded from
Android Auto Backup and device transfer in `backup_rules.xml` and
`data_extraction_rules.xml`.
