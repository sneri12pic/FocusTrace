# Samsung SM-M135F: imported-history dashboard benchmark

7 September 2026. Android 14/API 34, 32-bit ARM, installed FocusTrace 1.0.6-dev (7), debug build, USB power. All 10 measured launches completed: five process-cold and five activity-warm. No APK was installed or app data cleared for this run.

The pre-run database contained 42 days (28 July–7 September), 926 daily rows, 81 distinct apps, and 5,214 intervals. These are imported records, with no generated seed data. The measured screen shows today's local-device usage; all six dashboard icons became available in every measured launch. This does not time rendering all 81 historical apps.

| Measurement | Cold p50 / p95 (ms) | Warm p50 / p95 (ms) |
|---|---:|---:|
| Android activity launch | 8415.000 / 8506.000 | 8153.000 / 8322.000 |
| First dashboard graph | 3471.035 / 3643.767 | 3480.474 / 3552.032 |
| Icon placeholder duration | 1181.067 / 1302.593 | 888.940 / 1122.146 |
| Fresh usage available | 4790.695 / 5064.759 | 4529.949 / 4833.198 |
| Native usage query | 145.840 / 156.744 | 112.181 / 115.731 |

Graph/fresh-data clocks start inside the dashboard, excluding activity/engine startup. Icon duration starts at the first graph frame. Activity and native query timings have their own clocks; do not add these overlapping measurements. Percentiles use nearest rank; with five samples per scenario, p95 equals the maximum.

An initial cold/warm warmup pair and one capture from an interrupted attempt are retained but excluded in `warmup-and-interrupted.csv`. The measured run uses the existing icon capture script, with incomplete ADB launch-response retries and a two-second pause after Back. All measured launch states matched their requested scenarios.

This is a small debug-build baseline, not release-mode FPS or a controlled comparison against another phone. The imported history remains on the phone.

Evidence: [raw captures](dashboard-icons.csv), [summary CSV](summary.csv), [device metadata](environment.json), [dataset counts](dataset.json).
