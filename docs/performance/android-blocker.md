# Android Blocker Performance

This report contains a physical-device baseline of the original `BlockerService`
hot path and a directly comparable run after an incremental UsageStats change.
It is separate from the desktop JVM `aggregateEvents` regression benchmark.

## Device and build

- Benchmark date: 2026-08-21 (Europe/London)
- Device: Samsung SM-A366B (`arm64-v8a`, Qualcomm hardware)
- Android: 16, API 36
- OS build: `BP4A.251205.006.A366BXXSBCZG1`
- App package/build: debug application, version `1.0.6-dev` (`versionCode` 7),
  target SDK 35, min SDK 21
- Installed APK SHA-256:
  `79D05EF442E32A3D2E86ADFEB5CE74E88A129202D06B36DBC52BB4681DF3C2D9`
- Source revision: `1528c1a774a2cb805bbfb029623b5156187a5455`, with the benchmark
  instrumentation and other uncommitted working-tree changes present
- Build host: Microsoft Windows NT 10.0.26200.0; Java 26.0.1 was on the host
  command path
- Device connection: physical device over USB; `dumpsys battery` reported USB
  power enabled. Battery was 74% and 29.9 C at the final metadata read.
- Thermal state: Android reported thermal status 0 (no throttling status) at the
  final metadata read. This was not sampled continuously.

The installed package was confirmed as debuggable. Usage access
(`GET_USAGE_STATS`) and overlay (`SYSTEM_ALERT_WINDOW`) app-ops were both
`allow` during the final metadata check.

## Methodology

### Instrumentation

Instrumentation is enabled only when Android marks the installed application
as debuggable. A non-debuggable production build neither creates timing records
nor emits the benchmark log. No package names, app names, rules, usage history,
or user identifiers are recorded.

Each service tick emits one `FocusTraceBlockerPerf` record containing:

- UsageStats query count and combined number of `UsageEvents` iterated by all
  queries in the tick;
- minimum query start, maximum query end, and the resulting wall-clock query
  window;
- summed `UsageStatsManager.queryEvents` plus iteration time;
- pure aggregation time;
- restriction/routine decision time;
- total synchronous tick time;
- age of the latest foreground event and event-to-decision latency; and
- action category: `none`, `overlay`, or `block_activity`.

For a blocking action, the first draw of the block UI emits a second record with
decision-to-presentation and foreground-event-to-presentation latency. Code
durations use `SystemClock.elapsedRealtimeNanos()`. Android UsageEvent timestamps
are Unix wall-clock timestamps, so event-to-decision and event-to-presentation
necessarily use `System.currentTimeMillis()` and are vulnerable to wall-clock
changes.

The baseline intentionally retains the current hot path: each tick separately
queries from local midnight to now for restricted usage totals and current
foreground detection. No blocker optimization is included.

### Scenarios and repetitions

The service and permissions were set up before measurement. The selected blocked
target follows the full-screen `block_activity` path, so this run contains no
overlay-presentation samples.

| Scenario | Procedure | Human-observed attempts | Included instrumented records |
|---|---|---:|---:|
| Unrestricted -> unrestricted | Switch between two unrestricted system surfaces and allow the service to continue polling | One controlled transition followed by steady polling | 34 ticks, all `none` |
| Unrestricted -> blocked and repeated blocked/unblocked | Repeatedly leave the block screen and reopen the blocked target | 42 blocked transitions | 34 complete tick/presentation pairs |
| Exceeded daily limit | Set a daily limit below already accumulated usage, then reopen the target | 5 blocked transitions | 7 complete tick/presentation pairs |
| Scheduled restriction | Configure an active schedule containing the current time, then reopen the target | 5 blocked transitions | 7 complete tick/presentation pairs |
| Routine restriction | Enable a routine containing the target with its limit below accumulated usage, then reopen the target | 5 blocked transitions | 8 complete tick/presentation pairs |

The raw service action count is not a one-to-one count of human attempts. The
one-second poller can act again during a manual leave/re-entry sequence, and
logcat capture boundaries can omit an action or presentation record. Therefore,
manual missed-block observations and paired instrumentation sample counts are
reported separately. Only complete action/first-draw pairs are used for UI
latency.

### Warmup and sample selection

- The first 10 unrestricted ticks were retained in the CSV with
  `included=false` and excluded as warmup.
