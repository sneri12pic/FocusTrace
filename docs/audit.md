# Phase 1 audit

> Historical baseline audit, recorded before the performance work. Findings about
> repeated blocker scans, filtered aggregation, and formatting describe that
> earlier state. See the [engineering case study](performance/README.md) for the
> implemented changes, current evidence, and remaining limitations. The proposed
> work below is a plan, not a list of completed features.

No source files were modified. I audited the current working tree, including its
existing uncommitted routine/restriction changes. The generated coverage directory
was removed after measurement.

## Executive assessment

FocusTrace is a credible portfolio foundation: it has clear layering, platform
isolation, meaningful business logic, local persistence, background work, native
Android integration, Windows interop, and a non-trivial test suite.

It is not yet strongly evidence-backed or fully production-proven. The highest-
priority findings are:

1. The blocker service synchronously scans the day’s UsageStats history twice every
   second on its main thread. This is the clearest performance and battery risk.

2. Filtered UsageStats aggregation likely overcounts a restricted app when Android
   omits its background event and the next foreground app is not restricted.

3. Historical daily totals are best-effort 15-minute snapshots; delayed/missed work
   around midnight can leave incomplete days.

4. Report first-use inference repeatedly scans the interval list and has quadratic
   worst-case behavior.

5. Android Auto Backup is implicitly enabled, contradicting the strict “all data
   stays on this device” privacy claim.

6. CI currently fails its formatting gate, despite tests, analysis, lint, and debug
   assembly otherwise succeeding.
7. The critical Android enforcement path has pure-logic unit tests but no service,
   permission, boot, overlay, device, or process-lifecycle tests.

## 1. Architecture and data flows

FocusTrace uses a pragmatic MVVM-style layered structure:

Flutter screens/widgets
↓
Riverpod StateNotifier view models
↓
Domain repository interfaces + pure services/models
↓
Repository implementations
├── SQLite data source
└── Flutter MethodChannels
├── Android: UsageStats, WorkManager, blocker, widgets, SAF
└── Windows: foreground-window Win32 APIs

Composition is centralized in lib/src/presentation/providers.dart:31. The boundaries
are generally clean:

- Presentation owns UI state and orchestration.
- Application services contain pure aggregation, trend, and report logic.
- Domain contains models and repository contracts.
- Data contains SQLite and platform-channel adapters.
- Android and Windows native code remain outside the Dart domain.

This is appropriate for the project’s size. A separate use-case layer or heavier
architecture would not currently add measurable value.

Major flows:

- Android dashboard: DashboardViewModel → UsageRepositoryImpl → method channel →
  MainActivity worker thread → UsageStatsManager.queryEvents() → Dart summaries →
  filters/percentages → daily SQLite snapshot.

- Windows tracking: Dart timer → Win32 foreground-window channel → one SQLite session
  per valid sample → daily aggregation.

- Restrictions: SQLite JSON settings → Dart encoder → method channel → Android
  SharedPreferences → foreground service → overlay or BlockActivity.

- Background history: WorkManager every 15 minutes → UsageStats totals/intervals →
  direct native writes into the same SQLite database.
- Reports: refresh today and native intervals → load daily totals, intervals, and
  restriction events → pure report generation.

- Backup: transactionally read all five SQLite tables → versioned JSON → Android
  Storage Access Framework; imports merge rows transactionally.

The main architectural weakness is that Android native code directly opens the
Flutter-owned database and duplicates its filename/table/column contract. That makes
schema drift and concurrent-access behavior cross-language concerns rather than
compiler-checked concerns.

## 2. Test suite and coverage

### Current results

There are 85 statically declared tests:

- 69 Dart/Flutter tests across 25 files.
- 16 Kotlin/JUnit tests across 3 files.

Observed locally:

