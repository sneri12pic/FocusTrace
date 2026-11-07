# iOS port - architecture

Records decisions that are implemented. Plan and phases: `ios-port-plan.md`.

## Targets

All targets live in `ios/Runner.xcodeproj`.

| Target | Product type | Bundle id | Purpose |
| --- | --- | --- | --- |
| `Runner` | application | `com.stepandemianenko.focustrace` | Flutter host app |
| `FocusTraceMonitor` | app-extension | `com.stepandemianenko.focustrace.monitor` | DeviceActivityMonitor (`com.apple.deviceactivity.monitor-extension`) |
| `FocusTraceShield` | app-extension | `com.stepandemianenko.focustrace.shield` | Shield look (`com.apple.ManagedSettingsUI.shield-configuration-service`) |
| `FocusTraceShieldAction` | app-extension | `com.stepandemianenko.focustrace.shieldaction` | Shield buttons (`com.apple.ManagedSettings.shield-action-service`) |
| `FocusTraceReport` | extensionkit-extension | `com.stepandemianenko.focustrace.report` | DeviceActivityReport (`com.apple.deviceactivityui.report-extension`) |

- The three app extensions declare `NSExtensionPointIdentifier` and
  `NSExtensionPrincipalClass` (`$(PRODUCT_MODULE_NAME).<Class>`) under
  `NSExtension` and are embedded by Runner's "Embed Foundation Extensions" phase
  (PlugIns/).
- `FocusTraceReport` follows Xcode's own Device Activity Report template: an
  ExtensionKit extension with an `@main DeviceActivityReportExtension`, the
  extension point under `EXAppExtensionAttributes`, embedded by "Embed
  ExtensionKit Extensions" into `$(EXTENSIONS_FOLDER_PATH)` (Extensions/).
- Both embed phases sit before Flutter's "Thin Binary" script phase; after it,
  Xcode reports a dependency cycle in Runner.
- iOS deployment target 16.0 (project level, every extension, the Podfile and
  `Flutter/AppFrameworkInfo.plist`). Swift 5.

## Build configuration boundaries

- Flutter's `Flutter/Debug.xcconfig` and `Flutter/Release.xcconfig` (which also
  include CocoaPods) are the base configurations of Runner only. The Podfile
  integrates only `Runner` / `RunnerTests`.
- Extensions use `ios/Config/Extension.xcconfig`, which includes only
  `Flutter/Generated.xcconfig` (optional include) so `FLUTTER_BUILD_NAME` /
  `FLUTTER_BUILD_NUMBER` give every extension the app's version. Extensions
  never link Flutter or pods and set `APPLICATION_EXTENSION_API_ONLY = YES`.
- Every target has Debug, Release and Profile configurations.
- System frameworks are linked explicitly. Every target links FamilyControls,
  ManagedSettings and DeviceActivity (FocusTraceKit uses them); in addition
  Runner - SwiftUI, UserNotifications; Monitor - UserNotifications; Shield -
  ManagedSettingsUI; ShieldAction - UserNotifications; Report - SwiftUI,
  Charts.

## Shared code: FocusTraceKit

`ios/FocusTraceKit/*.swift` is a plain folder whose files are added to the
Sources phase of Runner and all four extensions (no framework target). Code
there must be extension-safe. Every extension therefore also links
FamilyControls, ManagedSettings and DeviceActivity.

| File | Frameworks | Contents |
| --- | --- | --- |
| `AppGroup.swift` | Foundation | Suite name and `UserDefaults` accessor |
| `RestrictionModels.swift` | Foundation | Codable mirror of the rule JSON, time logic |
| `RestrictionChangeGuard.swift` | Foundation | Port of `RestrictionChangeGuard.kt` |
| `RestrictionStore.swift` | Foundation | App Group store, `RestrictionSync` (sync validation) |
| `ScheduleMapper.swift` | Foundation | Rules to DeviceActivity monitoring plans, activity budget |
| `UsageEvents.swift` | Foundation | Usage-threshold activities (limits, routines, preferred usage), reached keys, notification texts |
| `ShieldPlanner.swift` | Foundation | Shield blocks (rule, routine allowance, routine member cap) and whether each holds |
| `ShieldStrings.swift` | Foundation | Block screen and notification texts |
| `UsageReportModels.swift` | Foundation | Report kinds/ranges, hourly/daily buckets, report texts and durations, reached-limit usage |
| `ScreenTimeEnforcement.swift` | FamilyControls, ManagedSettings, DeviceActivity | Selection codec, `ShieldController`, `ActivityScheduler` |

