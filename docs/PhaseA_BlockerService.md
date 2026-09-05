# Blocker correctness fix and optimization design

> Historical design record. Phase A was completed here; the later incremental
> implementation and physical-device measurements are documented in the
> [case study](performance/README.md) and [blocker report](performance/android-blocker.md).
> Statements about the current hot path below describe the pre-optimization build.

  ## Phase A — correctness fix

  In android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageStats.kt:146,
  stale requested sessions are now closed before an unrequested foreground event is
  discarded.

  This means unrestricted events participate in foreground transitions but never create
  accumulated usage entries.

  The regression in android/app/src/test/kotlin/com/stepandemianenko/focustrace/
  UsageStatsTest.kt:59 now proves:

  - Restricted A totals exactly 1,000 ms.
  - A retains one launch.
  - The result contains only A; unrestricted B is not accumulated.

  ### Verification

  - Full Android JVM suite: 18 tests, 17 passed, 1 opt-in benchmark skipped, 0 failures
  - Regression: passed
  - Opt-in benchmark: passed twice after the fix
  - Relevant diff whitespace check: passed

  ### Benchmark comparison

  Same machine, runtime, datasets, 10 warmups and 30 measured runs:

    Events    Previous p50    Post-fix p50 #1    Post-fix p50 #2
  ━━━━━━━━━  ━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━
     1,000      423,800 ns         437,799 ns         443,701 ns
  ─────────  ──────────────  ─────────────────  ─────────────────
    10,000      805,200 ns         769,001 ns         767,300 ns
  ─────────  ──────────────  ─────────────────  ─────────────────
    50,000    3,398,800 ns       2,406,400 ns       2,262,100 ns
  ─────────  ──────────────  ─────────────────  ─────────────────
   100,000    4,608,400 ns       4,057,200 ns       4,119,199 ns

  There is no measured regression. Larger traces happened to run faster, but one pre-
  fix JVM process is insufficient evidence to claim a material performance improvement.
  The defensible conclusion is that performance remains in the same low-single-digit-
  millisecond class and aggregate complexity remains linear.

  ## Phase B — current hot path

  Every one-second android/app/src/main/kotlin/com/stepandemianenko/focustrace/
  BlockerService.kt:72 currently performs:

  1. A midnight→now query for restricted usage totals at android/app/src/main/kotlin/
     com/stepandemianenko/focustrace/BlockerService.kt:96.

  2. Another midnight→now query for foreground detection at android/app/src/main/
     kotlin/com/stepandemianenko/focustrace/BlockerService.kt:99.

  Both run synchronously from the main-thread handler. The expensive unknown is
  Android’s query/Binder/event-delivery work—not pure aggregation.

  Android documents queryEvents windows as inclusive at the beginning and exclusive at
  the end. It also notes that events are retained for only a few days and that queries
  may return null while the user is locked on Android R and later. Android
  UsageStatsManager documentation
  (https://developer.android.com/reference/android/app/usage/UsageStatsManager.html#queryEvents(long,%20long))

  ### Design comparison

   Concern                Steady-state work
   A. Incremental state   One [cursor, now) query; process only new events
   B. Split cadence       Short foreground query each tick; full totals query every K
                          ticks
   C. Combined full scan  One midnight→now query each tick
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Structural reduction
   A. Incremental state   Approximately 2N → ΔN events after bootstrap
   B. Split cadence       Approximately 2N → Δforeground + N/K
   C. Combined full scan  2N → N
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Usage correctness
   A. Incremental state   Current, including an open foreground interval evaluated
                          through now
   B. Split cadence       Totals can lag by the refresh cadence
   C. Combined full scan  Same freshness as today
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Restart
   A. Incremental state   Rebuild state once from retained events
   B. Split cadence       Rebuild foreground state and totals
   C. Combined full scan  Naturally stateless
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Midnight
   A. Incremental state   Reset totals while carrying current foreground state
   B. Split cadence       Reset cache; carry/rebuild foreground state
   C. Combined full scan  Still cannot infer a session that began before midnight
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Boundary duplicates
   A. Incremental state   Chain [previousEnd, newEnd); prior end was exclusive
   B. Split cadence       Same for foreground cursor
   C. Combined full scan  Recomputed each tick, so no cross-tick accumulation
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Duplicate lifecycle events
   A. Incremental state   Pure state reducer ignores duplicate resume/pause transitions
   B. Split cadence       Foreground reducer must do the same
   C. Combined full scan  Existing aggregation behavior can be reused
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Missing backgrounds
   A. Incremental state   Any later foreground event closes the stale session
   B. Split cadence       Foreground state can close it; cached totals remain stale
                          until refresh
   C. Combined full scan  Fixed aggregator closes it
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Permission loss
   A. Incremental state   Invalidate state; rebuild after restoration
   B. Split cadence       Invalidate both caches; refresh after restoration
   C. Combined full scan  Retry a fresh scan after restoration
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Clock/time-zone changes
   A. Incremental state   Detect cursor reversal or changed local-day boundary and
                          rebuild
   B. Split cadence       Invalidate both cadences and rebuild
   C. Combined full scan  Recomputing from current midnight is naturally simpler
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Complexity
   A. Incremental state   Medium
   B. Split cadence       Medium; two clocks plus stale-data policy
   C. Combined full scan  Low
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Testability
   A. Incremental state   High with a pure state-transition reducer
   B. Split cadence       Good, but requires fake clock/cadence tests
   C. Combined full scan  High with one pure combined fold
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Battery expectation
   A. Incremental state   Best structural reduction; still one Binder query per tick
   B. Split cadence       Depends on K; full scans continue periodically
   C. Combined full scan  Roughly halves scans but retains growing daily work
  ─────────────────────────────────────────────────────────────────────────────────────
   Concern                Persistence required
   A. Incremental state   No; bootstrap after process restart
   B. Split cadence       No
   C. Combined full scan  No

  ### Recommendation

  Use A: one combined incremental state machine, without persisted state initially.

  Minimal shape:

  1. On the first valid tick, process one bootstrap query and establish:
      - current foreground package and start time;
      - closed usage totals for configured packages;
      - cursor timestamp.

  2. Each later tick performs one query over [cursor, now).
  3. The same event pass updates foreground state and usage totals.
  4. Open foreground usage is calculated through now without repeatedly committing the
     same interval.

  5. Advance the cursor only after the query is fully consumed successfully.
  6. On process restart, permission restoration, cursor reversal, local-day boundary
     change, or relevant configuration change, discard state and bootstrap again.

  Persistence is unnecessary initially: occasional restart reconstruction is simpler
  and safer than versioning partially written cursor state. A startup replay should
  include enough pre-midnight history to seed foreground state and clip totals at
  midnight; if the originating event has already fallen outside Android’s retention
  window, exact reconstruction is impossible.

  Design C is the safest intermediate fallback, but it still performs a growing full-
  day scan every second. Design B weakens daily-limit enforcement through stale totals,
  and adding threshold-sensitive refresh logic quickly approaches the complexity of A.

  ## Phase C — measurement plan

  Instrument the current implementation before redesign so before/after evidence uses
  identical definitions.

  For every tick, record:

  - query_count
  - events_processed, total and per query
  - query_from_ms, query_to_ms, and query_window_ms
  - query acquisition/iteration time using SystemClock.elapsedRealtimeNanos()
  - aggregation time
  - restriction/routine decision computation time
  - total tick time
  - age of the latest foreground event when the decision is made
  - action type: none, overlay, or block activity

  Implementation approach:

  - Accumulate one small BlockerTickMetrics value during tick().
  - Count events where UsageEvents.getNextEvent is called.
  - Use monotonic timing around queries and decision evaluation.
  - Emit one structured CSV/JSON log line only when BuildConfig.DEBUG is true.
  - Do not log package names or rule contents.
  - A future release-like benchmark build can enable the same metric flag without
    enabling general debug logging.

  Collect reproducible traces with adb logcat on the same physical device for:

  - Stable foreground app.
  - Repeated restricted/unrestricted switches.
  - Missing-background transitions.
  - Daily/routine limit crossing.
  - Permission revoke and restoration.
  - Service/process restart.
  - Midnight or controlled time-zone transition.

  Compare raw and p50/p95/max values for event count, query count, query time, decision
  time and total tick time. For real blocking latency, measure from the relevant
  foreground event timestamp to successful overlay/activity presentation; this includes
  polling delay and Android query latency.

  Metric calculation and state-reducer tests can run in CI. Real UsageStatsManager
  latency and event delivery require an instrumented physical-device or device-lab run
  and must not be represented by the JVM benchmark.

  No major blocker redesign, README change, dependency or additional architecture was
  implemented.

## Benchmark environment clarification

The aggregation benchmarks in this historical phase ran on Windows 11 using a desktop JVM:

  - CPU: Intel Family 6 Model 183
  - Java: 21.0.8
  - Kotlin: 2.1.0
  - Gradle: 8.12
  - Mode: Android debug JVM unit test

  They measure only pure Kotlin aggregation CPU time—not Android ART,
  UsageStatsManager, Binder calls, battery usage, or blocker end-to-end latency.
