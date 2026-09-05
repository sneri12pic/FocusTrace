# Android Dashboard Performance

This report measures FocusTrace dashboard startup on a physical Android device,
then compares the original live-only loading path with a stale-while-revalidate
SQLite snapshot and a cached bubble layout.

## Device and builds

- Benchmark date: 2026-08-27 (Europe/London)
- Device: Samsung SM-A366B
- Android: 16, API 36
- OS build: `BP4A.251205.006.A366BXXSBCZG1`
- App package/build: debuggable `com.stepandemianenko.focustrace.dev`, version
  `1.0.6-dev` (`versionCode` 7), target SDK 35, min SDK 21
- Source revision: `1528c1a774a2cb805bbfb029623b5156187a5455`, with
  benchmark instrumentation and other uncommitted working-tree changes present
- Baseline APK SHA-256:
  `1CA3B84B3CA70B596EEE5BD1C17F130DF844BBEF0C659D0918AF6B06F7558FB1`
- Optimized APK SHA-256:
  `1EBE0E0F9BB835E811C8E5B9A03DA4C07D5A9B1D4A3AF235D9EE121698867042`
- Icon-hydration APK SHA-256:
  `6486E90CC918086DA04144DB0F4E70EE41BD2531639A81A524506D20E80C7F1F`
- Usage Access remained allowed. App data was retained across `adb install -r`,
  so the optimized run used the same `daily_app_usage` snapshot populated by
  the baseline run.
- The device was USB-powered. Battery was 89% before the baseline and 88% after
  the optimized run; the final reported temperature was 31.6 C. Android thermal
  status was 0 at the checks around the captures.

## Measurement definitions

Debug-only instrumentation emits `FocusTraceDashboardPerf` records for:

1. `dashboard_open`: `DashboardScreen.initState`;
2. `view_model_init`: `DashboardViewModel` construction;
3. `live_usage_available`: the dashboard-owned Android
   `getTodayUsageStats` platform call has returned and its rows have been mapped;
4. `first_non_empty_state`: the first non-empty summaries state is published;
5. `first_bubble_frame`: the first Flutter post-frame callback after
   `BubbleChart` mounts; and
6. `entrance_animation_complete`: the first post-frame callback after the chart
   entrance controller completes.

The dashboard-owned live call is correlated through its async zone so another
consumer's UsageStats request cannot satisfy the marker. Durations use a Dart
`Stopwatch`, which is monotonic. Each reported duration subtracts the
`dashboard_open` marker from the relevant milestone.

`First graph visible` means the `first_bubble_frame` marker. It does not include
Android activity or Flutter engine startup before `DashboardScreen.initState`,
and it is not a user-perception or full-rasterization measurement. Android's
`am start -W` activity time is retained in the raw CSV as supporting context.

## Procedure

The same PowerShell/ADB capture script and event definitions were used for both
runs. Each run contains 15 pairs, for 30 included opens:

- `process_cold`: force-stop the app, retain its data, then start the dashboard;
  Android classified all 15 as `COLD`.
- `activity_warm`: finish the activity with Back and immediately restart it
  without force-stopping the process; Android classified all 15 as `WARM`.

The installed app already had Usage Access and a non-empty day of usage. Pilot
opens used to validate instrumentation were excluded. No measured samples were
removed and no outliers were discarded. Percentiles use nearest rank: sort and
select `ceil(p * n)`.

Raw measurements:

- [2026-08-27-dashboard-baseline.csv](../../benchmark/android/results/2026-08-27-dashboard-baseline.csv)
- [2026-08-27-dashboard-swr.csv](../../benchmark/android/results/2026-08-27-dashboard-swr.csv)
- [2026-08-27-dashboard-icons-baseline.csv](../../benchmark/android/results/2026-08-27-dashboard-icons-baseline.csv)
- [2026-08-27-dashboard-icons-after.csv](../../benchmark/android/results/2026-08-27-dashboard-icons-after.csv)
- [2026-08-27-dashboard-live-icon-payload-audit.csv](../../benchmark/android/results/2026-08-27-dashboard-live-icon-payload-audit.csv)

Both CSVs contain one row per open with the requested and Android-reported launch
state, run ID, Android activity time, all six microsecond markers, and
complete/included flags. Each file contains 30 complete included rows.

## Baseline

The baseline retained the original behavior. The ViewModel awaited live usage,
exclusions, all-time summaries, and 60-day trends before publishing. The screen
did not mount the graph while loading. During the 1,200 ms entrance animation,
every animation frame recomputed a prefix of the 150-step packing simulation.

### Combined baseline results