- The app, service, permissions, and rule configuration were already active
  before each blocking capture. Every complete blocking tick/presentation pair
  in the capture was included; no latency outliers were removed.
- The CSV contains 100 tick records and 56 presentation records. Reported tick
  distributions use 90 included ticks. Presentation distributions use all 56
  complete included pairs.
- Restriction decision timing exists for 71 included ticks. Nineteen
  unrestricted ticks exited before rule evaluation because no external
  foreground package required a decision.

### Statistics

Percentiles use the nearest-rank definition over the included raw samples:
sort ascending and select rank `ceil(p * n)`. Durations stored as nanoseconds
were converted to milliseconds only for the tables below. No synthetic event
dataset is involved: the dataset is the device's actual UsageStats event stream
from local midnight to each tick's `query_to_ms`.

Across included ticks, the query window was 63,293,335 ms at p50,
64,279,591 ms at p95, and 64,302,931 ms maximum. It grew throughout the session
because the current implementation always starts at local midnight.

## Baseline results

### Blocker tick work

| Metric | Samples | p50 | p95 | Max |
|---|---:|---:|---:|---:|
| Total blocker tick | 90 | 59.044 ms | 156.989 ms | 217.798 ms |
| UsageStats query + iteration, summed across both queries | 90 | 35.026 ms | 86.394 ms | 159.069 ms |
| Pure aggregation | 90 | 1.477 ms | 5.676 ms | 9.584 ms |
| Restriction/routine decision | 71 | 0.064 ms | 0.171 ms | 0.264 ms |

The pure aggregation row is only the in-process aggregation after the first
event query. It is not Android UsageStats query cost and is not end-to-end block
latency.

### Blocking latency

| Metric | Samples | p50 | p95 | Max |
|---|---:|---:|---:|---:|
| Foreground UsageEvent -> blocker decision | 56 | 552 ms | 1,141 ms | 1,199 ms |
| Blocker decision -> first block UI draw | 56 | 616.736 ms | 758.580 ms | 838.098 ms |
| Foreground UsageEvent -> first block UI draw | 56 | 1,106 ms | 1,688 ms | 1,866 ms |

All 56 presentation samples are for `block_activity`. The overlay path remains
unmeasured in this baseline.

### Event and query volume

| Metric | Samples | Median | p95 | Max |
|---|---:|---:|---:|---:|
| UsageEvents iterated per tick, combined across both queries | 90 | 3,432 | 4,744 | 4,866 |
| UsageStats queries per tick | 90 | 2 | 2 | 2 |

Because both calls scan the same midnight-to-now window, the event count is the
combined work of both scans, not the number of unique UsageEvents in the window.

### Observed correctness during the run

- Missed blocks: 0 reported across 57 manual blocked-transition attempts
  (42 repeated block/unblock, then 5 each for daily-limit, schedule, and routine).
- False positives: 0 blocker actions across the 34 included unrestricted control
  ticks.

These are observations from this controlled run, not general failure-rate
estimates. Manual attempt counts cannot be joined one-to-one to instrumentation
records for the reason described above.

## Raw evidence

The raw, privacy-filtered measurement samples are in
[2026-08-21-blocker-baseline.csv](../../benchmark/android/results/2026-08-21-blocker-baseline.csv).

CSV columns are the scenario, record type, tick ID, query/event counters, query
window, nanosecond timing fields, latest-event age and wall-clock latency fields,
action category, and the analysis inclusion flag. Blank fields do not apply to
that record type. The file contains no application identifiers or rule content.

## Interpretation

On this device and event history, the current service performed exactly two
UsageStats queries on every measured tick and iterated a median 3,432 events per
tick. UsageStats query/iteration time was materially larger than pure aggregation
or rule evaluation in the measured distributions. This evidence supports
targeting redundant Android UsageStats scans rather than optimizing the already
small pure aggregation step.

Foreground-event-to-UI latency includes both poll alignment and block activity
presentation. The measured decision-to-first-draw portion was hundreds of
milliseconds in this run, while the event-to-decision distribution reached just
over one polling interval at p95. The data does not isolate Android scheduling,
activity launch, rendering, and OEM UsageStats publication delay from one another.

## Incremental UsageStats optimization

