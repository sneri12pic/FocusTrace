# Performance measurements

The [engineering case study](../docs/performance/README.md) summarizes the results. The CSVs in this directory contain historical measurements; running a capture creates a new experiment and does not reproduce an old APK or its event history automatically.

## Inspect the evidence

| Area | Method and results | Raw samples |
|---|---|---|
| Android blocker | [Device report](../docs/performance/android-blocker.md) | [Before](android/results/2026-08-21-blocker-baseline.csv), [after](android/results/2026-08-21-blocker-incremental.csv) |
| Android dashboard | [Device report](../docs/performance/android-dashboard.md) | [Before](android/results/2026-08-27-dashboard-baseline.csv), [after](android/results/2026-08-27-dashboard-swr.csv) |
| Icon availability | [Icon experiment](../docs/performance/android-dashboard.md#cached-icon-hydration) | [Before](android/results/2026-08-27-dashboard-icons-baseline.csv), [after](android/results/2026-08-27-dashboard-icons-after.csv) |
| Live icon payload | [A/B audit](../docs/performance/android-dashboard.md#live-icon-payload-audit) | [Paired samples](android/results/2026-08-27-dashboard-live-icon-payload-audit.csv) |
| Pure Kotlin aggregation | [JVM methodology](usage_stats/README.md) | [120 baseline timing samples](usage_stats/results/2026-08-21-windows-debug-jvm.csv) |

For the Android CSVs, select `included=true` rows. Compute percentiles by sorting numerically and selecting rank `ceil(p * n)` (one-based). Blocker durations ending in `_ns` are nanoseconds. Dashboard milestone values ending in `_us` are microseconds: subtract `dashboard_open_us` for the baseline/SWR experiment. The icon CSV already stores screen-relative milestones and `placeholder_duration_us`.

## Capture a new dashboard experiment

Prerequisites: PowerShell, Flutter, Android SDK platform-tools (`adb`), one connected Android device, and the FocusTrace debug app. Install the debug build and open it once to grant Usage Access and populate a non-empty same-day snapshot. Use a disposable measurement session: the scripts clear logcat, force-stop/reopen the debug app, and navigate Back between launches. They retain app data.

From the repository root, with `adb` on `PATH`:

```powershell
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

.\benchmark\android\capture_dashboard.ps1 -OutputPath "$env:TEMP\focustrace-dashboard.csv" -Pairs 15
.\benchmark\android\capture_dashboard_icons.ps1 -OutputPath "$env:TEMP\focustrace-icons.csv" -Pairs 15
.\benchmark\android\audit_dashboard_live_icon_payload.ps1 -OutputPath "$env:TEMP\focustrace-payload.csv" -Pairs 10
```

If `adb` is not on `PATH`, pass `-AdbPath 'C:\path\to\platform-tools\adb.exe'` to each capture script. Output directories must already exist. Use new output filenames to preserve previous measurements.

The scripts target `com.stepandemianenko.focustrace.dev`. Dashboard and icon captures alternate process-cold and activity-warm opens. The payload audit compares live responses with/without icon bytes through a debug-only intent extra. Its fixed pair order and small sample limit causal inference.

For blocker measurements, follow the scenario and warmup procedure in the [blocker report](../docs/performance/android-blocker.md#methodology). Debug builds emit `FocusTraceBlockerPerf` tick and first-draw records; the committed blocker CSVs were assembled from controlled captures, without a general blocker automation script.

## Run correctness checks and the optional JVM benchmark

```powershell
flutter test
Set-Location android
.\gradlew.bat :app:testDebugUnitTest --no-daemon
$env:FOCUSTRACE_BENCHMARK = '1'
.\gradlew.bat :app:testDebugUnitTest --tests 'com.stepandemianenko.focustrace.UsageStatsAggregationBenchmarkTest' --rerun-tasks --no-daemon
Remove-Item Env:FOCUSTRACE_BENCHMARK
```

The optional benchmark measures pure `aggregateEvents` CPU cost on the host JVM. It does not measure Android UsageStats queries, ART, blocking latency, or battery life. Do not combine its timing figures with the physical-device results.