| Metric | Samples | p50 | p95 |
|---|---:|---:|---:|
| Dashboard open -> first graph visible | 30 | 1,340.781 ms | 1,700.304 ms |
| Dashboard open -> live usage available | 30 | 683.059 ms | 843.515 ms |
| Dashboard open -> first non-empty state | 30 | 953.288 ms | 1,292.382 ms |
| Dashboard open -> entrance animation complete | 30 | 2,151.270 ms | 2,493.051 ms |

### Baseline by launch state

| Launch state | Metric | Samples | p50 | p95 |
|---|---|---:|---:|---:|
| Process cold | First graph visible | 15 | 1,625.366 ms | 1,705.555 ms |
| Process cold | Live usage available | 15 | 789.720 ms | 844.324 ms |
| Process cold | Animation complete | 15 | 2,409.844 ms | 2,548.328 ms |
| Activity warm | First graph visible | 15 | 1,279.761 ms | 1,340.781 ms |
| Activity warm | Live usage available | 15 | 662.895 ms | 683.059 ms |
| Activity warm | Animation complete | 15 | 2,074.460 ms | 2,151.270 ms |

## Stale-while-revalidate and bubble layout change

The optimized Android path now:

- reads the exact current local-day snapshot directly from the existing
  `daily_app_usage` table, without a package-metadata lookup;
- publishes a valid non-empty snapshot immediately;
- distinguishes initial loading from background refreshing;
- keeps populated summaries visible through silent/manual refreshes and exposes
  live-refresh failures separately from destructive initial-load failures;
- leaves a valid cached snapshot visible when Usage Access is missing;
- queries the selected local day explicitly and invalidates visible summaries
  when the local day changes;
- replaces the snapshot with the fresh Android result, which is still persisted
  by the existing `saveDailySummaries` path; and
- starts all-time and trend reads only after main summaries are visible, without
  awaiting them before publishing the graph.

No new database or table was added. A no-cache launch still waits for live data.

`BubbleChart` now computes deterministic zero-step entrance geometry and the
final 150-step packed geometry once per relevant items/size change. Animation
frames interpolate those cached positions and radii. Selection, restriction,
tooltip, and other unrelated rebuilds reuse the layout. A data refresh during
entrance updates the target for the remaining entrance duration; a later refresh
uses a short 300 ms geometry transition instead of replaying the 1,200 ms
entrance.

## Optimized results

### Combined optimized results

| Metric | Samples | p50 | p95 |
|---|---:|---:|---:|
| Dashboard open -> first graph visible | 30 | 790.883 ms | 827.829 ms |
| Dashboard open -> live usage available | 30 | 1,220.135 ms | 1,378.961 ms |
| Dashboard open -> first non-empty state | 30 | 425.571 ms | 473.127 ms |
| Dashboard open -> entrance animation complete | 30 | 1,801.067 ms | 1,920.610 ms |

### Optimized by launch state

| Launch state | Metric | Samples | p50 | p95 |
|---|---|---:|---:|---:|
| Process cold | First graph visible | 15 | 796.027 ms | 820.928 ms |
| Process cold | Live usage available | 15 | 1,338.969 ms | 1,391.877 ms |
| Process cold | Animation complete | 15 | 1,716.477 ms | 1,893.521 ms |
| Activity warm | First graph visible | 15 | 762.910 ms | 830.210 ms |
| Activity warm | Live usage available | 15 | 1,120.651 ms | 1,232.267 ms |
| Activity warm | Animation complete | 15 | 1,873.666 ms | 1,973.825 ms |

## Before vs after

Negative changes are faster/lower. Positive changes are slower/higher.
Percentages use the unrounded raw nearest-rank values.

| Metric | Baseline p50 | Optimized p50 | Change | Baseline p95 | Optimized p95 | Change |
|---|---:|---:|---:|---:|---:|---:|
| First useful graph | 1,340.781 ms | 790.883 ms | -41.0% | 1,700.304 ms | 827.829 ms | -51.3% |
| Fresh-data completion | 683.059 ms | 1,220.135 ms | +78.6% | 843.515 ms | 1,378.961 ms | +63.5% |
| Entrance animation completion | 2,151.270 ms | 1,801.067 ms | -16.3% | 2,493.051 ms | 1,920.610 ms | -23.0% |

The diagnostic first-non-empty-state milestone fell from 953.288 ms to
425.571 ms at p50 (-55.4%) and from 1,292.382 ms to 473.127 ms at p95 (-63.4%).

## Interpretation

The stale-while-revalidate goal was achieved on this device with an existing
same-day snapshot. The first useful graph became visible 41.0% sooner at p50 and
51.3% sooner at p95. The narrower post-change p50/p95 spread also shows that the
cache-first path reduced the cold/warm gap for graph visibility. The graph was
visible before live usage completed in all 30 optimized samples and in none of
the 30 baseline samples.