- All 69 Flutter tests passed.
- All 16 Android unit tests passed.
- flutter analyze passed with no issues.
- Android lint passed with no errors, but reported 23 warnings.
- Debug APK assembly passed.
- Formatting check failed on four current working-tree files:
    - app_localizations_x.dart
    - block_routine_test.dart
    - restrictions_view_model_test.dart
    - routine_editor_sheet_test.dart

Therefore the current commit state would not pass the declared CI workflow.

Coverage from flutter test --coverage:

- Raw Dart line coverage: 3,266 / 6,695 = 48.78%
- Excluding generated localization files: 2,986 / 4,768 = 62.63%
- No branch coverage was emitted.
- Kotlin coverage is not collected.

Notable Dart coverage gaps:

- ReportRepositoryImpl: 0 executable lines covered.
- SettingsRepositoryImpl: 0 covered.
- PlatformUsageDataSource: 3%.
- UsageRepositoryImpl: 41.7%.
- SettingsViewModel: 40%.
- New routine details screen: 0%.
- SQLite data source: 69.3%.
### What is covered well

- Session aggregation, clipping, percentages, trends, and duration formatting.
- Report calculations and first-use heuristics on small datasets.
- Daily snapshot round trips and v2/v3 migration behavior.
- Portable backup envelope, transactional import, merge behavior, and rollback.
- Restriction and routine JSON parsing and boundary rules.
- View-model state transitions, stale dashboard loads, transient Windows sampling
  failures, idle time, and stalled timers.

- Localization key parity and locale resolution.
- Several widget-level dashboard, onboarding, language, and routine-editor flows.
- Kotlin event aggregation, interval construction, snapshot mapping, schedule
  boundaries, and routine-limit parsing.

### Important untested paths

- BlockerService, overlay creation, foreground-service lifecycle, and BlockActivity.
- Permission revocation while blocking, boot restart, force-stop, process death, and
  notification denial.

- Actual UsageStatsManager behavior and midnight-boundary state.
- WorkManager’s real worker/store transaction, retries, delayed execution, and
  database contention.

- Native restriction-event writes and loss when SQLite is busy.
- Android MethodChannel argument/result conversion and error paths.
- Storage Access Framework lifecycle and the 10 MB limit.
- Android widgets and bitmap renderer.
- Windows C++ channel and Windows release build.
- Full release/minified build and signing.
- Auto Backup/restore behavior.
- Cross-language compatibility of the Dart and Kotlin restriction JSON contracts.

## 3. CI guarantees

The workflow in .github/workflows/ci.yml:21 runs on pushes and pull requests to
develop and master.

It guarantees, when the workflow is required and successful:

- Flutter 3.32.2 dependency resolution.
- Dart formatting for lib and test.
- Flutter static analysis.
- Flutter tests with LCOV creation.
- Kotlin/JVM Android unit tests.
- Android debug lint with no fatal lint errors.
- A buildable debug APK.

It does not guarantee:

- Any minimum coverage.
- Warning-free Android lint.
- Kotlin coverage.
- Release/AAB buildability, R8 correctness, or release signing.
- Android instrumented/device behavior.
- Windows compilation or tests.
- Performance or regression budgets.
- Privacy-permission assertions.
- Backup policy.
- Dependency vulnerability or SBOM checks.
- Branch protection; the workflow file cannot prove it is required.
- Reproducible local Gradle invocation: wrapper properties are tracked, but wrapper
  scripts/JAR are ignored. CI avoids this by installing Gradle 8.12 directly.

Coverage is uploaded for 14 days, but it is neither summarized nor enforced.

The release signing configuration also fails open to the debug certificate when
key.properties is absent in android/app/build.gradle.kts:63. Convenient for local
runs, but a production release task should fail closed.

## 4. SQLite/data-access architecture

Schema version 4 is implemented in one lib/src/data/datasources/
focus_trace_local_data_source.dart:93 with five tables:

- usage_sessions: granular Windows samples.
- settings: key/value rows containing simple values or JSON.
- daily_app_usage: (day, app_key) daily snapshot.
- usage_intervals: Android intervals and report history.
- restriction_events: blocked/unblocked report events.

