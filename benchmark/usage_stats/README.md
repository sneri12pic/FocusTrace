# UsageStats pure aggregation baseline

> The stored CSV is the original pre-fix baseline. The filtered-aggregation
> regression is now fixed; see the [case study](../../docs/performance/README.md).
> Running this harness today measures the current implementation, not the old APK
> or the later Android device experiment.

This benchmark measures only the CPU cost of
`UsageStats.aggregateEvents(events, toMs, packageNames)` in a local JVM unit
test. Event generation, Android `UsageStatsManager.queryEvents`, conversion
from `UsageEvents`, package metadata lookups, `BlockerService.tick`, Android
main-thread scheduling, overlay display, and battery impact are outside the
timed region.

It is therefore a **pure aggregation baseline**, not an Android blocker
end-to-end benchmark.

## Dataset

The deterministic generator repeats a fixed 12-event cycle across eight
restricted and 32 unrestricted packages. Each event is 250 ms after the prior
event. The cycle contains:

- a foreground/background pair;
- a duplicate foreground lifecycle event;
- a restricted foreground event with no matching background event;
- a switch from that restricted package to an unrestricted package;
- unrestricted foreground/background pairs;
- switches between multiple restricted packages; and
- a non-lifecycle event.

The same construction is truncated at exactly 1,000, 10,000, 50,000, and
100,000 events. Dataset construction is excluded from timing.

## Method

- Build mode: Android `debug` JVM unit test; this does not run on ART.
- Clock: `System.nanoTime()` around `aggregateEvents` only.
- Warmup: 10 untimed calls per dataset size.
- Measurement: 30 calls per dataset size in one Gradle test worker, ascending
  by size.
- Statistics: raw nanoseconds plus nearest-rank p50 and p95, minimum, and
  maximum.
- Dead-code protection: every result is reduced to a checksum and written to a
  volatile field after the timed call.

Run on PowerShell:

```powershell
$env:FOCUSTRACE_BENCHMARK = '1'
.\gradlew.bat :app:testDebugUnitTest --tests "com.stepandemianenko.focustrace.UsageStatsAggregationBenchmarkTest" --rerun-tasks --no-daemon
```

The benchmark is skipped during ordinary unit-test runs unless
`FOCUSTRACE_BENCHMARK=1` is set.

## Correctness baseline

`UsageStatsTest.unrequestedForegroundClosesRequestedAppWithoutBackgroundEvent`
is an active regression test for the filtered aggregation defect. Its trace is:

1. restricted A enters foreground at 0 ms;
2. unrestricted B enters foreground at 1,000 ms with no background event for
   A; and
3. the filtered query for A ends at 5,000 ms.

The correct total for A is 1,000 ms. The original implementation reported
5,000 ms, so the regression initially failed with:

```text
expected:<1000> but was:<5000>
```

Run the regression (now expected to pass) with:

```powershell
.\gradlew.bat :app:testDebugUnitTest --tests "com.stepandemianenko.focustrace.UsageStatsTest.unrequestedForegroundClosesRequestedAppWithoutBackgroundEvent" --rerun-tasks --no-daemon
```

## Limitations

- Results include JVM JIT and garbage-collection behavior, not Android ART.
- All sizes run in one process, so later sizes benefit from earlier execution.
- The trace is deterministic and covers known event shapes, but it is not a
  recording from a real device.
- CI host scheduling and power management can add noise. Treat a single run as
  a baseline artifact, not a universal performance claim.
- This cannot measure the current blocker hot path's two Android event queries,
  main-thread work, metadata calls, one-second cadence, or overlay latency.

## Midnight boundary

The midnight concern cannot be represented as a truthful regression test at
the current pure aggregation boundary. `aggregateEvents` receives only the
events returned inside the query and the query end time. It receives neither
the query start nor the package that was already foreground before that start.

Consequently, these two real-world states produce identical pure inputs:

1. an app entered foreground before midnight and remained foreground; and
2. no app was foreground during the query.

Supplying a synthetic foreground event at midnight would remove the condition
being tested. Correct midnight coverage therefore belongs at the
`UsageStatsManager/queryEvents` adapter boundary, or after a future explicit
initial-state input is introduced. No such production change is part of this
baseline phase.

## Results

Raw output and the environment from the first baseline run are stored under
`benchmark/usage_stats/results/`.

The 2026-08-21 local baseline summary is:

| Events | p50 (ns) | p95 (ns) | Min (ns) | Max (ns) |
|---:|---:|---:|---:|---:|
| 1,000 | 423,800 | 599,000 | 385,000 | 648,400 |
| 10,000 | 805,200 | 991,900 | 757,200 | 2,703,500 |
| 50,000 | 3,398,800 | 5,061,700 | 2,467,600 | 5,067,700 |
| 100,000 | 4,608,400 | 6,619,900 | 4,080,500 | 7,549,200 |

Machine, runtime, build mode, warmup, run count, dataset construction, raw
samples, and statistic definitions are recorded in the corresponding result
file. The limitations above apply to every number in this table.
