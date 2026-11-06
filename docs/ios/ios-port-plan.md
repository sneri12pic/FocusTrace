# iOS port - plan

Goal: ship FocusTrace on iOS with the same Flutter UI, using Apple's Screen Time
APIs (FamilyControls, ManagedSettings, DeviceActivity) and app extensions for
enforcement and usage display. Android and Windows behaviour must not change.

Decisions that are implemented live in `ios-port-architecture.md`; current state
lives in `ios-port-progress.md`.

## Scope

- An iOS Runner app (Flutter host, Swift) plus four extensions:
  `FocusTraceMonitor` (DeviceActivityMonitor), `FocusTraceShield`
  (ShieldConfiguration), `FocusTraceShieldAction` (ShieldActionDelegate),
  `FocusTraceReport` (DeviceActivityReport).
- Shared Swift code in `ios/FocusTraceKit/`, compiled into every target: App
  Group rule store, shield controller, schedule mapper, and Codable models that
  mirror the JSON of `lib/src/domain/models/restriction_rule.dart`.
- Restrictions (block now, schedules and routines with weekdays, daily limits),
  Easy / Moderate / Hard friction through the existing Dart change guard, usage
  screens through DeviceActivityReport, and the iOS-equivalent of the extras
  (workouts, widget, backup).
- CI that builds the iOS app with all extensions on every push.

## Non-goals

- Exact feature parity with Android where iOS forbids it: no overlays, no
  Shorts/Reels detection, no raw per-app usage numbers in Flutter or SQLite (see
  the platform limits in the architecture document).
- Parental / child-device mode (`.child` authorization). FocusTrace authorizes
  `.individual` only.
- Cloud sync changes. iOS reuses whatever the backend-sync stage ships.
- Rewriting Dart features for iOS beyond the capability gating in phase 0.

## Phases

### Phase 0 - Dart platform capabilities

Introduce a `PlatformCapabilities` abstraction in Dart so screens and services
ask "can this platform do X" instead of checking `Platform.isAndroid`.

Acceptance criteria:
- Android and Windows behaviour unchanged; `flutter test` passes.
- Features iOS cannot provide (overlays, short-form video detection, raw usage
  lists) are hidden behind capabilities, not platform checks.

### Phase 1 - iOS shell and CI

Acceptance criteria:
- `ios/` exists with bundle id `com.stepandemianenko.focustrace`, display name
  "FocusTrace", deployment target iOS 16.0, Swift.
- The four extension targets exist in `Runner.xcodeproj` with correct product
  types, Info.plist extension points, entitlements (Family Controls + App
  Group) and minimal compiling stubs; they are embedded in Runner and do not
  link Flutter.
- `tool/ios/add_extension_targets.rb` recreates or repairs the project setup and
  is idempotent.
- CI job `ios-build` runs `flutter build ios --debug --no-codesign` on macOS and
  passes.
- `flutter analyze` and `flutter test` still pass.

### Phase 2 - Authorization, picking apps, blocking

- Method channel from Runner: request/inspect `AuthorizationCenter` status
  (`.individual`).
- Present `FamilyActivityPicker`; store the opaque selection in the App Group;
  Flutter receives only an id, a count and a display label.
- Block now, schedules and routines (including weekdays) mapped to
  `DeviceActivitySchedule`s; `ManagedSettingsStore` shields applied by the app
  and by the monitor at interval start/end.
- Shield and ShieldAction extensions show FocusTrace's block screen and handle
  its buttons.
- Friction Easy / Moderate / Hard enforced through the existing Dart change
  guard before any rule is relaxed.
- Routines are shared daily allowances (usage thresholds), so they move to
  phase 3 with daily limits; on iOS they are hidden until then.

Acceptance criteria:
- On a device with the Family Controls entitlement: authorize, pick apps, block
  now, schedule a weekday window; the shield appears and lifts on time, also
  with the app killed.
- Relaxing a Moderate or Hard rule goes through the same guard as on Android.
- Rule JSON written by Dart decodes in FocusTraceKit (unit-tested both ways).

### Phase 3 - Daily limits and nudges

- Turn on `PlatformCapabilities.dailyLimits` for iOS (daily-limit rules and
  routines in the UI).
- Daily limits and routine allowances as `DeviceActivityEvent` thresholds; the monitor shields the
  selection when the limit is reached and clears it at the interval end.
- Preferred-time nudges as local notifications from monitor threshold events:
  at limit - 5 min, at the limit, and every 10 min after.

Acceptance criteria:
- A 15-minute test limit shields on time with the app killed and resets the next
  day.
- The three nudge kinds fire once each at their thresholds and respect
  notification permission.

### Phase 4 - Usage screens

- `FocusTraceReport` scenes (daily total, per-app, hourly) rendered in SwiftUI.
- Embedded in Flutter screens through a `UiKitView` platform view hosting
  `DeviceActivityReport`.

Acceptance criteria:
- Home and usage-detail screens show the report view on iOS with matching date
  filters; nothing in Flutter or SQLite depends on iOS usage numbers.

### Phase 5 - Extras and release

- HealthKit workouts (iOS counterpart of Health Connect).
- WidgetKit status widget reading the App Group.
- Backup export/import through the share sheet.
- Settings and rules sync once backend sync is available.
- TestFlight distribution.

Acceptance criteria:
- Distribution entitlement for Family Controls granted by Apple for the app and
  all extensions.
- TestFlight build installed and smoke-tested on a physical device.

## Remaining work

- Phase 2 is implemented and builds in CI; its device acceptance criteria are
  unverified until a signed build runs on an iPhone.
- Phases 3-5.
- Request the Family Controls (Distribution) entitlement from Apple for the app
  and every extension bundle id before any TestFlight build.
- Configure an Apple developer team, App Group and provisioning profiles; CI
  builds without code signing until then.
