# FocusTrace

[![CI](https://github.com/sneri12pic/FocusTrace/actions/workflows/ci.yml/badge.svg)](https://github.com/sneri12pic/FocusTrace/actions/workflows/ci.yml)

FocusTrace is a transparent, local-first screen-time tracker for Android and Windows, built with Flutter, Riverpod, SQLite, and native Kotlin integration on Android.

## Demo

<img width="300" height="640" alt="FocusTraceMenu" src="https://github.com/user-attachments/assets/4f305b1f-f3a0-4925-94c2-af5425039a1e" />
<img width="300" height="640" alt="FocusTraceDetailedView" src="https://github.com/user-attachments/assets/52b280bb-8f61-4aa2-b720-0c06137c77c3" />


## Features

- Android usage summaries through Android Usage Access and `UsageStatsManager`
- Windows active-window tracking while the app is open
- Local SQLite storage for usage sessions and settings
- A dashboard for today's tracked usage, including a usage bubble chart where bigger bubbles mean more time spent
- Cached Android dashboard content that stays visible during refresh, with independent icon loading and cached bubble animation layouts
- [Swipeable app-detail charts](docs/usage-detail-charts.md) with smooth usage curves and a remembered chart choice
- Android app blocking through immediate restrictions, schedules, and daily limits
- App routines with optional shared daily allowances, per-app inclusion controls, usage progress, and limit warnings
- A settings screen to configure the Windows tracking interval and idle timeout, and to clear local data
- In-app language switching with translated Flutter and Android blocker UI
- Portable JSON export/import for local history, settings, and restrictions

FocusTrace does not implement hidden monitoring, keylogging, screenshots, clipboard reading, browser history reading, or content monitoring.

## Platforms

- Android: reads today's app usage after the user grants Usage Access.
- Windows: tracks the active desktop window only while FocusTrace is open and tracking is manually started.

iOS, macOS, and Linux are not part of the MVP, but the architecture keeps platform data sources isolated so they can be added later.

## Languages

FocusTrace can follow the device language or use a language selected in Settings. The initial language pack includes English, Spanish, French, German, Brazilian Portuguese, Japanese, and Ukrainian. The choice is stored locally and is preserved when usage data is cleared.

## Android Usage Access

Android protects app-usage data behind the Usage Access settings screen. FocusTrace checks whether this access is granted and shows a permission card when it is missing.

The app declares:

```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />
```

FocusTrace opens the system Usage Access settings when you press **Open Usage Access Settings**. After granting access, return to the app and refresh.

## Windows Tracking

Windows tracking is manual and session-based:

1. Open FocusTrace.
2. Press **Start Tracking**.
3. FocusTrace periodically reads the foreground window title and process name. The polling interval (default 5 seconds) and idle timeout (default 60 seconds) can be changed on the Settings screen.
4. Press **Stop Tracking** to end the current session.

Tracking stops when the app is closed. Background startup and tray tracking are not implemented in the MVP.

## Run

Install dependencies:

```sh
flutter pub get
```

Run on Android:

```sh
flutter run -d android
```

Run on Windows:

```sh
flutter run -d windows
```

## Tests

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Android JVM tests, lint, and a debug APK build:

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --no-daemon
```

[CI](.github/workflows/ci.yml) runs the Flutter and Android checks on pushes and pull requests to `master` and `develop`. The [case study](docs/performance/README.md#verification) links the regression coverage; [benchmark instructions](benchmark/README.md) explain how to inspect or repeat the measurements.

## Privacy

All usage data is stored locally in SQLite on the device. FocusTrace does not send tracked data to a server and does not include sync in the MVP. **Clear Local Data** on the Settings screen removes stored usage sessions and settings from the local database.

Portable backups can be created and restored from **Settings → Backup and
restore**. The JSON file remains under the user's control and should be treated
as private because it contains usage history and settings.

## Measured engineering improvements

Performance work reduced repeated Android event processing and made the dashboard useful sooner. These are recorded **physical-device debug-build results**, with raw measurements and regression tests in this repository.

| Measurement (median / p50) | Before | After | Reduction |
|---|---:|---:|---:|
| Android UsageStats query and iteration time per blocker tick | 35.026 ms | 3.626 ms | **89.6%** |
| Total blocker tick time | 59.044 ms | 32.977 ms | **44.1%** |
| UsageEvents processed per blocker tick | 3,432 | 4 | **99.9%** |
| Dashboard open to first graph frame | 1,340.781 ms | 790.883 ms | **41.0%** |
| Icon placeholder duration, process-cold launch | 1,027.124 ms | 576.696 ms | **43.9%** |

Measured on one Samsung SM-A366B running Android 16, on 21 and 27 August 2026. The blocker comparison includes 90 baseline / 97 optimized ticks; the dashboard comparison includes 30 opens per version; the cold-icon comparison includes 15 per version. Each row compares its own experiment's baseline and follow-up.

The dashboard result requires a saved same-day snapshot and starts at the Flutter dashboard screen, excluding earlier activity/engine startup. Fresh usage completion became slower in that experiment (683.059 → 1,220.135 ms median): cached content is shown first while live data refreshes. Battery life and release-build performance were not measured.

**[Read the engineering case study, evidence, and CV-ready accomplishments →](docs/performance/README.md)**

## Play update recovery

If Google Play reports that FocusTrace cannot be updated because an existing
package conflicts or has a different signature, do not uninstall before saving
the local data. Follow the verified diagnosis and recovery procedure in
[docs/PLAY_SIGNING_RECOVERY.md](docs/PLAY_SIGNING_RECOVERY.md).

## Roadmap

- macOS support using `NSWorkspace.frontmostApplication`
- iOS support using Screen Time APIs where possible
- App categories
- Weekly and monthly reports
- Optional CSV reporting export
- Optional encrypted sync later
