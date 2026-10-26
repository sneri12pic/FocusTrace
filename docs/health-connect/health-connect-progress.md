# Health Connect integration: progress

Newest entry first.

---

Date: 2026-10-26
Agent: Claude Code
Goal: Optional Health Connect integration, v1: exercise-session import.

Completed: Read-only import of exercise sessions (including Hevy workouts) with
manual "Import now" and opt-in automatic import every 6 hours; Settings screen
(Activity & data > Health Connect) with status, last successful import, last
outcome, revoked-access and background-blocked warnings, a link to Health
Connect's access management, the imported workouts with their source app, and
"Delete imported workouts"; an optional onboarding page (Connect / Not now)
that reuses the Settings view model; "Delete local data" now also turns the
integration off and deletes imported workouts. Strings in all seven languages.
Privacy policy section and Play Console declarations written.

Files materially changed: `HealthConnectStore.kt`, `HealthConnectImporter.kt`,
`HealthConnectWorker.kt`, `HealthConnectBridge.kt`,
`HealthConnectRationaleActivity.kt`, `MainActivity.kt`, `AndroidManifest.xml`,
`backup_rules.xml`, `data_extraction_rules.xml`, `app/build.gradle.kts`;
`health_connect.dart`, `health_connect_channel.dart`,
`health_connect_view_model.dart`, `health_connect_screen.dart`,
`settings_screen.dart`, `onboarding_screen.dart`, `providers.dart`, ARBs;
`docs/privacy.html`, `docs/releases/PLAY_RELEASE.md`.

Verification:
- PASS `dart format --set-exit-if-changed lib test`, `flutter analyze`,
  `flutter test` (372, 1 skipped; new `health_connect_test.dart` and an
  onboarding skip test in `widget_test.dart`).
- PASS `gradlew :app:testDebugUnitTest` (new `HealthConnectImporterTest`, 7
  tests against `FakeHealthConnectClient`: 30-day first import with source and
  zone offset, no-new on rerun, source update, late arrival, deletion, disabled
  integration reads nothing, revoked access keeps data, background run without
  background permission, own-package records skipped, re-reconcile after
  clearing) and `gradlew :app:lintDebug`.
- Not covered by tests: deletion through a `DeletionChange` (connect-testing
  1.0.0-alpha03 emits none; the same deletion is covered through the reconcile
  path that also handles an expired token), the permission dialogs, and the
  WorkManager schedule.
- UNAVAILABLE: device verification. No phone was connected over ADB, so no
  real Health Connect or Hevy workout was tested.

Decisions made: see `health-connect-architecture.md`. Export is not shipped:
FocusTrace owns no health data, and screen time is not a Health Connect type.

Remaining:
- On a device: enable, deny, grant, Import now with a Hevy workout, edit and
  delete it in Hevy and re-import, revoke in Health Connect, automatic import
  after 6 h, turn off mid-import, onboarding connect and skip.
- Play Console health apps declaration before the first release with this.
- Export use case (open question in the plan).

Risks / unresolved questions: connect-client 1.1.0 declares minSdk 26 and is
overridden for the app's minSdk 24; the importer refuses to run below API 26.
Google reviews Health Connect declarations; a rejection would block the
release that contains it.

Relevant commit: see `git log` on `feature/health-connect`.
