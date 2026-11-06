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
  Runner - SwiftUI, UserNotifications; Shield - ManagedSettingsUI;
  ShieldAction - UserNotifications; Report - SwiftUI.

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
| `ScheduleMapper.swift` | Foundation | Rules to DeviceActivity monitoring plans |
| `ShieldStrings.swift` | Foundation | Block screen texts |
| `ScreenTimeEnforcement.swift` | FamilyControls, ManagedSettings, DeviceActivity | Selection codec, `ShieldController`, `ActivityScheduler` |

The Foundation-only files are unit-tested without Xcode:
`tool/ios/run_kit_tests.sh` compiles them with `tool/ios/kit_tests/main.swift`
on the macOS CI host and decodes `test/fixtures/ios_restriction_configuration.json`,
which `test/ios_restriction_fixture_test.dart` keeps equal to what Dart's
`encodeRestrictionConfiguration` produces. Swift re-encodes it to the same
JSON, so the format is checked in both directions.

Runner-only Swift (UIKit, Flutter): `Runner/FocusTraceChannels.swift`,
`Runner/ActivityPicker.swift`, `Runner/SelectionIconsView.swift`, listed in
`RUNNER_SOURCES` of the project script.

## Restrictions on iOS

### Channels

| Channel | Method | Behaviour |
| --- | --- | --- |
| `focustrace/usage` | `syncRestrictions(json)` | `RestrictionSync.apply`: every removed or changed rule must pass the change guard, else `RESTRICTION_LOCKED` and nothing is stored (as Android). Then unreferenced selections older than a day are dropped, shields reconciled, monitoring re-registered. |
| | `readRestrictionConfiguration` | The JSON last stored, verbatim (or null). |
| | `requestRestrictionChange({appKey, type})` | Guard with `request: true`; "allowed" / "cooldown" / "hard"; "allowed" when no such rule. |
| | `hasNotificationsPermission`, `requestNotificationsPermission` | `UNUserNotificationCenter`; also stored in the App Group for the shield. |
| | `takeRestrictionEvents` | Block events the shield extension recorded, then forgotten. |
| `focustrace/screen_time` | `authorizationStatus`, `requestAuthorization` | `AuthorizationCenter`, `.individual`; "notDetermined" / "denied" / "approved". |
| | `pickSelection({selectionId?, doneLabel, cancelLabel})` | `FamilyActivityPicker` in a `UIHostingController`; returns `{selectionId, appKey, appCount, categoryCount, webDomainCount}` or null when cancelled or empty. With `selectionId` it edits that selection, refused (`RESTRICTION_LOCKED`) while a rule using it is protected. |
| | `selectionSummary({selectionId})` | Counts of a stored selection, or null. |
| | `setShieldStrings({strings})` | Block screen texts from the ARB files. |
| platform view `focustrace/selection_icons` | creationParams `{selectionId, maxIcons, iconSize}` | `Label(token)` icons of a selection plus "+N". |

Every other `focustrace/usage` method answers `notImplemented`;
`IosUsageDataSource` never calls them (usage methods return empty / false).

### Data model

- A rule whose apps were picked natively has `appKey = 'ios-sel:<uuid>'` and the
  name the user typed as `appName`. The `FamilyActivitySelection` is stored
  JSON-encoded in the App Group under its uuid; Flutter never sees tokens.
- App Group keys (`RestrictionStore`): `ft.restrictions.json` (Dart's JSON,
  verbatim), `ft.selection.<id>` / `ft.selectionCreated.<id>`,
  `ft.shield.rules` (rule keys shielded now), `ft.shield.stores`,
  `ft.events`, `ft.shield.strings`, `ft.notifications.authorized`, and the
  guard's `ft.change:<appKey>:<type>:rule|ready`.

### Enforcement

- One named `ManagedSettingsStore` per rule (`ft.<type>.<selectionId>`),
  shielding the selection's applications, categories (`.specific`) and web
  domains. iOS shields an app while any store does, so lifting one rule never
  unblocks an app another rule still blocks.
- `ShieldController.reconcile` evaluates every rule with the same time logic as
  Dart/Kotlin (`RestrictionRule.isBlocked`, ISO weekdays, overnight tails
  belong to the start day) and applies or clears each store. The app runs it
  after every sync and whenever it becomes active; the monitor extension runs
  it on `intervalDidStart`, `intervalWillEndWarning` and `intervalDidEnd`,
  evaluating 30 s ahead because callbacks may come slightly early.
- `ScheduleMapper` only makes sure the monitor wakes at every boundary:
  block-now = one non-repeating interval from now to `untilMs`; schedule = one
  daily interval, split into `start-23:59` and `00:00-end` over midnight.
  Weekdays are not encoded in the activities (that would cost one per day);
  the reconcile checks them. Intervals shorter than DeviceActivity's 15-minute
  minimum are widened and the lost boundary is hit with `warningTime`. At most
  20 activities: block-now rules first (soonest end first), then schedules.
- Daily limits and routines are stored and synced but not enforced on iOS
  (phase 3); the guard treats a daily limit as not blocking.
- The change guard is enforced natively with Android's semantics and result
  strings; Dart's `RestrictionsViewModel` is unchanged.

### Block screen

- `FocusTraceShield`: title = the app's `localizedDisplayName` (or the rule
  name), subtitle = one line per blocking rule ("Temporary block until 15:00 ·
  Social"), FocusTrace colours (#070A10 background, #5BC0EB accent), "Leave"
  primary button. It records one block event per rule per minute for Flutter.
- `FocusTraceShieldAction`: primary closes the app. A shield cannot open the
  host app, so the secondary button ("Unblock in FocusTrace") is offered only
  for Easy/Moderate rules and only when notifications are allowed; it posts a
  local notification that opens FocusTrace, then closes the app.

### Flutter

- `PlatformCapabilities.ios`: `screenTimeAuthorization`, `nativeAppPicker`,
  `appBlocking`. New capability `dailyLimits` (Android, Windows): without it
  the editor does not offer daily limits and the routines section is hidden.
- Onboarding's access page shows one Screen Time tile on iOS; the restrictions
  screen shows a Screen Time card until authorized, picks apps with
  `createIosRestriction` (authorize, picker, name dialog, usual editor) and
  draws selection icons through `SelectionIcons` (letter avatar elsewhere).
- Shield texts come from the ARB files (`shield*` keys), sent by
  `syncShieldStrings` when the restrictions screen's locale changes and before
  each pick; English defaults live in `ShieldStrings.swift`.

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
(`tool/ios/run_kit_tests.sh`, also when the build failed). It is the
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
  activities per app.
- No Shorts/Reels (in-app content) detection.
- The Family Controls entitlement works for development builds but needs
  Apple's approval of the Distribution entitlement, per bundle id, before
  TestFlight/App Store.