The isolated change replaces the two midnight-to-now queries in each service
tick with one query backed by in-memory state. A bootstrap reconstructs today's
restricted usage and foreground state. Later ticks query from the timestamp of
the newest successfully observed event to `now`, retain event identities at the
inclusive start boundary for deduplication, and commit each newly observed
foreground interval once. An open restricted foreground interval is evaluated
through `now` without repeatedly committing it.

The state is deliberately not persisted. It is invalidated and rebuilt after a
service/process restart, Usage Access loss or restoration, local-day rollover,
backwards wall-clock movement, or a change to the set of restricted packages.
Foreground switches from unrestricted packages are still tracked so they close
a stale restricted session without adding unrestricted usage totals.

### Correctness finding during device verification

The first device trial advanced its cursor to the end of every successful query.
On this Samsung device, UsageEvents could appear after an earlier query had
returned an empty window. That trial produced roughly 8–10 manually reported
misses and duplicate block screens after an app restart. It was rejected and is
not represented in the incremental CSV or comparison.

The corrected implementation advances the event cursor only to the latest event
actually returned. Empty queries retain the cursor, so the next query covers the
unobserved tail again; boundary records already processed are deduplicated. A
10-attempt pilot then had 0 reported misses. Pilot records were discarded before
the official capture.

### Post-change methodology

The post-change run used the same physical Samsung SM-A366B, Android 16/API 36,
debug package/version, permissions, USB power, 1-second service poll interval,
instrumentation fields, action route, manual procedures, and nearest-rank
statistics as the baseline. The installed incremental APK SHA-256 was
`0C414AC046659925330847F0C24CFEFA44D96743399C171E67E1E9C21BF0783A`.

| Scenario | Human-observed attempts | Included instrumented records |
|---|---:|---:|
| Unrestricted -> unrestricted | One controlled transition followed by steady polling | 34 ticks, all `none` |
| Unrestricted -> blocked and repeated blocked/unblocked | 42 blocked transitions | 40 complete tick/presentation pairs |
| Exceeded daily limit | 5 blocked transitions | 5 complete tick/presentation pairs |
| Scheduled restriction | 5 blocked transitions | 7 complete tick/presentation pairs |
| Routine restriction | 5 blocked transitions | 11 complete tick/presentation pairs |

The first 10 unrestricted ticks are retained with `included=false` as warmup.
All complete blocking tick/presentation pairs were included, with no latency
outlier removal. The incremental CSV contains 107 tick records and 63
presentation records; distributions use 97 included ticks and all 63 complete
pairs. The count difference between manual attempts and service actions has the
same polling/capture explanation as the baseline.

Across included incremental ticks, the query window was 1,729 ms at p50,
36,536 ms at p95, and 48,439 ms maximum. The window can span more than one poll
when no new event has yet been observed, because the cursor intentionally stays
at the latest returned event instead of skipping a possibly late-published tail.

### Post-change results

| Metric | Samples | p50 | p95 | Max |
|---|---:|---:|---:|---:|
| Total blocker tick | 97 | 32.977 ms | 95.233 ms | 198.107 ms |
| UsageStats query + iteration | 97 | 3.626 ms | 11.296 ms | 35.349 ms |
| Incremental state aggregation | 97 | 0.155 ms | 0.485 ms | 0.774 ms |
| Restriction/routine decision | 97 | 0.028 ms | 0.131 ms | 0.159 ms |

| Blocking latency | Samples | p50 | p95 | Max |
|---|---:|---:|---:|---:|
| Foreground UsageEvent -> blocker decision | 63 | 512 ms | 1,091 ms | 1,099 ms |
| Blocker decision -> first block UI draw | 63 | 234.149 ms | 439.175 ms | 837.283 ms |
| Foreground UsageEvent -> first block UI draw | 63 | 761 ms | 1,268 ms | 1,496 ms |

| Work volume | Samples | Median | p95 | Max |
|---|---:|---:|---:|---:|
| UsageEvents iterated per tick | 97 | 4 | 6 | 8 |
| UsageStats queries per tick | 97 | 1 | 1 | 1 |

Observed correctness in the official post-change run was 0 missed blocks across
57 controlled manual blocked attempts, 0 stacked block screens reported in those
attempts, and 0 blocker actions across the 34 included unrestricted control
ticks. These remain controlled observations, not population failure rates.