Fresh-data completion regressed: open-to-live was 78.6% higher at p50 and 63.5%
higher at p95. This is an ordering tradeoff, not evidence that Android's
UsageStats query itself became slower. The optimized path deliberately opens and
filters the SQLite snapshot before starting the authoritative live query, while
the baseline started live usage earlier. The user sees cached data before this
later milestone, and the fresh result silently replaces it.

Entrance completion improved, but the result combines the earlier chart mount,
device frame scheduling, and the revised cached-layout animation. This benchmark
does not isolate packing CPU time. Deterministic widget coverage separately
verifies that packing runs once per items/size change rather than once per
animation frame.

## Correctness and verification

Deterministic tests cover cache-first publication, no cached snapshot, missing
Usage Access, local-day rollover and exact day selection, retained content during
silent refresh, cached-data preservation after a failed live refresh,
destructive no-cache failure, independent auxiliary loads, direct SQLite cache
reads without metadata lookup, and bubble-layout reuse. Static analysis passed,
and the complete Flutter suite passed with 79 tests.

## Cached icon hydration

This follow-up keeps `daily_app_usage` usage-only. It measures and changes only
how names and icons are restored after the cache-first graph is published.

### Icon measurement definitions

The debug instrumentation adds the following milestones to the existing
monotonic dashboard run clock:

1. `cached_state_published`: the SQLite summaries have been published, including
   top-10 and real-icon counts;
2. `first_bubble_frame` plus `initial_graph_icon_state`: the first graph frame
   and the number of its top-10 items with non-null `iconBytes`;
3. `icon_hydration_start`: the operation expected to supply the missing icons;
4. `icon_hydration_complete`: that operation returned, with the number of
   requested top-10 packages for which an icon was available; and
5. `first_all_available_icons_frame`: the first post-frame callback where every
   available top-10 icon is present in the bubble items.

`Placeholder duration` is milestone 5 minus milestone 2. “Real icons available”
means non-null icon bytes reached the Flutter bubble model; it does not prove
that every PNG pixel had completed GPU rasterization or was perceived by a user.

The pre-change source for milestones 3–4 was the full live UsageStats refresh.
The post-change source is the independent `getAppMetadata` request. Native debug
records additionally retain payload size, metadata time, and memory/disk/
regeneration/failure counts.

### Icon benchmark procedure

The same Samsung, retained app data, ADB script, and 15 paired process-cold/
activity-warm procedure were used before and after. All 30 rows in each icon CSV
were complete and included; no samples or outliers were removed. The first
post-change pilot migrated legacy package-only files to versioned filenames and
was excluded. The measured post-change run therefore represents unchanged-app
disk reuse after process restart. The final device checks showed USB power,
86% battery, 34.2 C battery temperature, and Android thermal status 0.

All 30 pre-change and all 30 post-change first graph frames contained 0/10 real
icons. All requested top-10 packages returned usable icon bytes in the measured
runs, so the all-available target was 10/10 throughout.

### Icon before vs after

Negative changes are faster. Positive changes are slower. Because launch state
materially affects this path, cold and warm results are reported separately.

| Launch state | Metric | Before p50 | After p50 | Change | Before p95 | After p95 | Change |
|---|---|---:|---:|---:|---:|---:|---:|
| Process cold | First graph visible | 829.972 ms | 834.261 ms | +0.5% | 882.255 ms | 907.588 ms | +2.9% |
| Process cold | Top-10 real icons available | 1,820.446 ms | 1,407.093 ms | -22.7% | 1,932.976 ms | 1,772.812 ms | -8.3% |
| Process cold | Placeholder duration | 1,027.124 ms | 576.696 ms | -43.9% | 1,115.369 ms | 974.671 ms | -12.6% |
| Process cold | Fresh usage completion | 1,335.813 ms | 1,406.803 ms | +5.3% | 1,451.924 ms | 1,709.411 ms | +17.7% |
| Activity warm | First graph visible | 769.801 ms | 751.253 ms | -2.4% | 812.253 ms | 806.371 ms | -0.7% |
| Activity warm | Top-10 real icons available | 1,767.646 ms | 1,260.989 ms | -28.7% | 1,901.483 ms | 1,381.107 ms | -27.4% |
| Activity warm | Placeholder duration | 1,031.515 ms | 526.916 ms | -48.9% | 1,130.293 ms | 622.694 ms | -44.9% |
| Activity warm | Fresh usage completion | 1,234.112 ms | 1,373.690 ms | +11.3% | 1,342.284 ms | 1,506.644 ms | +12.2% |