Positive properties:

- Daily snapshot replacement and multi-row inserts are transactional.
- Import is one transaction and rolls back on an invalid table or row.
- Primary keys give deterministic merge behavior.
- Day keys are padded ISO dates, so range ordering is stable.
- Migrations preserve v2/v3 history in existing tests.
- Sensitive records are under the application database directory.

Risks:

- Android and Flutter open the same file through different SQLite APIs.
- No explicit WAL/busy-timeout strategy is visible.
- Native restriction-event failures are silently dropped.
- The worker retries database failures, but dashboard snapshot writes are silently
  best-effort.

- Overlap queries only index started_at; recent interval queries may scan a growing
  fraction of old rows.

- There is no retention or pruning policy.
- Windows can create one row every sampling interval rather than coalescing adjacent
  samples.

- Import validates table/column names but not semantic ranges such as negative
  durations or unreasonable timestamps.

- databaseSchemaVersion is exported but not validated during import.
- Bulk import/export loops row-by-row and materializes the full dataset in memory.

## 5. Android UsageStats processing

The pure aggregation code is thoughtful: it handles duplicate foreground events,
closes stale apps when Android omits background events, counts relaunches, closes
open intervals at query end, and filters non-launchable packages.

Two important correctness gaps remain.

First, filtered aggregation computes isRequested and skips unrequested foreground
events before closing stale requested sessions in android/app/src/main/kotlin/com/
stepandemianenko/focustrace/UsageStats.kt:129. In blocker mode, if Android omits the
restricted app’s background event and the user opens an unrestricted app, the
unrestricted foreground event is ignored. The restricted session can remain open and
accumulate time, potentially blocking early.

Second, queries begin exactly at local midnight. An app already in the foreground
before midnight has no opening event inside the query range. Its post-midnight use
may therefore be missed until another foreground transition.

Other limitations:

- Single-foreground assumptions cannot faithfully represent split-screen or picture-
  in-picture use.

- Launch count is a heuristic based on lifecycle events and a one-second relaunch
  gap.

- “User-facing” means “has a launcher intent,” which may exclude legitimate user-
  visible packages.

- Event lists are fully materialized in memory.
- Labels and launch-intent checks can repeat across many intervals.

These are defensible product heuristics, but they need quantified accuracy claims
rather than being presented as exact Android screen time.

## 6. Report and history generation

The report path is:

1. Refresh today’s snapshot if the selected period contains today.
2. Fetch native intervals from one day before the period through now.
3. Insert them into SQLite.
4. Read daily usage, intervals, and restriction events concurrently.
5. Generate weekly, monthly, or year-to-date results.

The implementation is easy to follow, but semantics need documentation:

- “Weekly” means the current week from Monday.
- “Monthly” means current calendar month.
- “Yearly” means current calendar year.
- Daily average divides by days with positive usage, not all elapsed days.
- First use is inferred only from 04:00–14:00 after at least four hours of
  inactivity.

- Peak usage ignores 00:00–04:00.
- Manual unblock counts only the explicit unblock path, not every way a rule can be
  removed.

The first-use algorithm repeatedly filters and rescans the complete sorted interval
list in lib/src/application/services/report_generation_service.dart:142. Worst-case
behavior is quadratic.

