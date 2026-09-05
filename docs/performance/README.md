# FocusTrace: performance and reliability case study

FocusTrace combines a Flutter/Riverpod interface, SQLite persistence, and Kotlin integration with Android UsageStats and app blocking. This work addressed three visible problems: repeated full-day event scans in the blocker, a dashboard that waited for live data, and placeholders that persisted until the live response supplied app icons.

The measured outcome was **89.6% less median UsageStats query/iteration time**, **41.0% less time to the first dashboard graph frame**, and **43.9% less icon placeholder time on process-cold launches**, across separate experiments on the same Samsung device.

## Results and evidence

All percentages below compare unrounded nearest-rank medians (p50). Lower is better. The experiments used a Samsung SM-A366B, Android 16/API 36, a debuggable `1.0.6-dev` build, and USB power. Blocker captures were recorded on 21 August 2026; dashboard and icon captures on 27 August 2026.

| Experiment | Measurement | Before | After | Reduction | Included samples, before / after |
|---|---|---:|---:|---:|---:|
| Incremental blocker | Queries per tick | 2 | 1 | 50.0% | 90 / 97 ticks |
| Incremental blocker | Events processed per tick | 3,432 | 4 | 99.9% | 90 / 97 ticks |
| Incremental blocker | Query + iteration | 35.026 ms | 3.626 ms | 89.6% | 90 / 97 ticks |
| Incremental blocker | Total tick | 59.044 ms | 32.977 ms | 44.1% | 90 / 97 ticks |
| Cached dashboard | Screen open → first graph frame | 1,340.781 ms | 790.883 ms | 41.0% | 30 / 30 opens |
| Independent icon loading | Placeholder duration, process cold | 1,027.124 ms | 576.696 ms | 43.9% | 15 / 15 opens |
| Independent icon loading | Placeholder duration, activity warm | 1,031.515 ms | 526.916 ms | 48.9% | 15 / 15 opens |

Tail latency also improved: blocker query/iteration p95 fell from 86.394 to 11.296 ms (86.9%), and first-graph p95 fell from 1,700.304 to 827.829 ms (51.3%). The full reports retain p95, maxima where available, warmup rules, device/build metadata, and measurement definitions.

- **[Android blocker report](android-blocker.md):** [baseline CSV](../../benchmark/android/results/2026-08-21-blocker-baseline.csv) and [incremental CSV](../../benchmark/android/results/2026-08-21-blocker-incremental.csv).
- **[Dashboard and icon report](android-dashboard.md):** [dashboard baseline](../../benchmark/android/results/2026-08-27-dashboard-baseline.csv), [cached dashboard](../../benchmark/android/results/2026-08-27-dashboard-swr.csv), [icon baseline](../../benchmark/android/results/2026-08-27-dashboard-icons-baseline.csv), and [icon follow-up](../../benchmark/android/results/2026-08-27-dashboard-icons-after.csv).
- **[Reproduction guide](../../benchmark/README.md):** capture scripts, prerequisites, and how to interpret the stored measurements.

These are sequential device experiments, not randomized trials or universal Android speed guarantees. Dashboard measurements start at `DashboardScreen.initState`, excluding preceding Android activity and Flutter engine startup. The first-graph improvement requires a non-empty snapshot for the current local day.

## Engineering decisions

### 1. Process new usage events instead of replaying the day

The original blocker queried midnight-to-now twice on every tick: once for restricted usage and once for the foreground app. The replacement uses a single in-memory state reducer for both. After bootstrap, it queries from the newest observed event, deduplicates events at the inclusive boundary, and evaluates an open foreground interval without double-counting it.

A device trial exposed delayed UsageEvent publication: advancing to the previous query's end could skip events. The implementation now retains the last observed event boundary through empty queries. The final controlled run recorded zero manually reported missed blocks across 57 blocked-app attempts, and zero blocker actions across 34 unrestricted control ticks. Those observations are not population failure rates.

A separate aggregation bug was reproduced and fixed: when a restricted app is followed by an unrestricted app without a background event, the restricted app's session now closes at the switch. In the regression trace, A is counted for 1,000 ms instead of 5,000 ms.

Sources: [incremental reducer](../../android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageStats.kt), [service integration](../../android/app/src/main/kotlin/com/stepandemianenko/focustrace/BlockerService.kt), and [regression tests](../../android/app/src/test/kotlin/com/stepandemianenko/focustrace/UsageStatsTest.kt).

### 2. Show saved usage before live refresh completes

The Android dashboard reads the exact current local-day snapshot from the existing SQLite table, publishes it, then refreshes authoritative usage. The ViewModel separates initial loading, background refresh, and refresh failure. A failed refresh preserves valid visible content; day changes and stale asynchronous responses cannot overwrite the selected day's data. Trends and all-time statistics load independently after the main summaries.

The bubble chart computes entrance and final packed geometry once per relevant item/size change. Animation frames interpolate those cached positions. Selection and icon-only updates reuse the layout; later usage updates use a short transition instead of replaying the entrance.

Sources: [dashboard ViewModel](../../lib/src/presentation/view_models/dashboard_view_model.dart), [usage repository](../../lib/src/data/repositories/usage_repository_impl.dart), and [bubble chart](../../lib/src/presentation/widgets/bubble_chart.dart).