The post-change native top-10 metadata request took 119.140 ms p50 /
359.311 ms p95 process-cold and 21.751 ms p50 / 69.989 ms p95
activity-warm. Across 150 cold metadata icon lookups, 143 were versioned disk
hits and seven were memory hits caused by a concurrent request; across 150 warm
lookups, all 150 were disk hits. There were zero regenerations, failures, and
missing packages in the measured run. The excluded migration pilot regenerated
eight entries once, after which subsequent process starts reused disk data.

### Implementation

After publishing the same-day SQLite snapshot, the ViewModel now starts two
independent operations:

- top-10 cached package metadata is requested first through the existing
  `getAppMetadata` channel, merged into the currently visible summaries without
  changing totals, shares, launches, or refresh/loading state, then any remaining
  cached packages are hydrated in a second lower-priority batch; and
- authoritative UsageStats refresh proceeds independently and still replaces
  usage fields when it completes.

Metadata errors, omitted/uninstalled packages, and null icon encodes leave the
existing Material fallback visible. Late responses are ignored after a day,
load generation, or disposal change. An icon-only state update does not change
the chart layout signature or restart its 1,200 ms entrance animation. A corrupt
image that reaches Flutter also uses the Material fallback through the image
error builder.

The Android derived disk cache key is now
`<packageName>-<PackageInfo.lastUpdateTime>.png`. The in-memory Android and Dart
caches use the same metadata version signal. Unchanged apps reuse disk across
process/activity recreation; an updated app gets one new derived PNG; removed
apps and encode failures return safely; and cache eviction regenerates normally.
PNG cache entries are validated before reuse. Legacy and obsolete versions are
cleaned only while a miss is already regenerating that package, avoiding a
directory sweep on the normal startup hit path.

### Live icon payload audit

The regular live response still carried 80,715 icon bytes in these runs. A
separate debug-only physical-device A/B used ten paired cold opens with live icon
bytes enabled and disabled while leaving metadata hydration unchanged:

| Live payload | Samples | Platform call p50 | Platform call p95 | Native metadata p50 | Icon bytes |
|---|---:|---:|---:|---:|---:|
| With icons | 10 | 332.157 ms | 465.305 ms | 1.424 ms | 80,715 |
| Without icons | 10 | 285.745 ms | 438.820 ms | 1.081 ms | 0 |

The grouped medians differ by 46.412 ms (14.0%), but the paired with-minus-
without median was only 12.450 ms and four of ten pairs moved in the opposite
direction. Native total time was slightly higher without icons because UsageStats
query variance dominated the roughly 0.343 ms native metadata difference. The
fixed within-pair order and small sample also limit inference.

Therefore this change does **not** remove icons from the production live payload.
The A/B suggests a possible modest transport benefit, but it does not establish a
stable material improvement, and retaining icons preserves a second recovery path
when independent metadata hydration fails. A future isolated, randomized payload
experiment can revisit the API separation.

### Icon interpretation

The graph itself did not become meaningfully faster in the cold data (+0.5% p50,
+2.9% p95); that was not the target of this follow-up. The time spent showing
placeholders fell 43.9% at cold p50 and 48.9% at warm p50, and real top-10 icons
arrived 22.7% earlier cold and 28.7% earlier warm at p50.

Fresh usage completion regressed by 5.3% cold and 11.3% warm at p50, with a
17.7% cold p95 regression. The metadata request and live UsageStats work now
overlap, so they can contend for the same process, platform channel, and device
resources. This benchmark demonstrates earlier icon availability; it does not
claim that metadata hydration improved UsageStats or fresh-data latency.

Deterministic coverage now includes parallel metadata/live loading, usage-field
preservation, metadata failure, stale-generation rejection, top-10-first
batching, icon-only layout reuse, and Dart cache invalidation on package version
change. The complete Flutter suite passed with 84 tests, and the complete Android
debug JVM suite passed. Static analysis also passed.

## Limitations

- Results are specific to one Samsung SM-A366B, Android build, usage history,
  debug build, and session.
- The optimized first-graph improvement requires a non-empty snapshot for the
  current local day. First use, a new day before the first successful refresh,
  cleared local data, or an empty snapshot follows the live path instead.
- Baseline and optimized captures were sequential, not randomized. Device and OS
  caches warmed during each 15-pair run, so cold/warm results are also shown.
- The cached SQLite rows still do not store icon bytes. The graph intentionally
  renders Material fallbacks first, then independently hydrates derived cached
  metadata; the measured placeholder interval is reported above.
- The 1,200 ms entrance duration was not shortened. The chart starts earlier and
  no longer spends every animation frame replaying packing work.
- Live completion is measured before the repository's best-effort SQLite save.
  First graph visibility and animation completion are Flutter frame markers, not
  guarantees about when every pixel reached the display or was perceived.
- USB power, debug instrumentation, logging, manual OS scheduling, and thermal
  conditions can affect timings. Thermal status was not sampled continuously.