The Foundation-only files are unit-tested without Xcode:
`tool/ios/run_kit_tests.sh` compiles them with `tool/ios/kit_tests/main.swift`
on the macOS CI host and decodes `test/fixtures/ios_restriction_configuration.json`,
which `test/ios_restriction_fixture_test.dart` keeps equal to what Dart's
`encodeRestrictionConfiguration` produces. Swift re-encodes it to the same
JSON, so the format is checked in both directions.

Runner-only Swift (UIKit, Flutter): `Runner/FocusTraceChannels.swift`,
`Runner/ActivityPicker.swift`, `Runner/SelectionIconsView.swift`,
`Runner/UsageReportView.swift`, listed in
`RUNNER_SOURCES` of the project script.

## Restrictions on iOS

### Channels

| Channel | Method | Behaviour |
| --- | --- | --- |
| `focustrace/usage` | `syncRestrictions(json)` | `RestrictionSync.apply`: every removed or changed rule must pass the change guard, else `RESTRICTION_LOCKED` and nothing is stored (as Android). A limit, routine or member cap whose thresholds changed, or that is no longer in the configuration (deleted, routine paused), forgets that it was reached today. Then unreferenced selections older than a day are dropped, shields reconciled, monitoring updated. |
| | `readRestrictionConfiguration` | The JSON last stored, verbatim (or null). |
| | `requestRestrictionChange({appKey, type})` | Guard with `request: true`; "allowed" / "cooldown" / "hard"; "allowed" when no such rule. |
| | `hasNotificationsPermission`, `requestNotificationsPermission` | `UNUserNotificationCenter` (alert, sound); also stored in the App Group for the shield. |
| | `takeRestrictionEvents` | Block events the shield extension recorded, then forgotten (only those returned; both sides hold the `events` App Group file lock). |
| | `readReachedLimits` | `{appKey: seconds}` for daily-limit rules the monitor recorded as reached today; seconds = the limit. |
| `focustrace/screen_time` | `authorizationStatus`, `requestAuthorization` | `AuthorizationCenter`, `.individual`; "notDetermined" / "denied" / "approved". |
| | `pickSelection({selectionId?, doneLabel, cancelLabel})` | `FamilyActivityPicker` in a `UIHostingController`; returns `{selectionId, appKey, appCount, categoryCount, webDomainCount}` or null when cancelled or empty. With `selectionId` it edits that selection, refused (`RESTRICTION_LOCKED`) while a rule using it is protected. |
| | `selectionSummary({selectionId})` | Counts of a stored selection, or null. |
| | `setShieldStrings({strings})` | Block screen texts from the ARB files. |
| platform view `focustrace/selection_icons` | creationParams `{selectionId, maxIcons, iconSize}` | `Label(token)` icons of a selection plus "+N". |
| platform view `focustrace/usage_report` | creationParams `{context, range, date, selectionId?, dark}` | `DeviceActivityReport` (see Usage reports). Registered in AppDelegate. |

Every other `focustrace/usage` method answers `notImplemented`;
`IosUsageDataSource` never calls them (usage methods return empty / false).

### Data model

- A rule whose apps were picked natively has `appKey = 'ios-sel:<uuid>'` and the
  name the user typed as `appName`. The `FamilyActivitySelection` is stored
  JSON-encoded in the App Group under its uuid; Flutter never sees tokens.
- App Group keys (`RestrictionStore`): `ft.restrictions.json` (Dart's JSON,
  verbatim), `ft.selection.<id>` / `ft.selectionCreated.<id>`,
  `ft.shield.rules` (rule keys shielded now), `ft.shield.stores`,
  `ft.events`, `ft.shield.strings`, `ft.notifications.authorized`, the
  guard's `ft.change:<appKey>:<type>:rule|ready`,
  `ft.restrictions.generation` (bumped by every sync and selection write),
  `ft.shield.displayed` (encoded app/web-domain token -> block keys the block
  screen listed, newest 200), and for usage thresholds
  `ft.limits.reached` (block key -> day it was reached), `ft.limits.notices`
  (notices posted today) and `ft.monitor.plans` (signature per monitored
  activity).
