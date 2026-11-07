# iOS release checklist

What has to happen outside the repository before FocusTrace for iOS can go to
TestFlight and the App Store. The repository builds unsigned in CI
(`ios-build`); nothing here is automated until the steps below are done.
Architecture: `ios-port-architecture.md`.

## 1. Apple Developer Program

- Enroll the publishing account (individual or organization) in the Apple
  Developer Program. Note the 10-character **Team ID**.

## 2. Identifiers (developer.apple.com > Certificates, IDs & Profiles)

Register one App ID per bundle id, all explicit (no wildcard):

| Target | Bundle id | Capabilities to enable |
| --- | --- | --- |
| Runner (app) | `com.stepandemianenko.focustrace` | Family Controls, App Groups, HealthKit (with Background Delivery) |
| FocusTraceMonitor | `com.stepandemianenko.focustrace.monitor` | Family Controls, App Groups |
| FocusTraceShield | `com.stepandemianenko.focustrace.shield` | Family Controls, App Groups |
| FocusTraceShieldAction | `com.stepandemianenko.focustrace.shieldaction` | Family Controls, App Groups |
| FocusTraceReport | `com.stepandemianenko.focustrace.report` | Family Controls, App Groups |
| FocusTraceWidget | `com.stepandemianenko.focustrace.widget` | App Groups |

- Register the App Group `group.com.stepandemianenko.focustrace` and assign
  it to all six App IDs.
- HealthKit: only the app reads Health (workouts, read only, no clinical
  records). The entitlements file already asks for background delivery.

## 3. Family Controls (Distribution) entitlement

Development builds work with the development entitlement, but TestFlight and
the App Store need Apple's approval of **Family Controls (Distribution)**:

- Request it at developer.apple.com/contact/request/family-controls-distribution
  **for each of the five bundle ids that use Screen Time** (app, monitor,
  shield, shieldaction, report). The widget does not use Family Controls.
- Describe the use: individual (self) authorization, the user picks apps to
  limit, blocking with shields and schedules/limits via DeviceActivity, usage
  shown only through DeviceActivityReport, nothing leaves the device.
- Approval can take days to weeks. Without it the archive/upload fails or the
  extensions are rejected.

## 4. Signing in Xcode (on a Mac)

- Open `ios/Runner.xcworkspace`, select each of the six targets > Signing &
  Capabilities > Team = the Team ID, "Automatically manage signing" on.
  Do not commit the team id unless you want it in the repository
  (`DEVELOPMENT_TEAM`); CI's TestFlight workflow passes it on the command line.
- Re-running `ruby tool/ios/add_extension_targets.rb` rewrites extension build
  settings; if you set the team in Xcode, set it again afterwards or add
  `DEVELOPMENT_TEAM` to the script.
- Run once on a physical iPhone (iOS 16+) from Xcode: Screen Time APIs do
  not work in the simulator.

## 5. Device verification before TestFlight

Run the device checks listed under "Remaining work" in `ios-port-plan.md`
(Screen Time authorization, shields, schedules with the app killed, limits,
notifications, reports, Apple Health import, backup to and from Files,
language change, widget).

## 6. App Store Connect

- Create the app record (bundle id `com.stepandemianenko.focustrace`,
  name "FocusTrace", primary language English, SKU of your choice).
- Version and build come from `pubspec.yaml` (`version: x.y.z+build` becomes
  `CFBundleShortVersionString` / `CFBundleVersion` for the app and every
  extension). Raise the build number for every upload.
- **App Privacy** label: "Data Not Collected". Usage data stays in Screen
  Time on the device, rules and settings in the app's local database and App
  Group, workouts in the app's container; nothing is sent to a server (cloud
  sync is off on iOS) and there is no tracking or analytics. The bundled
  `PrivacyInfo.xcprivacy` manifests declare the same (UserDefaults reasons
  CA92.1 and 1C8F.1).
- Age rating questionnaire, category (Productivity or Health & Fitness),
  support URL, privacy policy URL (the same policy as Google Play, with an iOS
  paragraph: Screen Time, Apple Health read-only, Files backups).
- Screenshots: see `store_assets/captions.txt` (iOS section).

## 7. TestFlight

Either from Xcode (Product > Archive > Distribute App > App Store Connect)
or with the manual GitHub workflow `iOS TestFlight`
(`.github/workflows/ios-testflight.yml`), after adding these repository
secrets:

- `APPLE_TEAM_ID`
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64` (an App Store Connect
  API key with the App Manager or Admin role; base64 of the `.p8` file)

The workflow archives with automatic signing and uploads; it never runs on
push. Then add internal testers in App Store Connect > TestFlight and fill in
the "What to Test" notes.

## 8. App Review notes (paste into "Notes" for the reviewer)

> FocusTrace is a personal digital-wellbeing app. It uses Apple's Screen
> Time APIs with **individual** authorization (FamilyControls
> `.individual`): the user chooses apps in Apple's FamilyActivityPicker, and
> FocusTrace blocks them with ManagedSettings shields now, on a schedule, or
> after a daily time limit (DeviceActivity monitor extension). Usage is shown
> only through a DeviceActivityReport extension; FocusTrace never sees app
> names or usage numbers and nothing leaves the device.
>
> To try it: open FocusTrace, allow Screen Time when asked, open the
> Restrictions tab and add a restriction, pick an app in Apple's picker, name
> the group, and choose "Block now". Opening that app shows FocusTrace's
> shield.
>
> Apple Health is optional (Settings > Apple Health) and read-only: it
> imports workouts to show next to screen time. Backups (Settings > Export
> data) are JSON files the user saves in Files.

## 9. After approval

- Submit for review with the same notes. Keep the Family Controls
  (Distribution) approval mail; Apple may ask for it again for new extension
  bundle ids.
