# Blocker aggregation: original regression baseline

> Historical record of the initial failing regression. The implementation has
> since been fixed and the blocker now uses incremental queries. Read the
> [case study](performance/README.md) and [device results](performance/android-blocker.md)
> for the current implementation. Test results below belong to the baseline phase.

### Changes

- Restored the Dart formatting gate for four existing files:
    - app_localizations_x.dart
    - block_routine_test.dart
    - restrictions_view_model_test.dart
    - routine_editor_sheet_test.dart

- Added the deterministic regression test android/app/src/test/kotlin/com/
  stepandemianenko/focustrace/UsageStatsTest.kt:59.

- Added an opt-in, dependency-free benchmark harness in android/app/src/test/kotlin/
  com/stepandemianenko/focustrace/UsageStatsAggregationBenchmarkTest.kt:8.

- Documented methodology, scope and midnight limitations in benchmark/usage_stats/
  README.md:1.

- Saved all 120 timing samples and environment metadata in benchmark/usage_stats/
  results/2026-08-21-windows-debug-jvm.csv:1.

### Bug reproduced

The new test is:

UsageStatsTest.unrequestedForegroundClosesRequestedAppWithoutBackgroundEvent

Trace:

- Restricted A foreground at 0 ms.
- Unrestricted B foreground at 1,000 ms.
- No background event for A.
- Filtered aggregation requests only A through 5,000 ms.

Correct result: 1,000 ms.
Current implementation: 5,000 ms.

The test deliberately fails with:

expected:<1000> but was:<5000>

The assertion was not weakened and the implementation was not fixed.

### Midnight boundary

No pure-layer test was added because it cannot truthfully represent the concern.
aggregateEvents receives neither the query start nor foreground state from before
that start. Therefore:

- “App entered foreground before midnight and remained foreground”
- “No app was foreground after midnight”

produce identical pure inputs. This limitation is documented rather than hidden
behind a synthetic event.

### Pure aggregation baseline

Environment: Windows 11, Intel Family 6 Model 183, Java 21.0.8, Kotlin 2.1.0, Gradle
8.12, Android debug JVM unit-test mode.

Each size used 10 warmups and 30 measured runs. Dataset construction was outside the
timed region.

    Events     p50 (ns)     p95 (ns)     Min (ns)     Max (ns)
━━━━━━━━━  ━━━━━━━━━━━  ━━━━━━━━━━━  ━━━━━━━━━━━  ━━━━━━━━━━━
1,000      423,800      599,000      385,000      648,400
─────────  ───────────  ───────────  ───────────  ───────────
10,000      805,200      991,900      757,200    2,703,500
─────────  ───────────  ───────────  ───────────  ───────────
50,000    3,398,800    5,061,700    2,467,600    5,067,700
─────────  ───────────  ───────────  ───────────  ───────────
100,000    4,608,400    6,619,900    4,080,500    7,549,200

The deterministic traces include foreground/background pairs, missing backgrounds,
duplicate foreground events, unrestricted switches, multiple restricted packages and
non-lifecycle events.

These numbers measure only UsageStats.aggregateEvents CPU time on a desktop JVM. They
do not measure UsageStatsManager.queryEvents, event conversion, package lookups,
blocker scheduling, overlay latency, battery impact or Android ART performance.
Android end-to-end cost remains unmeasured.

### Verification

- Dart format gate: 95 files checked, 0 changes
- flutter analyze: passed
- Flutter tests: 69 passed
- Opt-in aggregation benchmark: passed
- Android unit suite: 18 tests: 1 expected regression failure, 1 skipped benchmark
- No optimization, README rewrite, new dependency or unrelated architecture added.

The working tree already contained unrelated changes, so I did not create commits
that might mix with the user’s work.