Historical totals are only as complete as the stored daily snapshots. WorkManager is
configured at its 15-minute minimum in
android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageSnapshotScheduler.kt
:10, but periodic work is intentionally inexact and can be delayed by Doze and
battery optimization. Android’s documentation
(https://developer.android.com/reference/androidx/work/PeriodicWorkRequest) confirms
both the minimum interval and inexact execution. The worker replaces only “today,” so
a delayed first run after midnight does not finalize yesterday.

## 7. JSON import/export

Strengths:

- Explicit format name and version.
- UTF-8 JSON through Android’s document picker.
- Full database transaction for import.
- Unknown tables and columns are rejected.
- Matching primary keys are deliberately replaced.
- Imports are merged, not destructive.
- Android rejects imports over 10 MB in android/app/src/main/kotlin/com/
  stepandemianenko/focustrace/DataTransferDocumentBridge.kt:84.

- After import, language, restrictions, dashboard, and reports are refreshed.

Risks:

- The backup is plaintext and may contain Windows window titles, app usage,
  exclusions, and restrictions.

- Export and import create multiple complete in-memory representations: rows, JSON
  text, channel payload, and byte arrays.

- Export has no corresponding size limit.
- Schema version is informational rather than enforced.
- Semantic row validation is delegated to SQLite constraints, which are minimal.
- The SAF pending result is in memory and is not process-death resilient.
- Backup is only exposed on Android even though the data layer is portable.

## 8. Android application blocking

The enforcement flow is sensible:

- Restrictions are stored in SQLite.
- Dart sends a versioned configuration to Android.
- Android keeps an enforcement copy in private SharedPreferences.
- The foreground service starts only when rules and permissions exist.
- Every tick determines usage, foreground app, active rule/routine, and then shows an
  overlay.

- TikTok receives a real foreground BlockActivity to stop autoplay.
- Boot receiver restarts scheduling and enforcement.
- Block attempts are recorded in SQLite when possible.

The primary issue is the one-second loop in android/app/src/main/kotlin/com/
stepandemianenko/focustrace/BlockerService.kt:90:

- It queries and aggregates all events since midnight for restricted apps.
- It separately queries all events since midnight to find the foreground package.
- Both operations run synchronously from a main-looper Handler.
- The cost grows throughout the day and is paid once per second.

Blocking is also intentionally advisory, not tamper-resistant: revoking Usage Access
or overlay permission, force-stopping the app, or OEM service restrictions disable
enforcement. That is appropriate for a self-control tool, but should be stated
explicitly.

## 9. Reliability and performance risks

Highest priority:

- Full-day UsageStats scans twice per blocker tick.
- Filtered aggregation can overcount when background events are absent.
- Midnight-spanning foreground sessions are not reconstructed.
- Inexact snapshot work can leave incomplete historical days.
- Quadratic first-use inference.
- Re-fetching and re-inserting a year of intervals whenever a yearly report loads.
- No database retention or compaction strategy.
- Windows session-row amplification at short polling intervals.
- Full-memory JSON export/import.
- SQLite contention between native Android and Flutter writers.
- Best-effort catches conceal missing history and restriction events.
- Local-day arithmetic using fixed 24-hour durations deserves DST tests.
- A cold installed-app request encodes icons for every launchable app; caching
  mitigates later calls, but there is no measured evidence for its cost.

The source contains comments quoting approximate cold icon timings. Those should not
be used as portfolio claims because there is no benchmark, device specification,
distribution, or reproducible methodology behind them.

## 10. Privacy and security properties

Properties that can be supported from code:

- The merged Android release manifest has no INTERNET permission. It has
  ACCESS_NETWORK_STATE from WorkManager, which does not itself permit sockets.
  Android documents INTERNET as the permission needed to open network sockets.
  (Android connectivity documentation
  (https://developer.android.com/develop/connectivity/network-ops/managing))

- The main code and dependency list contain no account, analytics, advertising,
  crash-reporting, or cloud SDK.

- Debug and profile builds do include INTERNET for Flutter tooling; the claim is
  release-specific.

- SQLite and Android preferences use application-private storage.
- The blocker service and BlockActivity are not exported.
- Widget and boot receivers are exported for their platform roles.
- Backup documents are created only after explicit user interaction with the system
  picker.

- Signing keys and key.properties are ignored by Git.
- Release minification and resource shrinking are enabled.

  Properties that cannot currently be claimed:

    - “All data stays on this device.” The application has no explicit allowBackup or
      extraction rules in android/app/src/main/AndroidManifest.xml:19. Android Auto
      Backup defaults to enabled and includes databases and shared preferences,
      potentially uploading them to the user’s Google Drive; device-to-device transfer
      can also remain active. (Android Auto Backup documentation
      (https://developer.android.com/identity/data/autobackup))

    - “Uninstall permanently deletes all stored data.” Local files are removed, but
      backed-up data can survive and later be restored.

    - Encryption at rest. The SQLite database, preferences, and exported JSON are
      plaintext at the application layer.

    - Network absence on Windows. The code contains no network implementation, but
      Windows has no equivalent manifest permission boundary.

    - Complete deletion of every cached artifact. The database and settings are cleared,
      but cached app icons are separate cache files.

    - Supply-chain security. CI does not scan dependencies or pin GitHub Actions to
      immutable commit SHAs.

    ## Proposed engineering measurements

    ### 1. Blocker aggregation cost and correctness

    - What: Decision latency, allocations, scan scaling, and false block/allow rate.
      - Why: This is the most frequent and user-critical background operation.
      - Scenario: Aggregate a 24-hour synthetic event trace containing missing background
        events, duplicate lifecycle events, relaunches, and unrestricted app switches.

      - Dataset: 50,000 events, 100 packages, 20 restricted packages.
      - Methodology: Compare output with a simple state-machine oracle; JMH with 3 forks,
        five 1-second warmups, and ten 1-second measurements.

      - Tooling: JMH, Gradle, JVM allocation profiler.
      - Files: UsageStats.kt, new Android benchmark source set and deterministic fixture
        generator.

      - CI: Yes; archive results on every main-branch build, initially without an absolute
        timing gate.

      - Misleading risk: Pure aggregation excludes UsageStatsManager, PackageManager, and
        main-thread costs.

    ### 2. End-to-end blocker enforcement latency

    - What: Launch-to-block latency, missed-block rate, and false-positive rate.
      - Why: This is the actual user promise.
      - Scenario: Launch a helper app under block-now, daily-limit, schedule, and routine
        rules, plus matching allowed controls.

      - Dataset: 80 transitions per API level: 10 blocked and 10 allowed for each of four
        rule types; API 29 and 35.

      - Methodology: Timestamp launch with elapsedRealtime, observe overlay/activity
        through UIAutomator, report p50/p95/max and outcome counts.

      - Tooling: Android instrumentation, UIAutomator, emulator, adb appops.
      - Files: New helper/test app module, instrumentation tests, nightly workflow.
      - CI: Yes, nightly; keep PR CI to a small smoke subset.
      - Misleading risk: Emulators do not model OEM process killers, Doze, or real-device
        UsageStats timing.
  ### 3. Historical snapshot accuracy

    - What: Per-app/day error against ground truth after delayed or missed workers.
    - Why: Reports depend on these snapshots being complete.
    - Scenario: Simulate on-time 15-minute work, a 00:20 delayed run, six-hour Doze
      delay, one missed day, and permission revocation.

    - Dataset: 30 days, 100 apps, 10,000 events per day.
    - Methodology: Compare persisted daily totals with an oracle; report missing seconds,
      percentage error, incomplete-day count, and retry outcomes.

    - Tooling: Injected clock/event source, JVM/Robolectric SQLite tests.
    - Files: UsageSnapshotWorker.kt, store test seam, new reliability tests.
    - CI: Yes.
    - Misleading risk: Synthetic schedules cannot prove actual OEM scheduling behavior.

  ### 4. Dashboard responsiveness and frame quality

    - What: Cold first-meaningful-render, warm refresh latency, and janky frames.
    - Why: This is the primary interactive experience.
    - Scenario: Open and refresh a dashboard containing icons, 60-day trends, and the
      maximum ten rendered bubbles.

    - Dataset: 100 app summaries, 6,000 history rows, 100 fixed 128×128 icons; 30 cold
      and 50 warm runs.

    - Methodology: Profile-mode timeline; report p50/p95, frame build/raster time, and
      frames over 16.7 ms.

    - Tooling: Flutter integration_test, VM timeline, Android emulator.
    - Files: Benchmark test entry point, fixture provider overrides, integration
      workflow.

    - CI: Nightly or dedicated performance workflow.
    - Misleading risk: Provider overrides bypass real UsageStats and method-channel
      latency.
### 5. SQLite scale and storage growth

- What: Read/write latency, query plans, contention behavior, and database size.
- Why: Storage is the backbone of dashboard history, reports, Windows tracking, and
  backup.

- Scenario: Replace today, read one day, read 60-day history, aggregate all time,
  query yearly intervals, and run a concurrent native-style writer.

- Dataset: 36,500 daily rows, 250,000 intervals, 100,000 sessions, 10,000 events, and
  25 settings.

- Methodology: Five warmups and 30 measured operations; capture p50/p95/max, database
  bytes, and EXPLAIN QUERY PLAN.

- Tooling: sqflite_common_ffi, Dart benchmark harness, SQLite CLI.
- Files: New deterministic DB seeder and tool/benchmarks/sqlite_benchmark.dart.
- CI: Yes for FFI; periodic Android-device confirmation.
- Misleading risk: Desktop SQLite does not reproduce Android flash storage or cross-
  process locking exactly.

### 6. Report generation correctness and scaling

- What: Generation latency and equality with a one-pass reference implementation.
- Why: Reports are valuable only if both timely and mathematically trustworthy.
- Scenario: Generate weekly, monthly, and yearly reports at increasing interval
  counts.

- Dataset: 365 days × 100 apps, 10,000 restriction events, and interval sets of
  1,000, 10,000, and 50,000.

- Methodology: Validate totals, hourly buckets, first-use samples, and top apps;
  measure 20 iterations at each scale.

- Tooling: Dart benchmark harness and CPU profiler.
- Files: report_generation_service_test.dart, benchmark fixture/oracle, benchmark
  runner.

- CI: 10,000-interval case on PRs; full scale scheduled.
- Misleading risk: Generated interval distribution can conceal patterns found in real
  devices.

### 7. JSON portability and resource use

- What: Round-trip integrity, transactional rollback, elapsed time, serialized size,
  and peak RSS.

- Why: Backup is the only supported recovery path when signing/install problems
  occur.

- Scenario: Export, import into an empty database, merge into a populated database,
  and inject an invalid row halfway through.

- Dataset: 5,000 sessions, 3,650 daily rows, 10,000 intervals, 1,000 events, and 25
  settings—19,675 rows total—plus a separate fixed 9 MiB input.

- Methodology: Canonical table comparison, row-count/hash comparison, rollback
  assertion, ten timed runs.

- Tooling: Flutter tests, ProcessInfo.currentRss, Android SAF instrumentation for the
  size boundary.

- Files: data_transfer_test.dart, fixture generator, document-bridge instrumentation
  test.

- CI: Yes; SAF test in emulator job.
- Misleading risk: RSS and document-provider performance vary by OS and CI runner.

### 8. Windows tracking accuracy and write amplification

- What: Attributed-time error, dropped/extra seconds, row count, and database growth.
- Why: Windows is a documented supported platform and currently has no CI coverage.
- Scenario: Replay an eight-hour workday with switching, idle periods, excluded apps,
  and suspend gaps.

- Dataset: 5,760 five-second samples, 100 switches, three ten-minute idle periods,
  two thirty-minute suspend gaps, and 20 excluded-app samples.

- Methodology: Compare stored sessions with an oracle and measure rows/bytes/runtime.
- Tooling: Existing fake clock/channel pattern, Windows GitHub runner, small C++ unit
  seam.

- Files: Tracking tests, Windows channel tests, Windows CI job.
- CI: Yes.
- Misleading risk: A fake channel does not reproduce protected processes, UAC, or
  Win32 API failures.

### 9. Failure-recovery matrix

- What: Recovery success, data loss, retry count, and time to healthy state.
- Why: Graceful degradation is stronger evidence than happy-path coverage.
- Scenario: Permission revocation, overlay revocation, locked DB, absent DB, v1–v4
  migration, malformed settings, MethodChannel failure, and process death during
  transfer.

- Dataset: Eight fault classes, 20 repetitions each—160 trials.
- Methodology: Inject each fault at deterministic boundaries and assert the next
  valid operation recovers without corrupting prior data.

- Tooling: Fault-injecting repositories, fake_async, Robolectric, Android
  instrumentation.

- Files: Data-source, worker, report, tracking, restriction, and transfer tests.
- CI: Pure/Robolectric cases on PRs; process-death cases nightly.
- Misleading risk: Failure injection only tests the chosen interruption points.

### 10. Release privacy and security contract

- What: Final permissions, exported components, backup policy, signing identity,
  dependency inventory, and absence of known vulnerable packages.

- Why: These are directly auditable production-readiness claims.
- Scenario: Build one clean release AAB and inspect the final merged artifact.
- Dataset: One AAB plus the complete Dart/Gradle dependency graph per commit.
- Methodology: Compare permissions/components with an allowlist; assert no INTERNET,
  explicit backup policy, debuggable=false, and non-debug release-candidate
  certificate.

- Tooling: bundletool, apkanalyzer/aapt, Gradle signing report, CycloneDX SBOM, OSV
  scanner.

- Files: Manifest backup rules, release Gradle configuration, verification script, CI
  workflow.

- CI: Yes.
- Misleading risk: Static artifact inspection does not prove Windows behavior or
  absence of logic vulnerabilities.

### 11. Test effectiveness and layer coverage

- What: Line coverage by layer and critical-path mutation detection.
- Why: A single repository-wide percentage hides completely untested adapters.
- Scenario: Run all current and added tests, excluding generated localization code.
- Dataset: All production Dart/Kotlin executable lines and the current 85-test
  baseline.

- Methodology: Publish per-layer LCOV/JaCoCo; introduce controlled mutants in
  UsageStats, restrictions, report totals, and import rollback and count detected
  mutants.

- Tooling: LCOV, JaCoCo/Kover, targeted mutation script or PIT for Kotlin.
- Files: Coverage script, CI, critical service tests.
- CI: Yes.
- Misleading risk: Coverage and mutation scores can be optimized without testing real
  platform integration.

### 12. Architecture-boundary evidence

- What: Dependency-direction violations and import cycles.
- Why: It turns the current “clean-looking folders” into an enforceable architectural
  property.

- Scenario: Analyze every non-generated Dart source import on each PR.
- Dataset: Entire lib/src source tree.
- Methodology: Assert domain imports neither Flutter nor data/presentation;
  application imports no presentation/data implementation; data imports no
  presentation; detect cycles.

- Tooling: Small Dart analyzer-based script.
- Files: tool/check_architecture.dart, architecture contract test, CI.
- CI: Yes.
- Misleading risk: Passing directory rules does not prove that class responsibilities
  are well designed.

## Proposed small-commit implementation plan

1. style: restore the existing CI formatting gate
2. test: add deterministic shared evidence fixtures and reference oracles
3. perf(android): add UsageStats and blocker aggregation benchmarks
4. fix(android): correct filtered app-switch and midnight-boundary aggregation
5. reliability(android): test delayed snapshots, retries, and database contention
6. perf(data): add SQLite scale, query-plan, and storage-growth benchmarks
7. perf(reports): add report scaling benchmark and one-pass first-use implementation
8. test(backup): add large round-trip, semantic validation, and SAF boundary evidence
9. test(windows): add attribution benchmark and Windows CI build
10. test(android): add emulator blocker/permission/boot integration suite
11. security(android): make backup policy and release signing explicit; add artifact
    assertions

12. ci: publish coverage, benchmark, lint, SBOM, and architecture evidence with
    evidence-based thresholds
