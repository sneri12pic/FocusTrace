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
- System frameworks are linked explicitly: Runner - FamilyControls,
  ManagedSettings, DeviceActivity; Monitor - DeviceActivity, ManagedSettings,
  FamilyControls; Shield - ManagedSettings, ManagedSettingsUI; ShieldAction -
  ManagedSettings; Report - DeviceActivity, SwiftUI.

## Shared code: FocusTraceKit

`ios/FocusTraceKit/*.swift` is a plain folder whose files are added to the
Sources phase of Runner and all four extensions (no framework target). Code
there must be extension-safe. Currently only `AppGroup.swift` (the suite name
constant and a `UserDefaults` accessor).

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
link Flutter (`otool -L`). It is the
only place Swift is compiled; the developer machines are Windows/Linux. Code
signing is off, so the build proves compilation and project wiring, not
entitlement provisioning.

## Known platform limits

- Apps, categories and web domains chosen in `FamilyActivityPicker` are opaque
  tokens. FocusTrace cannot learn bundle ids or names; Flutter sees only ids,
  counts and labels.
- Usage numbers never reach Flutter or SQLite. They exist only inside the
  DeviceActivityReport extension sandbox, which renders them itself.
- No overlays over other apps; the only block UI is the system shield.
- No Shorts/Reels (in-app content) detection.
- The Family Controls entitlement works for development builds but needs
  Apple's approval of the Distribution entitlement, per bundle id, before
  TestFlight/App Store.
