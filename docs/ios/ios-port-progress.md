# iOS port - progress

Date: 2026-11-06
Agent: Claude Code
Goal: Phase 1 - iOS shell with Screen Time extension targets and a macOS CI build.

Completed:
- `flutter create --platforms=ios` (org `com.stepandemianenko`): bundle id `com.stepandemianenko.focustrace`, display name "FocusTrace", iOS 16.0 (project, Podfile, AppFrameworkInfo.plist), Swift. `.metadata` gained only the ios migration entry.
- Committed a Podfile (`platform :ios, '16.0'`) and the CocoaPods includes in `Flutter/Debug.xcconfig` / `Release.xcconfig`, as Flutter would generate on a Mac.
- `tool/ios/add_extension_targets.rb` adds FocusTraceMonitor, FocusTraceShield, FocusTraceShieldAction (app extensions) and FocusTraceReport (ExtensionKit extension), Info.plists, entitlements, FocusTraceKit sources, system frameworks, embed phases before "Thin Binary", and target dependencies.
- Minimal Swift stubs per extension and `FocusTraceKit/AppGroup.swift`.
- CI job `ios-build` (macos-15): `flutter build ios --debug --no-codesign`.
Files materially changed: `ios/**`, `tool/ios/add_extension_targets.rb`, `.github/workflows/ci.yml`, `.metadata`, `docs/ios/*`.
Verification: see the commit's CI run; locally (Linux) the script ran twice with no diff on the second run, all plists/entitlements parsed with Python `plistlib`; PASS `flutter analyze`; PASS `flutter test` (373, 1 skipped). Swift compilation is verified only by the CI job `ios-build`.
Decisions made: FocusTraceReport is an ExtensionKit extension (Xcode's template), not an NSExtension app extension. Extensions take version numbers from `Generated.xcconfig` via `Config/Extension.xcconfig`.
Remaining: phases 0 and 2-5 (see plan). No Apple team, provisioning or Distribution entitlement yet.
Risks / unresolved questions: nothing runs on a device yet; extension discovery (especially the report extension) is only verifiable on hardware with a signed build.
Relevant commit: see `git log -- docs/ios`.