The raw post-change evidence is in
[2026-08-21-blocker-incremental.csv](../../benchmark/android/results/2026-08-21-blocker-incremental.csv).

## Before vs after

Negative percentage changes mean a lower measured value. Percentages are based
on the unrounded raw values in the two CSV files.

| Metric | Baseline | Incremental | Change |
|---|---:|---:|---:|
| UsageStats queries/tick | 2 | 1 | -50.0% |
| Events iterated/tick, median | 3,432 | 4 | -99.9% |
| Events iterated/tick, p95 | 4,744 | 6 | -99.9% |
| Query + iteration, p50 | 35.026 ms | 3.626 ms | -89.6% |
| Query + iteration, p95 | 86.394 ms | 11.296 ms | -86.9% |
| Total tick, p50 | 59.044 ms | 32.977 ms | -44.1% |
| Total tick, p95 | 156.989 ms | 95.233 ms | -39.3% |
| Event -> decision, p50 | 552 ms | 512 ms | -7.2% |
| Event -> decision, p95 | 1,141 ms | 1,091 ms | -4.4% |
| Decision -> first draw, p50 | 616.736 ms | 234.149 ms | -62.0% |
| Decision -> first draw, p95 | 758.580 ms | 439.175 ms | -42.1% |
| Event -> first draw, p50 | 1,106 ms | 761 ms | -31.2% |
| Event -> first draw, p95 | 1,688 ms | 1,268 ms | -24.9% |
| Missed blocks / controlled attempts | 0 / 57 | 0 / 57 | Not applicable |
| False blocker actions / included control ticks | 0 / 34 | 0 / 34 | Not applicable |

### Interpretation of UsageStats work

On this device and these event histories, the experiment achieved its direct
mechanical objective: measured steady-state ticks made one query instead of two
and iterated single-digit events rather than replaying thousands. Query and
iteration time fell substantially in both reported percentiles. Total
synchronous tick time also fell, but it did not fall in direct proportion to
query time because configuration loading, notification checks, service work,
and normal device scheduling remain in the total.

### Interpretation of blocking latency

All three blocking-latency distributions were lower in the post-change session,
but this experiment did not change the poll interval or block activity/UI path.
The result therefore shows an observed session-level difference, not proof that
incremental querying caused the full UI-latency reduction. Poll alignment,
Android scheduling, UsageEvent publication timing, manual interaction, and
activity startup/rendering remain mixed into those measurements. The stronger
causal evidence is the direct reduction in query count, iterated event count,
and measured query/iteration duration.

## Limitations

- Results are specific to one Samsung SM-A366B, its current event history, its
  firmware, and one session. They are not universal Android performance claims.
- OEM and Android versions can differ in UsageStats event publication, ordering,
  duplication, omission, and query cost.
- This is a debuggable build. Release compilation, tracing overhead, and system
  scheduling may differ. The instrumentation itself performs clocks, counters,
  one structured log per tick, and one log per measured first draw.
- The device was connected and USB-powered. Battery life and unplugged thermal
  behavior were not measured. Thermal state was checked only at the end.
- The service schedules the next tick 1,000 ms after the previous tick completes.
  Poll alignment is therefore a major component of foreground-event latency and
  the actual cadence also includes the preceding tick's work.
- Event-to-decision and event-to-presentation mix Android wall-clock UsageEvent
  timestamps with current wall time; clock adjustments during a sample would
  distort them. Internal code durations use a monotonic clock.
- Only the full-screen block activity route was exercised. Overlay presentation
  performance was not measured.
- Human interaction controlled the blocked scenarios. Attempt counts and
  instrumentation records are intentionally not treated as a one-to-one mapping.
- The event stream grew from roughly 3,200 to 4,866 combined iterations per tick
  during this session. Different usage intensity and time of day can change scan
  volume and latency.
- Baseline and incremental captures occurred on the same device and date but at
  different times with different accumulated event histories and manual action
  timing; this is not a randomized experiment.
- Incremental state is in memory. A service/process restart deliberately incurs
  a fresh day bootstrap, which is required for correctness but is excluded from
  the steady-state comparison.
- Retaining the latest observed-event boundary protects the late publication
  reproduced in this session, but OEM event ordering and arbitrarily delayed
  older events are not guaranteed by this single-device test.
- The benchmark measures blocker computation and first draw, not whether every
  pixel was fully rendered or when the user perceived the UI.