### 3. Restore icons independently and invalidate them correctly

After cached usage is published, metadata for the top ten apps loads independently of live usage; remaining cached apps follow in a second batch. Metadata updates preserve usage totals, shares, and launch counts. Native disk/memory caches and the Dart byte cache use the package update timestamp to invalidate stale icons. Missing apps and image failures retain fallback icons.

An additional ten-pair payload experiment did not establish a stable material benefit from stripping icons out of live usage responses. The production response retains them as a second recovery path. This decision and the inconclusive measurements are preserved in the [payload audit](android-dashboard.md#live-icon-payload-audit).

Sources: [native metadata/cache implementation](../../android/app/src/main/kotlin/com/stepandemianenko/focustrace/MainActivity.kt) and [Dart cache invalidation test](../../test/android_usage_data_source_icon_cache_test.dart).

## Product clarity: shared routine limits

Routines now support an optional daily allowance shared by their included apps. A dedicated details screen shows combined usage, remaining time, progress, and each app's contribution. Users can add/remove apps, exclude an app from the allowance, rename a routine, choose preset/custom durations, and pause or remove a limit. Native enforcement and warning notifications use the same included-app grouping.

This changes legacy behavior: old routines without a daily limit migrate to disabled usage groups. The new routine and blocker messages are localized in English, German, Spanish, French, Japanese, Brazilian Portuguese, and Ukrainian.

Sources: [routine details](../../lib/src/presentation/screens/routine_details_screen.dart), [model and migration](../../lib/src/domain/models/block_routine.dart), [native rules](../../android/app/src/main/kotlin/com/stepandemianenko/focustrace/RestrictionRules.kt), and [routine tests](../../test/block_routine_test.dart).

## Verification

Local verification on **5 September 2026**, before publication:

| Check | Result |
|---|---|
| Dart formatting | 97 files checked, no changes required |
| Flutter static analysis | Passed, no issues |
| Flutter tests | 84 passed |
| Android debug JVM tests | 31 passed, 1 opt-in benchmark skipped, 0 failures/errors |
| Android lint | Passed |
| Android debug APK assembly | Passed |
| Documentation links and PowerShell capture-script parsing | Passed |

The device timing tables remain the August measurements; this verification did not repeat the device experiments. Repository CI runs the Flutter and Android checks; see the [workflow](../../.github/workflows/ci.yml) and [current runs](https://github.com/sneri12pic/FocusTrace/actions/workflows/ci.yml).

Coverage added or expanded by this work includes:

- [Usage event transitions](../../android/app/src/test/kotlin/com/stepandemianenko/focustrace/UsageStatsTest.kt): missing/duplicate lifecycle events, delayed publication, query boundaries, permission invalidation, restart reconstruction, day/clock changes, and open-interval accounting.
- [Dashboard state](../../test/dashboard_view_model_test.dart): cache-first display, absent cache, permission loss, failed refresh, stale responses, exact day selection, and independent metadata/auxiliary loads.
- [Layout reuse](../../test/bubble_pack_test.dart), [metadata-free snapshot reads](../../test/historical_icon_enrichment_test.dart), [versioned icon caching](../../test/android_usage_data_source_icon_cache_test.dart), and [routine editing](../../test/routine_editor_sheet_test.dart).
- An [opt-in pure Kotlin aggregation benchmark](../../benchmark/usage_stats/README.md) with 1,000–100,000 deterministic events, separate from Android device timings.

## Tradeoffs and remaining limits

- **Freshness:** cached dashboard publication moved first-graph visibility earlier, but median live-data completion increased from 683.059 to 1,220.135 ms (+78.6%). The later icon experiment also increased median fresh-data completion by 5.3% cold and 11.3% warm. These are visibility improvements with measured freshness costs.
- **Measurement scope:** battery life, release-build behavior, other devices, and overlay presentation latency were not measured. Block activity latency improved in the recorded session, but that experiment cannot attribute the entire change to incremental querying.
- **Usage reconstruction:** state resets and bootstraps on relevant changes. Sessions already active before midnight, or events published out of order behind the retained cursor, remain limitations; reset tests do not establish complete midnight-spanning accuracy.
- **Historical evidence:** benchmarks were captured from intermediate uncommitted builds; the reports preserve the base revision and APK hashes. The CSVs are historical evidence, not fresh measurements of every later edit.

## CV-ready accomplishments

Choose the bullets relevant to the role and retain the device-benchmark qualifier when using the numerical results:

- Optimized Kotlin Android usage enforcement with an incremental event reducer, reducing median UsageStats query/iteration time by 89.6% and per-tick events from 3,432 to 4 in a physical-device debug benchmark.
- Implemented a SQLite-backed Flutter dashboard with background refresh and cached chart layouts, reducing median screen-open-to-first-graph time by 41.0% across 30 opens per version on one Android device.
- Added independent metadata loading and versioned icon caches, reducing median cold-launch icon placeholder time by 43.9% in a physical-device debug benchmark, with regression coverage for cache invalidation and stale responses.
- Delivered shared daily app allowances with native Android enforcement, usage-progress UI, legacy-data migration, and localization across seven languages.

For an interview, explain the observed tradeoffs as well as the gains: delayed Android events changed the cursor design, cache-first rendering delayed live completion, and the live-icon payload experiment was too inconclusive to justify removing a recovery path.
