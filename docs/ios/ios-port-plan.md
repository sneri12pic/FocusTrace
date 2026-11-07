# iOS port - plan

Goal: ship FocusTrace on iOS with the same Flutter UI, using Apple's Screen Time
APIs (FamilyControls, ManagedSettings, DeviceActivity) and app extensions for
enforcement and usage display. Android and Windows behaviour must not change.

Decisions that are implemented live in `ios-port-architecture.md`; current state
lives in `ios-port-progress.md`.

## Scope

- An iOS Runner app (Flutter host, Swift) plus five extensions:
  `FocusTraceMonitor` (DeviceActivityMonitor), `FocusTraceShield`
  (ShieldConfiguration), `FocusTraceShieldAction` (ShieldActionDelegate),
  `FocusTraceReport` (DeviceActivityReport), `FocusTraceWidget` (WidgetKit).
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
- Cloud sync on iOS: the backend syncs usage history, which iOS cannot export
  (see the architecture's Cloud sync section). `server/` is not changed here.
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

- Turn on `PlatformCapabilities.dailyLimits` and `notificationsPermission`
  for iOS (daily-limit rules, routines, notification permission UI); show
  limits without usage numbers.
- Daily limits and routine allowances (shared over all included apps, plus
  member caps) as `DeviceActivityEvent` thresholds of one daily activity
  each; the monitor shields the selection when the limit is reached and the
  next day's interval start clears it.
- Limit warnings as Android's: a local notification five minutes before a
  daily limit or routine allowance.
- Preferred-time nudges as local notifications from monitor threshold events:
  amber at limit - 5 min, red at limit - 1 min and at the limit, and every
  10 min after. The Dart side (preferred limits in the restriction JSON)
  lives on the preferred-usage branch, not on develop; iOS decodes its wire
  format and plans the events once Dart sends it.

Acceptance criteria:
- A 15-minute test limit shields on time with the app killed and resets the next
  day.
- A routine's shared allowance shields every included app once their use
  together reaches it; a member cap shields that member only.
- The warning and the three nudge kinds fire once each at their thresholds
  and respect notification permission.
- Relaxing a reached Moderate or Hard limit goes through the same guard as on
  Android.

### Phase 4 - Usage screens

- `FocusTraceReport` scenes (today, hourly, week, month, appDetail) rendered
  in SwiftUI with Swift Charts.
- Embedded in Flutter screens (dashboard, Reports, usage details of a picked
  group) through a `UiKitView` platform view hosting `DeviceActivityReport`.
- Reached daily limits shown as blocked in Flutter, with Unblock now through
  the guard (follow-up from phase 3).

Acceptance criteria:
- Home and usage-detail screens show the report view on iOS with matching date
  filters; nothing in Flutter or SQLite depends on iOS usage numbers.

### Phase 5 - Extras and release (implemented; device and Apple steps open)

- HealthKit workouts through the shared `focustrace/health_connect` contract,
  "Apple Health" texts on iOS. Done.
- Backup export/import through the Files pickers, carrying picked app groups.
  Done.
- In-app language mirrored to iOS (`AppleLanguages`, extensions' locale).
  Done.
- WidgetKit restriction status widget reading the App Group. Done.
- Settings and rules sync: not possible with the current server (usage-only);
  documented, `cloudSync` stays off.
- Release prep: icon, launch screen, privacy manifests, Health usage string,
  manual TestFlight workflow, `ios-release-checklist.md`. Done; signing,
  entitlements approval and upload are the account owner's steps.

Acceptance criteria:
- Distribution entitlement for Family Controls granted by Apple for the app and
  the four Screen Time extensions.
- TestFlight build installed and smoke-tested on a physical device.

## Remaining work

- Phases 2-5 are implemented and build in CI; their device acceptance
  criteria are unverified until a signed build runs on an iPhone.
- Device verification still open (iPhone, iOS 16 and 17.4+):
  - Screen Time: authorization, picker, block now, weekday schedule with the
    app killed, daily limit and routine thresholds, warnings and nudges,
    shield texts, reports (phases 2-4 lists in the progress document).
  - Apple Health: the permission sheet, first 30-day import, a workout added
    or deleted in Health showing up on the next import, background delivery
    with FocusTrace closed, the access hint after denying.
  - Backups: export to Files / iCloud Drive and import back; import of an
    Android backup (iOS-less rules stay unenforced); import on a second iPhone
    (do restored app groups shield the same apps?).
  - Language: system pickers and permission sheets in the app language after
    a relaunch; shield/report/widget dates at once.
  - Widget: small and medium layouts, refresh at schedule boundaries and
    after a limit is reached with the app closed.
  - Launch screen and icon on device; App Store validation of the privacy
    manifests.
- Preferred usage time on iOS: Dart sends `preferredLimits` only after the
  preferred-usage work merges; it must then also let iOS pick apps for a
  preferred limit (category limits need an installed-app list iOS does not
  have).
- Account owner steps (`ios-release-checklist.md`): Apple Developer Program,
  six App IDs and the App Group, Family Controls (Distribution) for the five
  Screen Time bundle ids, HealthKit capability, signing team, App Store
  Connect record and privacy label, TestFlight secrets. CI builds without code
  signing until then.
- Cloud sync for iOS needs a server-side settings/rules sync first.