- Cross-process read-modify-write sequences hold an exclusive `flock` on
  `ft.<name>.lock` in the App Group container (`AppGroup.withLock`): `shields`
  (reconcile) and `events` (record/take block events).
- Routine members and preferred limits refer to selections by the same
  `ios-sel:<uuid>` app keys; such a selection is kept while any rule, routine
  or preferred limit refers to it. Dart sends only enabled routines with a
  limit, so it also sends `routineAppKeys` (every routine's `ios-sel:` keys,
  paused ones included; only when non-empty, Android ignores it), which keeps
  a paused routine's selections for when it is turned on again.
- `preferredLimits: [{limitMinutes, apps}]` (wire format of the
  preferred-usage work, Android `PreferredLimit`) is decoded and planned when
  present and re-encoded only when non-empty. Dart on develop does not send it.

### Enforcement

- One named `ManagedSettingsStore` per block (`ShieldPlanner`): per rule
  (`ft.<type>.<selectionId>`), per routine allowance (`ft.routine.<id>`,
  shielding every included member's selection together) and per routine
  member cap (`ft.routineApp.<id>.<selectionId>`). iOS shields an app while
  any store does, so lifting one block never unblocks an app another still
  blocks.
- `ShieldController.reconcile` evaluates every block with the same time logic
  as Dart/Kotlin (`RestrictionRule.isBlocked`, ISO weekdays, overnight tails
  belong to the start day) and applies or clears each store. A daily limit,
  routine allowance or cap holds when the monitor recorded it reached today
  (`ft.limits.reached`, day in the device calendar); for the time logic and
  the change guard a reached limit counts as usage = limit, else 0. The app
  runs it after every sync and whenever it becomes active; the monitor
  extension runs it on `intervalDidStart`, `intervalWillEndWarning` and
  `intervalDidEnd`, evaluating 30 s ahead because callbacks may come slightly
  early (so the 00:00 start also lifts yesterday's reached limits), and on
  `eventDidReachThreshold`. The app and the monitor may reconcile at once:
  the `shields` lock serializes them, and a reconcile that sees
  `ft.restrictions.generation` change while applying runs again (at most
  three passes), so shields from an older configuration never stay.
- `ScheduleMapper` makes sure the monitor wakes at every boundary:
  block-now = one non-repeating interval from now to `untilMs`; schedule = one
  daily interval, split into `start-23:59` and `00:00-end` over midnight.
  Weekdays are not encoded in the activities (that would cost one per day);
  the reconcile checks them. Intervals shorter than DeviceActivity's 15-minute
  minimum are widened and the lost boundary is hit with `warningTime`.
- Usage thresholds (`UsageEvents`): one repeating `00:00-23:59` activity per
  daily-limit rule (`ft.limit.<selectionId>`), enabled routine
  (`ft.routine.<id>`) and preferred limit (`ft.preferred.<hash>`), with
  `DeviceActivityEvent`s whose threshold is minutes of use since 00:00 of the
  event's selections (on iOS 17.4+ with `includesPastActivity`, so earlier use
  today counts after a restart):

  | Activity | Event | Minutes | Monitor does |
  | --- | --- | --- | --- |
  | limit | `warning` | limit - 5 | notification "{name} limit almost reached" / "Blocking starts in about 5 minutes." (Android's texts) |
  | limit | `reached` | limit | records it reached, reconciles (shield until the day ends) |
  | routine | `warning` | limit - 5, included apps together | routine warning notification |
  | routine | `reached` | limit, included apps together | shields every included member |
  | routine | `cap.<selectionId>` | member cap | shields that member |
  | preferred | `amber`, `red`, `limit`, `over.<n>` | limit - 5, limit - 1, limit, limit + n (n = 10, 20, ... 120) | notification "5 min left" / "1 min left" / "You've reached your time" / "n min over" |

  For a limit of five minutes or less the warning (and amber) fires after the
  first minute; thresholds after 23:59 are dropped. Daily limits apply every
  day, as on Android (the editor sets no weekdays for them; Kotlin ignores
  them). Members whose app key is not an `ios-sel:` selection are ignored.
- Notifications are posted by the monitor extension, at most once per
  activity, event and limit minutes per day (a restarted activity re-reports
  passed thresholds; a limit raised the same day warns again, as Android's
  key holds the limit), with one identifier per activity so a newer notice
  replaces the previous one. No warning is posted for a limit or routine
  already reached today, and the reached event removes a delivered warning.
  Without permission iOS drops them; blocking never depends on them.
- Activity budget: at most 20 activities, in this order: block-now rules
  (soonest end first), daily limits and routines, schedules whose weekday is
  today (or that block now), other schedules, preferred limits. The order is
  decided whenever the app reschedules (after a sync, when it becomes active).
  `ActivityScheduler` keeps an activity running when its signature (plan plus
  a checksum of each selection its events count) is unchanged and only stops
  and restarts the ones that changed, so a limit's day is not reset by an
  unrelated edit.
- The change guard is enforced natively with Android's semantics and result
  strings; Dart's `RestrictionsViewModel` is unchanged. Routines are not
  guarded, as on Android.

### Block screen

- `FocusTraceShield`: title = the app's `localizedDisplayName` (or the rule
  name), subtitle = one line per blocking rule or routine ("Temporary block
  until 15:00 · Social", "Daily app limit reached · Games", "Study: shared
  allowance reached", "Study: app limit reached · Games"), FocusTrace colours
  (#070A10 background, #5BC0EB accent), "Leave" primary button. It records one
  block event per app key per minute for Flutter, with Android's reasons
  (`dailyLimit`, `routineLimit:<id>`, `routineAppLimit:<id>`, ...).
- `FocusTraceShieldAction`: primary closes the app. A shield cannot open the
  host app, so the secondary button ("Unblock in FocusTrace") is offered only
  for Easy/Moderate rules and routines and only when notifications are
  allowed; it posts a local notification that opens FocusTrace, then closes
  the app. The action extension gets only the app's (or web domain's) token,
  which is in no selection when the app was shielded through a picked
  category, so it uses the blocks the block screen recorded for that token
  (`ft.shield.displayed`) and falls back to matching selections.

### Flutter

- `PlatformCapabilities.ios`: `nativeUsageReports`, `screenTimeAuthorization`, `nativeAppPicker`,
  `appBlocking`, `dailyLimits`, `notificationsPermission` (no
  `usageNumbersInFlutter`). Daily limits, routines and the notifications
  permission tile/prompt therefore appear as on Android. Where
  `usageNumbersInFlutter` is off, limit rules and routines show their size
  only: no progress bar, no "used", "left" or "today" numbers (restrictions
  screen rule and routine tiles, routine details).
- Routines on iOS hold picked groups: the candidates are the `ios-sel:` keys
  of rules and routines under their names (`iosRoutineCandidates`), and the
  routine editor and the add-apps sheet offer "Choose new apps", which runs
  Apple's picker and the name dialog without creating a rule
  (`pickIosAppGroup`).
- Onboarding's access page shows one Screen Time tile on iOS; the restrictions
  screen shows a Screen Time card until authorized, picks apps with
  `createIosRestriction` (authorize, picker, name dialog, usual editor) and
  draws selection icons through `SelectionIcons` (letter avatar elsewhere).
- Shield and notification texts come from the ARB files (`shield*`,
  `routineReason*` keys), sent by `syncShieldStrings` when the restrictions
  screen's locale changes and before each pick; texts with a number are sent
  pluralized per count (`limitWarningBody.1-5`, `nudgeLeft.1-5`,
  `nudgeOver.10-120`). English defaults live in `ShieldStrings.swift`.

## Usage reports

- Usage numbers exist only in `FocusTraceReport`. The host
  (`Runner/UsageReportView.swift`) maps creationParams to
  `DeviceActivityReport(Context(context), filter:)`: `range` today = hourly
  segments of the day of `date`, week/month = daily segments of the 7/30
  days ending with it; `users: .all`, devices iPhone and iPad; with
  `selectionId` the filter holds that selection's apps, categories and web
  domains (a missing or empty selection shows "no data", never all usage).
  `dark` sets the hosting controller's interface style.
- Scenes (`UsageReportKind`, same names on both sides): `today` (24 hourly
  dial slices, tap for an hour; pickups, notifications, most active time;
  "Current list" with category chips, 10 apps), `hourly` (hour bars),
  `week`/`month` (total, daily average, active days; day bars; 8 most used
  apps), `appDetail` (totals and dial for today, or totals and day bars; 6
  apps of the group). Each scene builds a `UsageSnapshot` (at most 60 apps
  for today, 8 or 6 elsewhere; no images beyond `Label(token)`).
- Colours are hard-coded in `ReportPalette.swift` from Flutter's theme
  (light and dark). Texts: Dart sends `report.*` keys (and `report.locale`)
  in the `setShieldStrings` map; the extension reads them from the App Group
  (`ReportStrings`), English otherwise. Durations use templates of the
  `compactDuration` ARB strings.
- Flutter (`PlatformCapabilities.nativeUsageReports`, iOS):
  `IosUsageReportView` gives each report a fixed height
  (`IosUsageReportView.heightFor`, kept in step with the SwiftUI layouts;
  Dynamic Type capped at Large there) and `IosUsageReportGate` shows a
  Screen Time card until authorized. Dashboard: today + hourly for the
  selected day (header without the tracked total). Reports: Weekly/Monthly
  only, native report plus the restriction activity card. Usage details:
  `IosSelectionUsageScreen` (Today / 7 days / A month) for `ios-sel:` keys,
  opened from a rule's "Usage" menu entry or a routine member. The
  restrictions screen hides "Choose apps to limit" and busiest hours.
  Taps inside a report cannot navigate Flutter.
- Reached limits: `RestrictionsViewModel` adds `readReachedLimits` to
  today's usage (`withReachedLimits`) and to `unblockAppNow`, so limit
  tiles show "Blocked until" and Unblock now goes through the native guard
  and removes the rule, as on Android.

## Entitlements and App Group

Each target has `<Target>/<Target>.entitlements` (Runner:
`Runner/Runner.entitlements`) set through `CODE_SIGN_ENTITLEMENTS`, with:

- `com.apple.developer.family-controls` = true
- `com.apple.security.application-groups` = `group.com.stepandemianenko.focustrace`

## Editing the Xcode project without a Mac

`tool/ios/add_extension_targets.rb` (Ruby + the `xcodeproj` gem) owns every
project change above: deployment target, Runner entitlements, FocusTraceKit
membership, the extension targets, their build settings, frameworks, embed
phases and target dependencies. It is idempotent: it finds targets, groups and
files by name, re-applies build settings, and writes Info.plist / entitlements
files only when missing (so hand edits to those survive). A second run leaves
`project.pbxproj` unchanged.

To add a FocusTraceKit file: create it under `ios/FocusTraceKit/` and re-run the
script. To change extension settings: edit the script and re-run it; do not hand
edit `project.pbxproj` for anything the script manages.

```bash
gem install xcodeproj
ruby tool/ios/add_extension_targets.rb
```

## CI

Job `ios-build` in `.github/workflows/ci.yml` (macos-15, 40 min): Flutter
3.32.2, `flutter pub get`, `flutter build ios --debug --no-codesign`, then a
check that every extension is embedded (PlugIns/ or Extensions/) and does not
link Flutter (`otool -L`), then the FocusTraceKit unit tests
(`tool/ios/run_kit_tests.sh`, also when the build failed). When the build
fails, a step re-runs `xcodebuild` to list every Swift error. It is the
only place Swift is compiled; the developer machines are Windows/Linux. Code
signing is off, so the build proves compilation and project wiring, not
entitlement provisioning.

## Known platform limits

- Apps, categories and web domains chosen in `FamilyActivityPicker` are opaque
  tokens. FocusTrace cannot learn bundle ids or names; Flutter sees only ids,
  counts and labels.
- Usage numbers never reach Flutter or SQLite. They exist only inside the
  DeviceActivityReport extension sandbox, which renders them itself.
- No overlays over other apps; the only block UI is the system shield, and a
  shield cannot open the host app.
- DeviceActivity: intervals of at least 15 minutes, about 20 monitored
  activities per app. Usage arrives only as threshold events registered in
  advance: no per-tick usage, no app-open events, and nothing from the
  last minute of the day (the interval ends 23:59).
- Preferred-usage nudges are notifications, not overlays, and cannot repeat
  "on every app open"; amber/red fire once each per day, then every 10
  minutes over the limit for two hours.
- Before iOS 17.4 `DeviceActivityEvent` has no `includesPastActivity`; whether
  use before a restarted activity counts is then up to the system.
- No Shorts/Reels (in-app content) detection.
- The Family Controls entitlement works for development builds but needs
  Apple's approval of the Distribution entitlement, per bundle id, before
  TestFlight/App Store.
