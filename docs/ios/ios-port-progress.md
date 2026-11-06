# iOS port - progress

Date: 2026-11-06
Agent: Claude Code
Goal: Phase 2 - Screen Time authorization, app picker, blocking, schedules, change guard.

Completed:
- FocusTraceKit: Codable mirror of the rule JSON (`RestrictionModels.swift`, lenient like `RestrictionRules.kt`), App Group `RestrictionStore` and `RestrictionSync` (sync validation as `MainActivity.syncRestrictions`), Swift `RestrictionChangeGuard` (same "allowed"/"cooldown"/"hard"), `ScheduleMapper` (DeviceActivity plans: midnight split, 15-minute minimum via `warningTime`, cap 20), `ShieldController` (one named ManagedSettingsStore per rule) and `ActivityScheduler`.
- Extensions: monitor re-evaluates all rules at every interval start / warning / end; FocusTrace-styled shield (app name, one reason line per rule, Leave); shield action closes the app, secondary posts an "open FocusTrace" notification for Easy/Moderate when notifications are allowed.
- Runner: `focustrace/usage` (syncRestrictions, readRestrictionConfiguration, requestRestrictionChange, notifications permission, takeRestrictionEvents), `focustrace/screen_time` (authorization, pickSelection, selectionSummary, setShieldStrings), platform view `focustrace/selection_icons`; shields refreshed whenever the app becomes active.
- Dart: `IosUsageDataSource` (usage empty), `ScreenTimeChannel`, `screenTimeAuthorizationProvider`, iOS Screen Time onboarding tile, restrictions screen Screen Time card, native picker + name dialog + usual editor (`ios-sel:<uuid>` keys), native selection icons, shield texts from ARB. `appBlocking` on for iOS; new `dailyLimits` capability (Android, Windows) hides daily limits and routines on iOS. Shield block events are imported into restriction statistics on load.
- 17 new ARB keys translated into all 7 languages.
- CI: `tool/ios/run_kit_tests.sh` compiles the Foundation-only kit files with `tool/ios/kit_tests/main.swift` on macOS and checks them against `test/fixtures/ios_restriction_configuration.json` (kept equal to Dart's encoding by `test/ios_restriction_fixture_test.dart`).
Files materially changed: `ios/FocusTraceKit/*`, `ios/Focus*/**Extension.swift`, `ios/Runner/{AppDelegate,FocusTraceChannels,ActivityPicker,SelectionIconsView}.swift`, `ios/Runner.xcodeproj/project.pbxproj`, `tool/ios/*`, `.github/workflows/ci.yml`, `lib/src/data/datasources/{platform_usage_data_source,screen_time_channel}.dart`, `lib/src/domain/models/platform_capabilities.dart`, `lib/src/presentation/{providers.dart,screens/restriction*.dart,screens/onboarding_screen.dart,view_models/*,widgets/selection_icons.dart}`, `lib/l10n/*`, `test/*`.
Verification: PASS CI run https://github.com/sneri12pic/FocusTrace/actions/runs/42288871861 (all four jobs; `ios-build` compiled Runner and the four extensions, kit tests 80/80). Locally PASS `flutter analyze`, PASS `dart format --set-exit-if-changed lib test`, PASS `flutter test` (390, 1 skipped); project script idempotent (second run leaves `project.pbxproj` unchanged). Nothing ran on a device or simulator.
Decisions made: monitor activities are wake-ups only, every callback reconciles all rules (weekdays checked in Swift, not encoded per day); per-rule named stores; picker selections are immutable per rule in the UI (a new rule per new pick); daily limits/routines hidden on iOS via a capability rather than "coming soon" UI; shield texts sent from Dart so they follow the in-app language.
Remaining: device verification of phase 2 acceptance criteria; phase 3 (daily limits, routines, nudges; also turns notifications permission on for iOS); phases 4-5.
Risks / unresolved questions: unverified on hardware: shield extension writing block events to the App Group, `warningTime` firing for short intervals, intervals whose start is "now" for block-now, `Label(token)` sizing in the platform view, picker presentation over FlutterViewController. More than 20 block-now/schedule pieces leave the rest enforced only when the app is opened. Onboarding's "choose apps" page still lists installed apps (empty on iOS).
Relevant commit: 317fc31 (native), dafb197 (Dart/UI), 516dee1 (Swift import fix).

Date: 2026-11-06
Agent: Claude Code
Goal: Phase 1 - iOS shell with Screen Time extension targets and a macOS CI build.

Completed:
- `flutter create --platforms=ios` (org `com.stepandemianenko`): bundle id `com.stepandemianenko.focustrace`, display name "FocusTrace", iOS 16.0 (project, Podfile, AppFrameworkInfo.plist), Swift. `.metadata` gained only the ios migration entry.
- Committed a Podfile (`platform :ios, '16.0'`) and the CocoaPods includes in `Flutter/Debug.xcconfig` / `Release.xcconfig`, as Flutter would generate on a Mac.
- `tool/ios/add_extension_targets.rb` adds FocusTraceMonitor, FocusTraceShield, FocusTraceShieldAction (app extensions) and FocusTraceReport (ExtensionKit extension), Info.plists, entitlements, FocusTraceKit sources, system frameworks, embed phases before "Thin Binary", and target dependencies.
- Minimal Swift stubs per extension and `FocusTraceKit/AppGroup.swift`.
- CI job `ios-build` (macos-15): `flutter build ios --debug --no-codesign`, then checks each extension is embedded, reports its bundle id / version / extension point, and does not link Flutter. Passed on the first push; no Swift fixes were needed.
Files materially changed: `ios/**`, `tool/ios/add_extension_targets.rb`, `.github/workflows/ci.yml`, `.metadata`, `docs/ios/*`.
Verification: PASS CI run https://github.com/sneri12pic/FocusTrace/actions/runs/42284125256 (all four jobs; `ios-build` built Runner.app with the three extensions in PlugIns/ and the report in Extensions/, versions 1.1.0, no Flutter linkage). Locally (Linux) the script ran twice with no diff on the second run, all plists/entitlements parsed with Python `plistlib`; PASS `flutter analyze`; PASS `flutter test` (373, 1 skipped). Swift compilation is verified only by the CI job `ios-build`.
Decisions made: FocusTraceReport is an ExtensionKit extension (Xcode's template), not an NSExtension app extension. Extensions take version numbers from `Generated.xcconfig` via `Config/Extension.xcconfig`.
Remaining: phases 0 and 2-5 (see plan). No Apple team, provisioning or Distribution entitlement yet.
Risks / unresolved questions: nothing runs on a device yet; extension discovery (especially the report extension) is only verifiable on hardware with a signed build.
Relevant commit: 36cd4f3 (shell), c7b359d (CI embed check).
