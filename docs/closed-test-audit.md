# Closed-test feedback audit

Audit date: 2026-09-07; historical recovery implementation update: 2026-09-09. Baseline: `497272da9bd1d4bdf0998120e8f4b1da06c54693`,
FocusTrace `1.0.6+7`. Findings below distinguish baseline code, local fixes, and
device checks. Local fixes have not been released. The reviewed `.dev` APK was installed on the
SM-A366B on 2026-09-09. Device Session 1 ran September 9–14; the detailed
checkpoint below records passed accounting checks and unresolved recovery evidence.

**Historical recovery: implemented and regression-tested; device preservation/backoff
checks pass. The bounded timestamp correction repaired September 13 on-device;
repeated reads preserved its reconciled metadata and intervals. Current-day
persistence is now DEVICE VERIFIED after the second correction: repeated saves
succeed, including the adjacent tiny Clock session, and stale writes are rejected.
September 11 remains unresolved: the eligible retry reached a different, isolated
93ms Health Connect interval rejection. Existing data survives; further investigation
is deferred as a non-blocking P1 limitation under the September 15 decision below.
Final bounded gate completed September 15: READY WITH DOCUMENTED NON-BLOCKING
LIMITATIONS.** Core enforcement and the corrected normal reboot flow passed on
SM-A366B/API 36. Basic timing, screen-off and resume-refresh checks previously passed.
The final decision below supersedes earlier open-gate checkpoints and exhaustive
test proposals. Optional multi-window verification was skipped at the user's request
to finish; it is not a passed test.
Passing unit tests is not a production sign-off. P1–P3 requests do not block release.

## Scope and evidence

The supplied feedback summary reports 12 testers (5 English and 7 Ukrainian/Russian
responses), ease of use 4.42/5, readiness 4.33/5, 11/12 readiness ratings of 4 or 5,
and 9/12 likely continuing users. These are supplied aggregates, not independently
recalculated survey results. The ignored spreadsheets and individual responses are
not included in this report or GitHub follow-ups.

Reviewed Dart screens, view models, repositories, SQLite schema, native event
aggregation, snapshots, service/rules, locale resources, and existing tests/issues.
Baseline Flutter suite: 93 passing tests. Baseline Android suite: 32 passing tests.
The new regression cases are synthetic event/widget tests, not reproductions of a
particular tester's device incident.

Read-only device inspection found Samsung SM-M135F, Android 14 (API 34), with
`1.0.6-dev` / versionCode 7 installed for user 0 and Usage Access / overlay app-ops
allowed. The production package is installed in user 10 and stopped; it is not
installed for user 0. This does not establish which build testers used. No phone
restart, profile switch, reinstall, permission change, or force-stop was performed.

## Initial priority table (historical; superseded by the final gate)

“Partially fixed” means a specific path is implemented/tested while the umbrella
item still needs verification. “Cannot reproduce — not run” is not evidence of
absence; no original device trace was available.

| Item | Priority | Status | Current implementation and remaining action |
| --- | --- | --- | --- |
| 1. Missing/stale usage | P0 | Partially fixed | Android queries OS events independently of the Flutter process; periodic snapshots exist. Added dashboard resume refresh and pinned native snapshot date to query date. Shared native recovery now repairs recent incomplete/missing days with coverage evidence and atomic writes. Regression-tested; device backoff/preservation verified, but millisecond-shifted interval endpoints reproducibly reject historical and current-day writes (see diagnostic confirmation below). |
| 2. Incorrect time | P0 | Partially fixed | Existing duplicate/app-switch regressions pass. Added controlled-duration, refresh, midnight, shutdown and restart cases. Cannot certify the testers' historical fix without their traces / device comparison. |
| 3. Background counted | P0 | Partially fixed | App switches already close outgoing sessions. Local fix closes on screen non-interactive, keyguard shown, shutdown; startup discards an unclosed session with unknown end. SM-A366B/API 36 screen-off/lock exclusion passed; shade remains counted under the observed foreground metric. PiP, multi-window and other OEM behavior remain pending. |
| 4. Limit bypass | P0 | Partially fixed | Native service rebuilds daily allowance from OS events. Fixed missing midnight continuation in the shared event path; synthetic restart and threshold checks pass. Overlay delivery, OS process death, split screen and PiP remain unverified. |
| 5. Split-screen totals | P0 | UX issue / product definition | Current algorithm is exclusive last-resumed attribution, not summed simultaneous visibility. Synthetic overlapping-resume trace cannot double total wall time. It may undercount another visible app and miss its enforcement. Device comparison and explicit promise still required. |
| 6. Blocked Routines | P1 | UX issue | Groups share a daily allowance; name/apps/included-app toggles/enabled state exist. Old immediate-block routines migrate to disabled groups without a limit. Empty-state wording still suggests immediate group blocking. |
| 7. Scheduled routines | P1 | Feature request | Individual app schedules activate by local start/end time every day. Groups have no schedule or weekday fields. Keep shared-limit behavior; schedule redesign is separate. |
| Locale (section 7) | P1 | Fixed in source; device checks pending | Explicit Flutter locale resolver chooses a supported device language, then English. Existing regression guards the former alphabetical German fallback. Russian is unsupported and falls back to English unless a later device preference is supported. |
| 8. Historical navigation | P1 | Partially fixed / feature request | Dashboard previous/next day, per-app 7/14/30-day and year charts, and weekly/monthly/yearly reports exist. No date picker or previous-report-period navigation. Recent history reconciliation is now implemented; expired/ambiguous gaps remain unrecoverable. |
| 9. Reels/Shorts only | P1 | Feature request | No AccessibilityService or sub-feature detection. Feasible hypothesis but fragile; needs a separate prototype and policy review. No implementation in this audit. |
| 10. Limit selector | P2 | UX issue | Per-app slider is 5–480 minutes in 5-minute steps: 2-minute test limit cannot be entered there. Routine picker already has hour/minute dropdowns up to 24h, still 5-minute steps. Review precision, large values and TalkBack. |
| 11. Onboarding | P2 | Working as intended (existing flow) / UX issue | Skippable three-page welcome, permissions and app selection already exist. Routine semantics and discovering detail charts could use contextual help; do not duplicate onboarding. Related existing issue #33. |
| 12. Detailed navigation | P2 | Partially fixed / UX issue | Summary rows and restriction app rows open details; widget coverage verifies navigation. Bubble taps only show a tooltip, and long-press manages restrictions. Add a clear details action for bubbles. |
| 13. Precision | P2 | UX issue | Compact sub-minute values use `<1m`; details have second-based formatting. Summary/tooltip percentages use zero decimals: 0.4% becomes 0%, 0.7% becomes 1%. |
| 14. Suggestions | P2 | Feature request | Five-minute warnings exist for configured individual/shared limits. No heavy-usage suggestion for apps without limits. Related #30 and #33 cover adjacent, distinct behavior. |
| 15. Swipe tabs | P3 | Feature request | Main tabs use IndexedStack and buttons. Charts already consume horizontal gestures. Defer pending gesture design. |
| 16. Themes | P3 | Feature request | App and bubble screen explicitly force dark colors; system/light/custom choices absent. Optional future work. |
| 17. Battery per app | P3 | Platform limitation / feature request | No battery collection. Privileged per-app battery statistics cannot be assumed available to a normal Play-distributed app. Defer. |
| Passive audio / Spotify | Definition | Working as intended for foreground accounting; UX issue | Foreground audio service events do not add usage. Adopt foreground screen-use wording as a proposed default; do not promise all background application activity. Device comparison remains pending. |

## P0 data flow and remaining risks

### Collection and refresh

- [UsageStats.kt](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageStats.kt)
  queries `UsageStatsManager.queryEvents`; it does not use aggregate
  `queryUsageStats`/`totalTimeInForeground` as a second source of truth.
  Totals, intervals, and enforcement use foreground event reconstruction.
- [MainActivity.kt](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/MainActivity.kt)
  serves usage queries on a background thread, schedules periodic work at engine
  configuration, and syncs restrictions into Android preferences.
- [UsageSnapshotScheduler.kt](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageSnapshotScheduler.kt)
  uses unique WorkManager work every 15 minutes, with KEEP policy. Scheduling is
  inexact; it is not a guarantee of a complete snapshot at 23:59:59.
- [UsageSnapshotWorker.kt](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageSnapshotWorker.kt)
  delegates to [UsageHistoryRecovery.kt](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageHistoryRecovery.kt),
  the shared native recovery/snapshot component. It captures the timestamp and
  timezone, considers the previous three local calendar days plus today, uses persisted retry/recheck timestamps for
  historical candidates, and clips each day independently. The three-day horizon is
  an attempt bound, not a guarantee of Android retention.
- [UsageSnapshotStore.kt](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/UsageSnapshotStore.kt)
  owns the existing native transaction, extended to write daily totals, intervals
  and coverage metadata atomically. Missing DB/tables or a non-v5 DB are left
  untouched until Flutter initializes/migrates them. SQLite failures retry through
  WorkManager; live dashboard reads retain a storage-error fallback to OS usage.
- [UsageRepositoryImpl](../lib/src/data/repositories/usage_repository_impl.dart)
  awaits recovery before daily history, range history and all-time reads. Android
  live queries also use the native snapshot writer; Flutter no longer saves that
  response under a separately captured current date. Other platform paths remain.
- [ReportRepositoryImpl](../lib/src/data/repositories/report_repository_impl.dart)
  refreshes today first where needed, then awaits the same recovery entry point
  before reading all report inputs in one SQLite transaction.
  Android no longer independently imports another interval query after recovery.
  Totals and intervals use the same raw event stream and included packages
  (launchable apps, plus packages already present in stored evidence). This also
  retains recoverability for previously stored apps that were uninstalled.
- Dashboard loads once and supports manual refresh; before this audit it had no
  lifecycle resume hook. Windows tracking samples trigger refreshes, but Android
  does not use that polling mechanism. The local fix requests a view-model refresh
  when the app resumes.

**Historical recovery implementation (2026-09-09):** SQLite schema v5 adds
`usage_snapshot_days`, keyed by local date, recording start/end milliseconds,
timezone ID, captured last-attempt timestamp, covered-through timestamp and status:
`partial`, `unavailable`, or `reconciled`. No metadata means unknown, including
legacy and imported days. Migration only adds this table; it does not erase
existing totals/intervals or label legacy rows complete. A current snapshot stays
partial; after midnight that status makes it a reconciliation candidate.

One OS event query covers the candidate span, with up to 24 hours of lookback
before the earliest candidate and an end at the captured current timestamp.
Each day's aggregation is clipped to its own `[start, end)` window. Calendar
arithmetic handles 23/25-hour DST days; query and persistence use the same captured
boundaries and timezone. Existing metadata with conflicting day boundaries is
preserved rather than silently reassigned after a timezone change.

**Availability and zero safety:** Android supplies no explicit completeness flag.
Historical finalization requires a known foreground state at/before the day start
(a resume or global stop, not an orphan pause/startup), a known closed state through the day end or a retained event at/after that end,
and no unmatched active session discarded at startup within the day.
This is a conservative retention-evidence policy that assumes a contiguous retained
event stream; it cannot prove that an OEM recorded every transition. An empty or
unanchored response does not replace history. A genuinely empty day can be marked
reconciled when boundary evidence exists and no stored usage contradicts it.
Current-day nonempty observations may be saved as partial even without a start
anchor; that does not qualify them for historical finalization.

Inside the SQLite write transaction, replacement must preserve every stored
per-app duration and cover every stored interval portion in that day. Otherwise,
existing rows survive and the day remains unresolved. This intentionally favors
retaining evidence over correcting an old overcount. Legacy cross-midnight
intervals are split, retaining neighboring-day fragments. Throwing inserts ensure
any totals, interval or metadata failure rolls the whole day back. Repeated
recovery does not append or inflate usage. Immediate repeated reads skip
reconciled days; within the three-day horizon, a guarded recheck is allowed after
six hours so delayed events can still be recovered.

**Concurrency:** all native usage snapshot callers currently run in the default
application process. A shared lock serializes native queries and writes. SQLite
rechecks captured query timestamps, day boundaries, finalization state and a
persistent generation token inside the write transaction. Older results cannot
overwrite newer snapshots. Reconciled snapshots may only be rechecked after six
hours, while still in the bounded historical horizon, with the same safety rules. Flutter no longer writes Android live
snapshots or independently imported Android report intervals; defensive local
write guards also protect native-managed days. Clear/import rotate the token and
invalidate coverage in the same transaction, rejecting in-flight native results.
Coverage metadata and the internal token are excluded from portable backups;
imported usage remains intact but is not treated as proof of this device's coverage.

**Exact delayed-worker example, verified by regression:**

1. At Day 1 23:45, Instagram has 2,400 seconds (40m), with `partial` metadata and
   covered-through time 23:45. Legacy data without metadata is also a candidate.
2. At Day 2 00:20, the component captures that time/timezone. Day 1 is now a
   historical candidate. Raw events include preceding-state and closed-end
   evidence; Day 1 aggregation uses midnight Day 1 through midnight Day 2. The test has no
   post-midnight phone event: the retained pause at 23:59 closes the last session,
   and the successful query extends through captured 00:20.
3. The retained 40-minute session plus 23:50–23:59 produce 2,940 seconds (49m).
   The native transaction replaces Day 1 totals/intervals together, then records
   `reconciled` with covered-through time midnight Day 2. Today is processed
   separately and never receives yesterday's totals.
4. If retained coverage is absent, a query fails, or the replacement contradicts
   stored data, the 40m survives. Empty results cannot erase it or finalize it.
5. Day 1 becomes reconciled only after the evidence checks and successful commit.
   This is an accepted reconstruction, not immediate permanent finalization: a
   guarded six-hour recheck remains possible within the recovery horizon.
   An unresolved day outside the three-day attempt horizon stays unresolved;
   unlimited reconstruction of expired history is not claimed.

### Local accounting fixes

The original mapper only recognized foreground/background and discarded system
events without package names. The local fix retains global screen/lock/shutdown
events and ends the current foreground interval in totals, intervals and the
incremental blocker. A startup event discards an unmatched pre-restart open
session, since its true end is unknowable. An unavailable pre-unlock event query
raises a handled permission-style error instead of dereferencing null.

Previously each daily query began at midnight with no initial foreground state.
An app resumed before midnight could receive zero usage after midnight until a new
resume event, including in the blocker. The fix seeds the query from up to 24 hours
of preceding events, clips the carried session to the requested start, and does
not count the continuation as a fresh launch. Warm blocker ticks still query from
their cursor. This bounded reconstruction cannot recover a resume older than the
lookback/retention window or reconstruct events never recorded by Android.

The original audit pinned the native snapshot date to its query. Historical
recovery preserves and extends that fix with immutable per-day windows and a
captured timezone. A regression changes the default timezone during the query
and verifies the saved date/coverage remain unchanged. Android's separate Flutter
query/save date boundary has been removed by using the native writer. This does
not establish full real-device clock/timezone behavior.

Recovery adds schema v5 and data-layer coordination. UI presentation/business
boundaries remain unchanged: the dashboard forwards lifecycle events to its
existing view model; event reconstruction and recovery remain native.

### Enforcement and measurement

[BlockerService](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/BlockerService.kt)
uses a one-second Handler loop, persisted rules, incremental usage state and
START_STICKY. It removes overlays when permissions are absent, and uses a blocking
activity for TikTok to stop autoplay. Other packages get a WindowManager overlay;
an addView failure is swallowed, so real presentation must be checked.
[BootReceiver](../android/app/src/main/kotlin/com/stepandemianenko/focustrace/BootReceiver.kt)
restarts scheduling and eligible enforcement after BOOT_COMPLETED. There is no
explicit package-replaced/timezone-change receiver. Usage is reconstructed after
service restart rather than saved as a separate remaining-allowance counter.

Normal process death and intentional force-stop are different. Force-stop,
permission revocation, and platform/OEM restrictions can prevent execution; do not
promise tamper resistance. The normal foreground/background/relaunch paths still
need device verification before treating a reported bypass as explained by Android.
Android documents that an intentionally stopped package remains stopped until
user interaction removes that state; Android 15 adds cancellation of pending
intents. [Stopped-state behavior](https://developer.android.com/about/versions/15/behavior-changes-all#stopped-state).

Both batch and incremental algorithms choose one last-resumed package. Android
multi-resume allows multiple resumed activities, so “one app is foreground” is a
FocusTrace attribution policy, not an Android guarantee. Switching touch focus
may not generate another resume. A restricted app visible alongside another app
may stop accumulating time and may not be the package selected for blocking.
This unresolved enforcement risk remains P0 even if exclusive total usage is the
desired product definition. No actual multi-window bypass is claimed reproduced.
The model also retains package names rather than activity instance identity;
overlapping activities within one package need device traces before declaring
all pause/resume orderings correct.

Proposed wording: “Foreground app time. Background audio is excluded.” Explain
the chosen multitasking policy only after device comparison. Do not claim exact
wall-clock screen time or actual attention/touch activity: the current algorithm
does not measure either. Leaving an app visible without touching it counts.

## Reproduction records

Records describe baseline failure paths and local regression results, including
the 2026-09-09 recovery implementation. They do not establish the cause of a
particular tester incident.

| Field | Screen/lock/shutdown overcount | Midnight continuation / limit gap | Stale dashboard on return | Incomplete history |
| --- | --- | --- | --- | --- |
| Device | Synthetic JVM fixture | Synthetic JVM fixture | Flutter widget fixture | Synthetic events + Robolectric SQLite fixture; no device run |
| Android | Event types from SDK; no OS runtime | No OS runtime | Android platform provider override | Robolectric API 28; not physical Android |
| FocusTrace | 1.0.6+7 baseline source | Same | Same | Same |
| Steps | Resume app at 0; system stop at 60s without pause; query at 3600s | Resume at 23:59; remain open after midnight without another resume | Load 75m; background app; source changes to 150m; resume | Snapshot 23:45; use app afterward; worker delayed until 00:20 |
| Expected | 60s; no current package | Post-midnight time counts toward new allowance | Display 150m after return | Complete previous day |
| Baseline actual / source consequence | System stop mapped to Other; session extends to query end (3600s) | No initial resume in day query, so session absent | No resume refresh; stale provider state | Previous day is never repaired |
| Frequency | Deterministic for fixture; OEM frequency unknown | Deterministic for fixture; real frequency unknown | Reproducible widget transition | Source-confirmed; device frequency unknown |
| Logs | `build/closed-test-android-validation.log` | Same | `build/closed-test-flutter-final.log` | `build/history-recovery-android.log`; no overnight device logs |
| Likely cause | Missing global lifecycle handling | Empty foreground state at daily query boundary | Missing lifecycle observer | Current-day-only worker plus DB-only historical reads |
| Result | Local fix; synthetic regression passes | Local fix; synthetic regression passes | Local fix; widget regression | Local recovery fix; 40m → 49m and SQLite safety regressions pass; device verification pending |

## Verification results and limits

- Latest Android unit run: **71 discovered, 70 passed, 1 skipped, zero failures or
  errors**. The skipped test is the pre-existing opt-in aggregation benchmark
  (`FOCUSTRACE_BENCHMARK=1`), not a disabled regression. All 27 recovery tests
  passed, as did the 12 original closed-test regressions. Debug lint passes.
  Evidence: `build/app/test-results/testDebugUnitTest/`,
  `build/app/reports/lint-results-debug.html`, `build/p0-review-android.log`.
- [UsageHistoryRecoveryTest](../android/app/src/test/kotlin/com/stepandemianenko/focustrace/UsageHistoryRecoveryTest.kt)
  uses synthetic OS events and Robolectric API 28 SQLite. It covers delayed final
  snapshot (40m → 49m), missed/legacy partial days, empty/truncated/denied events,
  evidenced zero use (including a fully idle day), contradictory apparent zero, missing boundary evidence,
  orphan pause, midnight/timezone capture, forced SQL rollback, repeated recovery,
  stale writes, clock rollback, clear/import during a query, uninstalled stored
  apps, legacy crossing intervals, interval preservation, absent/pre-v5/newer DBs
  and DST. Review tests add persisted retry/recheck timing, delayed-event recovery,
  failed rechecks preserving data, simultaneous readers and distinct-package filtering.
- [ClosedTestUsageRegressionTest](../android/app/src/test/kotlin/com/stepandemianenko/focustrace/ClosedTestUsageRegressionTest.kt)
  remains unchanged. Its global lifecycle, midnight, restart and allowance
  regressions still pass.
- Latest Flutter suite: **109 passed, zero failures**. The review adds five
  migration/report tests and one historical-resume widget case to the prior 103. New [usage_history_recovery_test.dart](../test/usage_history_recovery_test.dart)
  verifies recovery-before-read for daily/range/all-time/report paths, cached
  fallback, no second Android live save, v4→v5 data preservation and schema parity,
  migration rollback, legacy downgrade/re-upgrade, refusal of newer schemas,
  report snapshot reads, guarded Dart writes and backup/clear metadata handling. Real SQLite is used for Flutter
  migration/storage tests; the method channel is mocked for orchestration tests.
- `flutter analyze --no-pub`: **no issues found**. Logs:
  `build/p0-review-flutter.log`, `build/p0-review-analyze.log`.
- The original connected-device metadata/app-ops inspection remains the only
  scenario evidence. The reviewed debug APK has since been installed on the
  SM-A366B (Android 16/API 36); installation is preparation only. No on-device
  usage comparison, overnight worker, restart, overlay, layout or
  TalkBack sign-off is claimed. Robolectric transaction tests do not prove real
  WorkManager scheduling, on-device cross-runtime SQLite behavior, or OEM events.

Exact successful validation commands in this environment (PowerShell):

```powershell
& C:/Flutter/flutter/bin/cache/dart-sdk/bin/dart.exe --disable-analytics C:/Flutter/flutter/bin/cache/flutter_tools.snapshot test --no-pub
& C:/Flutter/flutter/bin/cache/dart-sdk/bin/dart.exe --disable-analytics C:/Flutter/flutter/bin/cache/flutter_tools.snapshot analyze --no-pub
# Working directory: android
& 'C:/Users/Stepan/.gradle/wrapper/dists/gradle-8.12-all/ejduaidbjup3bmmkhw3rie4zb/gradle-8.12/bin/gradle.bat' :app:testDebugUnitTest :app:lintDebug --console=plain
```

These are the installed-tool equivalents of the requested Flutter and Gradle
commands. Sandbox cache access required approved escalated execution. An initial
offline Android attempt lacked `androidx.test:monitor:1.7.2`; the online retry
resolved it. An intermediate analysis found one redundant test import, removed
before the final clean analysis. Generated evidence remains under ignored `build/`.

## Device checklist still required

Record model, API level, package/profile, exact APK version/commit, permissions,
battery settings, test times/timezone, expected/actual seconds, frequency, and
filtered app logs for each run. Preserve production data; use the `.dev` package
or a dedicated test device for destructive lifecycle tests.

| Area | Scenarios | Evidence still needed |
| --- | --- | --- |
| Retained history | Several apps without opening FocusTrace; hours later; entire missed day; following-day load | Per-app previous/today totals before and after refresh, raw events and persisted rows |
| Calculation regression | Manually timed 1-minute, short repeated, long and open/close sessions; repeated refresh | Compare elapsed timing, event reconstruction, raw Android aggregate and Digital Wellbeing; explain methodology differences |
| Foreground/inactive | Home, another app, lock/unlock, screen-off, notification shade, no touches while visible | Expected active intervals vs reported totals; do not classify visible inactivity as a bug by assumption |
| Multitasking | Split screen with each focus order; PiP; music while another app is visible | Google/Samsung comparison, count policy and actual usability of a limited app |
| Limits | 5-minute UI limit; continuous use, Home/return, lock/unlock, switch back, target force-stop/relaunch | Allowance survives transitions; actual block appears and prevents indefinite use |
| Recovery | Device reboot after partial usage; OS-killed FocusTrace; deliberate force-stop followed by manual reopen; app update | Distinguish platform-stopped behavior from normal restart; no unintended allowance reset |
| Boundaries | Cross midnight with same app; delayed worker; DST short/long days; timezone and clock changes | Captured date assignment, final previous day, new day reset and no duplicate intervals |
| Locale | Fresh en/uk/ru/unsupported install; upgrade with saved language; system language change | English fallback where appropriate, no unexpected German, native/Flutter agreement, text overflow |
| UX | Discover routines/details unaided; slider with TalkBack and smallest/largest limit | Understandable group allowance, discoverable detailed view, accessible precision |

None of these device scenarios is checked off based only on synthetic tests.

## Follow-up scope and existing issues

Repository remote `activityTracker` redirects to `sneri12pic/FocusTrace`. The
existing backlog was read before drafting new issues:

- [#24 Routines](https://github.com/sneri12pic/FocusTrace/issues/24) describes the
  shared pool now implemented. Scheduled groups are a distinct request.
- [#31 Detailed View Chart](https://github.com/sneri12pic/FocusTrace/issues/31),
  [#10 Detailed statistics](https://github.com/sneri12pic/FocusTrace/issues/10),
  [#23 Report Generation](https://github.com/sneri12pic/FocusTrace/issues/23) and
  [#21 Time tracked](https://github.com/sneri12pic/FocusTrace/issues/21) are closed;
  that is not proof of current device reliability.
- [#29 Detailed View Sessions](https://github.com/sneri12pic/FocusTrace/issues/29)
  remains open; Android per-session detail work should not be duplicated.
- [#30 Excess Usage](https://github.com/sneri12pic/FocusTrace/issues/30) and
  [#33 Mascot / warnings](https://github.com/sneri12pic/FocusTrace/issues/33)
  overlap future recommendations/contextual discovery, but do not implement
  suggestions for an app with no configured limit.

Nine follow-ups and their acceptance criteria are stored in
[closed-test-followups.json](closed-test-followups.json). Publication status is
listed in [closed-test-issues.md](closed-test-issues.md). Automatic approval review
blocked publication pending explicit approval of the drafts and repository;
no new issues have been created.
The issue drafts remain unpublished and were not edited during recovery. Their
history-recovery draft reflects the earlier audit state; the implementation and
verification evidence above supersede that draft's source-gap description.
Optional swipe/theme/battery work is deferred, not a release dependency.

## Platform research

1. Android retains detailed events only for a few days and can return null before
   user unlock. Long-term correctness therefore requires durable snapshots and
   honest handling of unrecoverable gaps, not unlimited OS reconstruction.
   [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager#queryEvents(long,%20long)).
2. Resume/pause are activity lifecycle events (legacy foreground/background names
   alias the newer constants). Screen/keyguard and runtime shutdown/startup need
   separate treatment; incomplete sessions across startup have unknown ends.
   [UsageEvents.Event](https://developer.android.com/reference/android/app/usage/UsageEvents.Event).
3. Android 10+ supports multiple resumed activities in multi-window. The inference
   that last-resumed always equals the app currently receiving attention is invalid.
   [Multi-window support](https://developer.android.com/develop/ui/views/layout/support-multi-window-mode).
4. Periodic work has a 15-minute minimum interval, with actual execution affected
   by system optimization. A scheduling delay is a platform constraint; failing
   to reconcile retained data afterward is an application recovery gap.
   [Work requests](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).
5. Google describes screen time as duration apps have been on screen. This supports
   excluding background audio as a default; it does not establish Samsung/Google
   split-screen attribution or a tested Spotify-specific result.
   [Digital Wellbeing help](https://support.google.com/pixelphone/answer/9137850?hl=en).
6. Reels/Shorts: accessibility window/view inspection could identify known controls,
   but view IDs, localization, custom rendering and app updates make it fragile.
   Activity identity may identify only the host app; deep links cover launches,
   not all in-app navigation. Screen recognition introduces privacy, consent and
   performance costs. This is an engineering feasibility inference, not prototype
   evidence. Research should measure false blocks (especially Messages/tutorials),
   supported host versions, update breakage and fallback behavior. Google Play
   requires declaration/review and, for non-accessibility tools, prominent
   disclosure/consent; do not claim `isAccessibilityTool` for this wellbeing feature.
   [Accessibility view inspection](https://developer.android.com/guide/topics/ui/accessibility/views/service),
   [AccessibilityService policy](https://support.google.com/googleplay/android-developer/answer/10964491).
7. `BATTERY_STATS` is signature/privileged/development protected. A normal user
   runtime permission prompt cannot grant it. Device-wide BatteryManager readings
   do not establish accurate per-application consumption. Treat this as future-only
   investigation, not a promised capability.
   [Android permissions](https://developer.android.com/reference/android/Manifest.permission#BATTERY_STATS).

## Closure decision

Historical recovery is implemented and regression-tested locally. Do not close
the umbrella or certify production yet. Verify recovery on a device (including
retention evidence and delayed work), collect the normal usage/limit/blocking
lifecycle matrix, resolve multi-window enforcement and document measurement
semantics. Usage timing, actual block presentation, normal process restart,
reboot, split screen, PiP and limit enforcement remain unverified on the patched
APK. Re-run regressions on the release candidate. P1–P3 work remains deferred.


## Final P0 engineering review — 2026-09-09

### CODE VERIFIED

Reviewed the complete uncommitted P0 source, including the original audit's
resume refresh, global stop/startup handling, midnight continuation, native date
fix, historical recovery, migrations, writer ownership and regression tests.
No P1–P3 implementation or unrelated style refactoring was performed. Existing
`.gitignore`, generated localization changes and unrelated `.claude/` files were
not modified by this review. Baseline remains
`497272da9bd1d4bdf0998120e8f4b1da06c54693`; no commit or push was made.

Concrete corrections made:

- Repeated unresolved historical reads previously repeated a multi-day OS query.
  `RETRY_INTERVAL_MS` now backs them off for 15 minutes, using persisted metadata
  inside the existing serialized native path. A pre-midnight current snapshot
  never suppresses the first reconciliation after midnight.
- Package filtering previously called the package manager repeatedly for each
  event. It now evaluates distinct package names once per candidate day.
- A `reconciled` day was previously immutable immediately. It now permits guarded
  revalidation every six hours while inside the existing three-day horizon.
  Duration/interval preservation, timestamp, bounds and generation guards still
  apply. A failed recheck preserves the accepted data/status and updates the
  attempt timestamp to prevent repeated expensive failed queries.
- Reports previously read totals and intervals in separate SQLite snapshots. The
  real SQLite source now reads all report inputs in one transaction. Reports
  containing today refresh native live data first, so the subsequent history
  call can use the persisted attempt state rather than duplicate the history query.
- Resume previously refreshed only today's dashboard. It now reloads the selected
  day through the existing ViewModel, including a recent historical day that may
  have been repaired in the background. Existing request-generation protection
  still rejects obsolete UI results; Windows polling behavior is unchanged.
- Removed the unused private `MainActivity.getTodayUsageStats` duplicate; the
  method channel already uses `measuredTodayUsageStats`. No second snapshot store
  remains after the extraction.
- The native writer now accepts **only schema v5**, not arbitrary future schemas.
  Flutter explicitly rejects opening a database newer than v5. Migration safely
  handles metadata tables left by a legacy downgrade and invalidates that evidence.
- Added debug-only `FTUsageRecovery` diagnostics for candidate dates, query
  boundaries/event counts and save/preserve outcomes/aggregate duration. Release
  builds do not emit them; no user content is logged.

### Historical recovery design decision

**Three days:** `UsageDayWindow.RECOVERY_DAYS = 3` is a named engineering policy:
cover yesterday plus two missed days while bounding cold reconstruction work.
Android promises only a limited number of retained days, not exactly three
([UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager#queryEvents(long,%20long))).
Shorter OEM retention causes coverage failure and preserved data. Longer retention
may offer additional recovery opportunities that this policy deliberately does
not attempt. No evidence justified blindly expanding the horizon or a user-facing
setting. The policy constants can be changed in code with evidence and tests.

Selection is **metadata-driven within a bounded discovery horizon**: unresolved
status, last-attempt time, reconciliation state and matching boundaries decide
whether to query. Enumerating recent calendar slots also discovers completely
missing days, which a scan of existing metadata alone would miss. Scanning every
unresolved legacy date would repeatedly revisit expired data. Old unresolved
metadata remains unresolved rather than being relabeled zero/complete.

**Reconciled versus immutable:** `reconciled` means the last accepted full-day
reconstruction passed the coverage/preservation checks and committed atomically.
It is not a claim of immutable truth immediately after midnight. Within the
horizon it can gain late usage at a six-hour recheck; ordinary reads skip it.
Once its date falls outside the three previous local dates, automatic recovery no
longer touches it. That is the effective finalization boundary for a stable
clock/timezone, not an Android guarantee of event completeness. Late events after
that point cannot be automatically recovered. Clock/timezone changes are not
used to reinterpret an existing metadata row with different UTC day boundaries.
Process restart preserves attempt state. Midnight-spanning sessions use the
existing clipped continuation with no extra launch. Late worker execution repairs
the completed day independently of today; no exact-midnight schedule is required.

**Conservative tradeoff:** legitimate corrected durations can be lower than a
previous snapshot (for example an earlier unclosed-session overcount). Stored
intervals can also already be wrong. The current no-decrease/interval-containment
rules deliberately reject those corrections; an old overcount or erroneous
interval can remain unrepairable automatically, even when new evidence is better.
This limitation is preferable to guessing which source is wrong and deleting
valid history. It is not an accuracy claim about old data. Missing/unrecorded OEM
events can evade boundary heuristics; an idle trace can be ambiguous. No finite
retry cadence or finalization delay proves that every Android event was recorded.

### Migration and concurrency review

`v4 → v5` adds the metadata table without replacing existing totals or intervals.
Legacy rows begin without trusted coverage. Fresh and upgraded schemas match.
The installed sqflite 2.5.6 runs upgrade callbacks and `user_version` changes in an
exclusive transaction; forced migration failure retains v4 data/version.

The dependency does **not** reject downgrade by default: without a callback it
lowers `user_version` and leaves tables. A legacy v4 binary therefore remains
unsupported as a rollback strategy. Current code cannot change that old binary.
This build rejects future schemas explicitly; a later v5 reopen after legacy
version lowering uses `CREATE TABLE IF NOT EXISTS` and clears stale reconciliation
metadata while retaining usage. Regression tests exercise both paths.

Clear/import rotate the internal generation token in their transaction and
invalidate coverage, rejecting in-flight native results. Coverage and the token
are not portable; usage and normal settings remain portable. Current-day Android
snapshots have one native writer; defensive Dart guards protect managed days.
Native queries are serialized off the main thread, and SQLite checks stale
results within each per-day write transaction. Reports now use a consistent read
snapshot. Cross-runtime scheduling/locking still needs observation on real Android.

### Performance review

Dashboard today must obtain fresh live events; history/detail 7/14/30-day and
report requests use the bounded recent candidates rather than querying the whole
selected period. Repeated historical reads inside the cooldown make no OS query.
Concurrent historical requests serialize and the second uses the first attempt's
persisted state (tested); process restart does not reset that state. Live-today
requests still serialize and may each query—there is no cache that would hide
fresh usage. UI work remains asynchronous, but loading/refresh can wait for native
work. Cold recovery may scan up to roughly four days including the preceding
bootstrap day. Writes are one day at a time, with package lookups outside SQLite
transactions. A very large report read can still delay a writer; cold latency,
real event volume and cross-runtime contention are NOT YET VERIFIED on-device.

### AUTOMATED TEST VERIFIED

Final review run: Flutter **109 passed**; Android **71 discovered / 70 passed /
1 existing opt-in benchmark skipped**, zero failures/errors. All 27 recovery JVM
cases pass. Flutter analysis and Android debug lint pass. `git diff --check` passes.
The first review run exposed a wrong downgrade assumption in a new test; the test
and implementation now exercise the observed legacy behavior. Existing v2/v3
migration fixtures and all earlier closed-test regressions pass unchanged in intent.

Exact successful commands (PowerShell):

```powershell
& C:/Flutter/flutter/bin/cache/dart-sdk/bin/dart.exe --disable-analytics C:/Flutter/flutter/bin/cache/flutter_tools.snapshot test --no-pub
& C:/Flutter/flutter/bin/cache/dart-sdk/bin/dart.exe --disable-analytics C:/Flutter/flutter/bin/cache/flutter_tools.snapshot analyze --no-pub
# Working directory: android
& 'C:/Users/Stepan/.gradle/wrapper/dists/gradle-8.12-all/ejduaidbjup3bmmkhw3rie4zb/gradle-8.12/bin/gradle.bat' :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain
# Repackage after the final Dart correction:
& 'C:/Users/Stepan/.gradle/wrapper/dists/gradle-8.12-all/ejduaidbjup3bmmkhw3rie4zb/gradle-8.12/bin/gradle.bat' :app:assembleDebug --console=plain
```

Logs: `build/p0-review-flutter.log`, `build/p0-review-analyze.log`,
`build/p0-review-android.log`, `build/p0-review-apk.log`.

### DEVICE VERIFIED — installation/identity only

With the user's target confirmation, installed via `adb install -r` on the
connected **Samsung SM-A366B, Android 16/API 36, user 0**. This is not the original
SM-M135F/Android 14 audit device. APK identity checked with `aapt`:

- Application ID: `com.stepandemianenko.focustrace.dev`
- Version: `1.0.6-dev`, versionCode `7`; minSdk 21, targetSdk 35; debug build
- APK: `build/app/outputs/apk/debug/app-debug.apk`
- SHA-256: `042ad9a2dcfd1041a41c630a19d576495f2eab79f26a427618c7f0626f600d96`
- `.dev` first-install timestamp remains 2026-08-19 14:06:51; update timestamp is
  2026-09-09 11:26:27. Existing `focus_trace.db` and journal remain present.
- Production package/version/update timestamp remain unchanged (`1.0.6` / 7,
  last updated 2026-08-19 13:31:45). No production package/data operation occurred.
- Separate application IDs/data directories; no uninstall, data clear or app
  launch was performed. File presence is not verification of migration/content.

Build/source hash manifest: `build/p0-review-build.json`; installation output:
`build/p0-review-install.log`. No commit, push or issue publication occurred.

### NOT YET VERIFIED — production gate remains open

At completion of the engineering review the patched app had not been launched.
Session 1 results below supersede that installation-only state. Usage accuracy,
usage accuracy, background snapshots and historical recovery (including genuine
midnight timing), real overlay/block presentation, normal process restart,
reboot/allowance recovery, split screen, PiP and limit enforcement remain open.
No device scenario is passed based on synthetic events, Robolectric, installation
success or metadata/file inspection. Execute the ordered
[device protocol](closed-test-device-protocol.md), recording the supplied per-case
expected/FocusTrace/Digital Wellbeing/raw-event/difference/pass-fail fields. Run
SM-M135F/Android 14 coverage separately; do not relabel SM-A366B results. No P1 work.


## Device Verification Session 1 — started 2026-09-09

Measurement-only session on SM-A366B / Android 16 / API 36 / user 0,
`com.stepandemianenko.focustrace.dev`, `1.0.6-dev` / 7, Europe/London.
No application code, settings or permissions were manually changed. App launch
performed its normal migration and usage writes; device DB files were only read
by the measurement tools.

### DEVICE VERIFIED — pre-launch checks

- Installed APK bytes match the reviewed APK SHA-256
  `042ad9a2dcfd1041a41c630a19d576495f2eab79f26a427618c7f0626f600d96`.
- `GET_USAGE_STATS: allow`; `SYSTEM_ALERT_WINDOW: allow`.
- Pre-launch database is v4, with 513 daily usage rows and 5,418 intervals.
  Historical rows cover 2026-08-19 through the current date, 2026-09-09.
- Two consecutive captures of the `.dev` DB and its sidecar files were byte
  identical. The rollback journal was empty; integrity check on the local copy
  returned `ok`. Device files were only read; no SQL write, process stop, clear,
  import, clock change or synthetic event injection was performed.
- Evidence is retained locally under ignored `build/device-session-1/`:
  `identity.json`, `prelaunch-summary.json`, and the private pre-launch DB copy.
  App-specific usage/content is not included in this audit.

### DEVICE VERIFIED — Phase 1 migration PASS

- Launch began at device epoch `1788951513` (2026-09-09 11:58:33 BST);
  Android reported a successful warm activity launch. The dashboard rendered
  Today / Tracked 30m and an existing populated usage list.
- Post-launch SQLite version **5**, `usage_snapshot_days` present, integrity `ok`.
  Two consecutive DB/sidecar captures were identical; rollback journal empty.
- All 513 prior daily keys survive with no duration decreases. Historical daily
  rows are byte-for-value identical. Daily row count is now 514; today's stored
  total changed from 1,826s to 1,842s through normal live collection.
- All 5,418 existing interval rows survive unchanged; six intervals were added.
  All five settings and all 219 restriction events remain unchanged.
- Usage Access and overlay app-ops remain `allow`. Startup logs show successful
  live queries and persistence, with no migration exception in captured app logs.
  No clear/import/reset was requested or observed; row comparison confirms
  preservation independently of the logs.
- Initial metadata: September 9 `partial`; September 6–8 `unavailable` after
  preservation-guard outcomes. Existing historical totals and intervals were
  preserved exactly. This verifies safe preservation on this launch, **not**
  successful historical reconciliation or full midnight recovery.
- Evidence: `build/device-session-1/launch.json`, `postlaunch-summary.json`,
  `migration-comparison.json`, `postlaunch-logcat.txt`, `postlaunch.png`, and
  private pre/post SQLite snapshots. Unrestricted app content is not published.

Timing, lifecycle and resume-refresh remain **NOT YET VERIFIED**. Historical
backoff/reconciled rechecks and successful repair remain **NOT YET VERIFIED**.
No defect has been reproduced; production logic was not changed in this session.

### DEVICE VERIFIED — Test A, first continuous-session measurement

Target: Samsung Calculator (`com.sec.android.app.popupcalculator`), no stored
current-day row/interval before the test (0s baseline). The requested duration
was 60s, but the user-driven Home transition occurred after approximately 71s.
This run is **INCONCLUSIVE for the exact 60s protocol**; the longer actual
interval is measurement evidence, not a reproduced accounting defect.

- Raw Android events: ACTIVITY_RESUMED 2026-09-09 12:07:37 BST;
  ACTIVITY_PAUSED 12:08:48; ACTIVITY_STOPPED 12:08:49. Dumpsys displays whole
  seconds, giving approximately 71s of foreground time.
- Native-persisted interval: `1788952057094` to `1788952128537`, **71.443s**.
  Daily Calculator duration **71s**, launch count **1**. Difference from the
  independently read whole-second Android event reconstruction: approximately
  **0s**, within the proposed ±3s tolerance. Native/SQLite accounting for the
  measured interval **PASS**; millisecond raw-query output is not independently
  exposed by this dumpsys capture.
- The same 71s total and single interval were already persisted while Home was
  foreground, before reopening `.dev`, and remained unchanged after return.
  A background native query/save is logged at epoch `1788952128787`; its caller
  is not identified by that log, so this is not proof of a WorkManager run.
- Explicit `.dev` activity return reported HOT / existing task brought forward.
  A fresh native query/save followed at `1788952158158`; dashboard screenshot
  shows Calculator newly present in the usage bubbles. Calculator's numeric UI
  value was subsequently confirmed as **1m** in the Calculator bubble tooltip
  (`test-a-calculator-detail.png`), consistent with the stored 71s at minute
  display precision. UI display **PASS**. No manual refresh/restart was performed.
- Two historical reads immediately afterward logged `today=false candidates=[]`;
  historical metadata timestamps remained `1788951517718`, with all three days
  still unavailable. This is device evidence of skipped recovery reads during
  backoff, not successful reconciliation or reconciled-day recheck evidence.
- Digital Wellbeing was not measured. No data reset, production logic change or
  synthetic event/clock manipulation occurred.

Evidence: `build/device-session-1/test-a-{baseline,monitor,db-comparison}.json`,
`test-a-android-events.txt`, `test-a-logcat.txt`, `test-a-after.png`, and the
private `test-a-before`, `test-a-home`, `test-a-after` database copies.

### Session 1 resumed — 2026-09-11

The September 9 three-short-session test was interrupted after the first session
(approximately 24s by Android events). It is incomplete; no combined three-session
result is claimed. Test B is restarted with a fresh September 11 baseline.

DEVICE VERIFIED preflight: same SM-A366B / Android 16 / API 36, Europe/London,
`.dev` 1.0.6-dev / 7, unchanged installed APK SHA-256
`042ad9a2dcfd1041a41c630a19d576495f2eab79f26a427618c7f0626f600d96`.
Usage Access and overlay remain allowed. Home is foreground. SQLite v5 integrity
is `ok`, with 550 daily rows and 5,916 intervals in two identical captures with an
empty rollback journal. Evidence: `build/device-session-1/resume-sep11-identity.json`
and `resume-sep11-before-summary.json` plus the private SQLite copy.

Metadata observation only: September 9 and 10 now report `reconciled`, September
11 `partial`. This is actual device metadata evidence; the intervening recovery
execution was not observed, so it does not verify the controlled delayed-midnight
scenario, exact repaired totals, or reboot/process-restart behavior. Full recovery
comparison remains for the scheduled recovery phase. No production logic changed.

### DEVICE VERIFIED — Test B restarted September 11: accounting PASS

Samsung Calculator began with no current-day stored row/interval and no current-day
raw Android events (0s baseline). The three intended ~20s sessions actually lasted
approximately 27s, 23s and 22s; chat/manual cue latency is recorded rather than
attributed to FocusTrace. This is a three-short-session test, not exactly 60s.

| Session (BST) | Raw Android resumed → paused | Raw duration | Native-persisted interval |
|---|---|---:|---:|
| 1 | 11:06:36 → 11:07:03 | ~27s | 26.985s |
| 2 | 11:07:52 → 11:08:15 | ~23s | 22.462s |
| 3 | 11:08:59 → 11:09:21 | ~22s | 22.217s |

Expected measured sum: approximately **72s** from independently read whole-second
Android events. FocusTrace persisted **71s**, **3 launches**, exactly **3 intervals**
summing **71.664s**. Difference versus raw reconstruction: **−1s** (within ±3s);
versus the native-persisted millisecond interval sum: **−0.664s**, consistent with
whole-second storage. No duplicate, missing-final-only, zero, or continuous interval
spanning the Home gaps was observed. Native/SQLite accounting **PASS**.

Intermediate Home DB snapshots did not yet include these sessions. Reopening `.dev`
triggered live collection and saved all three. Launch was WARM, not an observed
normal process-death test. Debug logs show two successful current-day saves, followed
by two historical reads with empty candidate lists. Calculator appeared in the
refreshed dashboard bubbles; tapping Calculator confirmed **1m** in its tooltip,
consistent with 71s at minute display precision. UI display **PASS**; evidence
`sep11-test-b-calculator-ui.png`. Digital Wellbeing was not measured. No production logic was changed.

Evidence under `build/device-session-1/`: `sep11-test-b-baseline.json`,
`sep11-test-b{1,2,3}-android-events.txt`, `sep11-test-b-raw-reconstruction.json`,
`sep11-test-b-db-comparison.json`, `sep11-test-b-logcat.txt`,
`sep11-test-b-after.png`, timer records and private before/after SQLite copies.

### DEVICE VERIFIED — Test C: direct app switch, accounting PASS

September 11, same device/build/timezone. Calculator baseline **71s / 3 launches**;
Clock baseline **60s / 4 launches**. User opened Calculator; the measurement helper
launched the real Clock activity using `adb shell am start -W` after approximately
30s, and the user subsequently pressed Home. No synthetic usage events, clock
changes, app force-stop or data writes were injected. This verifies a real direct
activity switch initiated through ADB, not the separate Recents navigation UX.

| App | Raw Android interval (BST, whole-second display) | Native-persisted duration | Stored before → after | Delta | Difference vs raw |
|---|---|---:|---:|---:|---:|
| Calculator | 11:13:14 → 11:13:45 (~31s) | 30.662s | 71s → 102s | +31s | ~0s |
| Clock | 11:13:45 → 11:14:19 (~34s) | 33.914s | 60s → 94s | +34s | ~0s |

Calculator paused at `1789121625385`; Clock resumed at `1789121625612`, a
227ms transition gap and **no overlap** in the stored intervals. Calculator did
not continue accumulating while Clock was foreground. Each app gained exactly
one launch and one interval. Accounting **PASS**, within ±3s per measured interval;
the manually ended Clock duration exceeded its intended 30s and was compared to
its actual Android interval. Digital Wellbeing was not measured.

On returning to `.dev`, Android reported a HOT existing-task return. Native
collection/save followed, without a manual refresh. Dashboard displayed Tracked
53m. Clock tooltip subsequently showed **1m**, consistent with its stored 94s
(`sep11-test-c-clock-ui.png`). Calculator tooltip also showed **1m**, consistent
with 102s (`sep11-test-c-calculator-ui.png`). Both UI displays **PASS** at minute
precision; they cannot independently resolve these sub-minute increases. Historical requests
again logged empty candidate lists. Home snapshot still held the prior totals;
the subsequent live refresh persisted both new intervals. No defect reproduced.

Evidence under `build/device-session-1/`: `sep11-test-c-baseline.json`,
`sep11-test-c-android-events.txt`, `sep11-test-c-db-comparison.json`,
`sep11-test-c-clock-launch.json`, `sep11-test-c-logcat.txt`,
`sep11-test-c-after.png`, timer record and private SQLite snapshots.

### Session 1 protocol adjustment — avoid redundant checks

At the user's request, the separate ~30s foreground / ~30s Home repetition (Test D)
is not run: Tests B and C already provide observed pause events and intervals
excluding Home gaps. This is supporting Home-transition evidence, not a claim
that the exact separate Test D protocol was executed. Repeated minute-only tooltip
checks are omitted unless needed to resolve a UI discrepancy. Proceeding to the
distinct screen-off/lock test (Test E); no production logic changes.

### DEVICE VERIFIED — Test E: screen off / lock and unlock, accounting PASS

September 11, Calculator baseline **102s / 4 launches**. User turned the screen
off earlier than the cue, so actual pre-lock use was ~8s rather than 30s. This
variation is explicitly measured; the test still exercises a long screen-off gap.

Raw Android events (BST, whole-second display): resumed 11:18:58;
SCREEN_NON_INTERACTIVE and Calculator paused/stopped 11:19:06; KEYGUARD_SHOWN
11:19:07; SCREEN_INTERACTIVE and Calculator resumed 11:20:26; KEYGUARD_HIDDEN
11:20:27; Calculator paused on Home 11:20:37. The off interval was approximately
**80s**. During it, `dumpsys power` reported Dozing (screen non-interactive on this
Samsung; this should not be relabeled a guaranteed fully powered-off display).

Native-persisted Calculator intervals:
- `1789121938693` → `1789121946314`: **7.621s** before screen off.
- `1789122026696` → `1789122037670`: **10.974s** following wake/unlock.

These are two separate intervals with an **80.382s gap**, no giant interval and
no duplicate interval after unlock. Daily total **102s → 120s** (+18s), compared
to ~19s from whole-second raw events (difference −1s; within ±3s). Interval sum
is 18.595s; daily integer delta reflects aggregation/storage precision. Launches
increased from 4 to 6. Screen-off exclusion **PASS** for this observed transition.

The post-wake ACTIVITY_RESUMED precedes KEYGUARD_HIDDEN in the whole-second event
dump; accounting resumes at ACTIVITY_RESUMED. The sub-second/lockscreen transition
boundary is not separately resolved by this raw dump. Do not infer a lockscreen
leak defect from this ordering alone. This provides actual lock/unlock evidence;
the separately prescribed Test F repetition has not been run.

Locked and Home DB captures still held the previous snapshot; a HOT return to
`.dev` produced the updated total and two intervals through a logged native save.
No manual refresh, force-stop, synthetic events or code changes. Digital Wellbeing
and a per-app UI delta were not measured for this case; no repeated rounded-tooltip
check is claimed. Evidence under `build/device-session-1/`: `sep11-test-e-baseline.json`,
`sep11-test-e-screenoff-{events.txt,state.json}`, `sep11-test-e-android-events.txt`,
`sep11-test-e-db-comparison.json`, `sep11-test-e-logcat.txt`, screenshot and private
before/locked/Home/after SQLite snapshots.

### DEVICE VERIFIED — Test G plus resume refresh: PASS

September 11, Calculator baseline **120s / 6 launches** from Test E's final DB.
User opened Calculator and was instructed to leave it visible untouched. No
measurement-tool input was sent to Calculator during the session. At the one-minute
mark, ADB brought the existing `.dev` activity to the foreground (HOT, 91ms),
without force-stop, restart or manual refresh.

Raw Android resumed **11:23:53 BST**, paused **11:24:53**: approximately **60s**.
Native-persisted interval `1789122233761` → `1789122293583`: **59.822s**.
Daily total **120s → 180s**, delta **60s**, launch count **6 → 7**. Exactly one
new interval; raw-event difference approximately **0s**. Untouched foreground
accounting **PASS**, within ±3s. This also supplies an actual approximately
60-second continuous session, addressing the duration limitation in original Test A.
Touch inactivity is based on the controlled user instruction, not a raw touch log.

Return triggered a native query at `1789122293748`, saved by log timestamp
`1789122293.890`. Dashboard rendered the updated data without a manual refresh;
Calculator tooltip showed **3m**, matching the native-persisted **180s**. The
measurement tool tapped only that tooltip after the session ended. Resume-refresh
outcome **PASS** for this existing-activity return. A pre-session Calculator
numeric UI screenshot was not taken (baseline is SQLite 120s); do not claim an
observed 2m → 3m UI pair. The updated post-return value itself is device verified.
Digital Wellbeing was not measured. No code changes or reproduced defect.

Evidence under `build/device-session-1/`: `sep11-test-g-start.json`,
`sep11-test-g-return.txt`, `sep11-test-g-android-events.txt`,
`sep11-test-g-db-result.json`, `sep11-test-g-logcat.txt`,
`sep11-test-g-{return,after,calculator-ui}.png`, and the post-return SQLite copy.

### Session 1 checkpoint (after Test G)

| Check | State |
|---|---|
| Identity / v4 → v5 / existing-data preservation | PASS |
| Continuous foreground (~60s now observed in G) | PASS |
| Three short sessions | PASS |
| Direct Calculator → Clock switch | PASS |
| Home gaps | Verified through B/C; redundant separate D not run |
| Screen off and lock/unlock | PASS for E's actual transition; separate F not run |
| Visible untouched foreground | PASS |
| Existing-activity resume refresh | PASS; pre-session numeric UI screenshot missing |
| Notification shade | NEXT / not started |
| Historical recovery | Partial metadata/backoff observations; dedicated checks pending |

No passed scenario is scheduled for repetition unless a specific evidence gap or
reproducible failure requires it. Enforcement, force-stop, reboot, split-screen,
PiP and controlled overnight tests remain outside Session 1 and NOT YET VERIFIED.

### DEVICE VERIFIED — Test H: notification shade, foreground metric observed

Calculator baseline **180s / 7 launches**. Raw Android resumed at **11:26:42 BST**.
ADB window focus was explicitly `NotificationShade` at epochs **1789122453** and
**1789122483** (11:27:33 and 11:28:03), confirming observations 30 seconds apart.
No Calculator pause or global screen/lock stop event appeared during that span.
Notification contents/screenshots were not collected.

After the close-shade instruction, the next observation found **Home**, rather
than Calculator, foreground. Raw Calculator pause/stop occurred at **11:28:55**.
Therefore shade dismissal back to Calculator was not independently observed;
this procedural variation is not an application failure.

Native-persisted interval `1789122402943` → `1789122535083`: **132.140s**, including
the observed shade period. Daily total **180s → 312s** (+132s), launch count 7 → 8,
with exactly one new interval. Raw whole-second reconstruction is ~133s, difference
−1s (within ±3s). Classification: **app remains foreground according to our metric**
while the notification shade has window focus. Accounting agrees with Android's
resumed/paused stream on this Samsung/API 36 configuration (**PASS** for metric
consistency). This does not establish actual attention or universal OEM behavior.

No repeated UI tooltip check; per-app UI delta and Digital Wellbeing were not
measured. Post-return screenshot retained; database/native/raw-event comparison
is the quantitative evidence. No reproduced defect or production logic change.
Evidence under `build/device-session-1/`: `sep11-test-h-before-shade.json`,
`sep11-test-h-shade-{open,held,closed}.json`, `sep11-test-h-before-return-events.txt`,
`sep11-test-h-db-result.json`, `sep11-test-h-logcat.txt`, screenshot and SQLite copy.

Notification-shade observation is complete with the dismissal limitation above.
Proceeding to the remaining Session 1 historical-recovery checks; no accounting
scenario is restarted.

### DEVICE VERIFIED — September 14 historical-read checks

Same SM-A366B / API 36, `.dev` 1.0.6-dev / 7, unchanged package update timestamp,
Europe/London. Device was awake on Home. Prelaunch DB v5 integrity `ok`, 607 daily
rows and 6,416 intervals; consecutive DB/sidecar captures identical, journal empty.
No clear/import, forced work, clock change, synthetic historical state or code
change was performed. The latest APK byte hash was verified on September 11;
September 14 checked package version/update time, not a new byte hash.

Opened September 13 (unavailable) and September 12 (reconciled), then each again.
Actual UI: September 13 **2m**, corresponding to **132s** in SQLite; September 12
**1h 26m**, corresponding to **5,204s**. Initial September 12 screenshot caught
loading; `sep14-history-sep12-loaded.png` records the settled display.

- **PASS — bounded historical reads/backoff:** explicit daily history requests and
  accompanying report/history requests logged `today=false candidates=[]`. No OS
  query followed these requests. Current-day launch queries remained independent.
- **PASS — reconciled day not repeatedly rewritten:** September 12 totals, all
  overlapping intervals and metadata remained exactly unchanged, including
  `queried_at_ms=1789377886584` and full-day coverage through `1789254000000`.
- **PASS — preserve existing history/current-day independence:** September 11,
  12 and 13 totals/intervals/metadata were unchanged across the history-open cycle.
  All prior daily keys survived; post-check integrity `ok`. Current-day snapshots
  continued to save under September 14. No historical total became zero.
- **Observed retry cadence:** September 13 recovery attempts logged at epochs
  `1789386502.276`, `1789387403.434`, `1789388304.263`, approximately 15 minutes
  apart. Each reported `result=preserved historical=true seconds=11275`.
  September 11 likewise had a preserved reconstruction (13,748s vs stored 9,450s).

### UNRESOLVED — September 13 recovery acceptance

**Do not count this as successful historical repair.** September 13 remains at
**132s** (4 daily rows), status `unavailable`, despite three observed native
reconstructions reporting **11,275s**. Last successful partial coverage ends at
`1789267950160`; rejected attempts advance retry time, not accepted coverage.
This is a repeatable unrepaired-history observation; the exact rejection cause
and whether accepting the candidate would be correct are **INCONCLUSIVE**.

After observing repeated rejection, inspected the shared recovery/store source.
The log form establishes that the candidate passed the coarse `hasCoverage` gate
and reached `replaceDay`. Rejection can arise from transaction eligibility,
per-package duration preservation, or interval-coverage preservation. Existing logs
do not identify the rejecting condition. A larger whole-day sum alone does not
prove every package and stored interval is safely represented.

A read-only shell event reconstruction was attempted. Its earliest parsed lifecycle
event was `1789303676000`, later than the existing September 13 early-morning
intervals. Several saved intervals have no corresponding event in that shell dump;
one stored package has 37s saved and no reconstructed duration there. This
**does not prove the native queryEvents result has the same omissions**: dumpsys
and the app's query window expose different evidence. The whole-second shell
comparison cannot adjudicate native millisecond coverage. Keep the stored data;
do not bypass the guard, force zero, or mark the day reconciled on this evidence.

Next focused investigation: capture the exact rejected guard and corresponding
native per-package/interval comparison in debug-only diagnostics, then reproduce
with the retained stream. Do not restart passed timing tests or weaken protection
based only on the aggregate mismatch. No production logic was modified.

### Session 1 disposition / production gate

Available Session 1 measurements are recorded. Basic accounting and automatic
resume refresh passed. Notification-shade semantics were observed. Recovery
invocation, persisted metadata, preservation and repeated-read suppression are
device verified; successful controlled partial-day repair remains unresolved.
Naturally observed reconciled metadata from intervening days is not a controlled
midnight test. Normal process death, forced-stop behavior, reboot, limits, actual
block presentation, split screen, PiP and the genuine overnight case were not run.

**No production sign-off and no master merge is justified by these results.**
The recovery acceptance gap needs focused diagnosis before declaring historical
recovery device-verified. Session 2 enforcement/multi-window tests remain separate;
there is no reproduced basic-accounting defect requiring a speculative patch.

Evidence: `build/device-session-1/sep14-history-{identity,before-summary,comparison}.json`,
`sep14-history-logcat.txt`, `sep14-history-sep13-attempts.txt`,
`sep14-history-sep13-raw-comparison.json`, dated UI captures and private SQLite copies.
The comparison command asserted that recent historical totals, intervals and
metadata stayed identical; its results are retained in the JSON evidence. Raw evidence is local/ignored, not published.

### Recovery rejection diagnostics — implemented September 14

Diagnostic-only change: recovery thresholds/order, query window, retry periods,
Boolean result, schema and transaction boundaries are unchanged. The existing
`UsageHistoryRecovery` debug callback now reaches `UsageSnapshotStore.replaceDay`.
The first rejected guard reports captured bounds/timestamps, package totals or
an interval gap with at most two candidate neighbors. Generation-token values and
user content are excluded. Diagnostic callback failures cannot change persistence.
Production output remains disabled by the existing debuggable-app flag check.

AUTOMATED TEST VERIFIED: Gradle 8.12 command
`:app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain` passed.
**76 discovered / 75 passed / 1 existing benchmark skipped**, zero failures/errors;
lint/build passed. Five new tests cover duration and interval rejection, eligibility
reasons/token privacy, failing diagnostics and unavailable DB/schema. Existing
success and rollback tests run with a diagnostic callback. `git diff --check`
passed. Flutter suites were not rerun for this native-only diagnostic change.
Restricted Gradle startup stalled; retry with SDK/cache access succeeded.
Log: `build/recovery-diagnostic-android.log`.

DEVICE VERIFIED: `adb install -r` updated only `.dev` successfully (1.0.6-dev / 7).
APK `build/app/outputs/apk/debug/app-debug.apk`, SHA-256
`7d38152da4991f5e945fa5beaef2b15af91da714104e7617091ef81bccb85cb3`.
Baseline `497272da9bd1d4bdf0998120e8f4b1da06c54693` plus uncommitted changes.
All daily/interval/settings/restriction/metadata rows were identical in pre/post
installation snapshots. No clear/uninstall or production-package operation.
Update process replacement is not a normal OS process-death test.

Evidence: `build/device-session-1/diagnostic-build.json`,
`diagnostic-install-preservation.json`, private pre/post-install SQLite copies.
Exact rejection capture and second eligible attempt are **PENDING**: the phone
locked after installation. No cooldown or lock bypass, commit, push or master merge.

### DEVICE VERIFIED — diagnostic cause confirmed September 14

The installed diagnostic build recorded **two naturally eligible attempts**, at
captured epochs `1789405288707` and `1789406190022`, **901,315ms apart**. Both
produced the same precise `interval_gap` rejection for each affected day. No forced
retry, metadata alteration, process restart or additional timing exercise was used.

| Day | Stored interval (epoch ms) | Candidate interval (epoch ms) | Shift of both endpoints | Duration, unchanged |
|---|---|---|---:|---:|
| September 11 | 1789081228024–1789081255306 | 1789081228411–1789081255693 | +387ms | 27,282ms |
| September 13 | 1789255444326–1789255473832 | 1789255444591–1789255474097 | +265ms | 29,506ms |
| September 14 (current day) | 1789367480254–1789367485602 | 1789367480394–1789367485742 | +140ms | 5,348ms |

**Reproduced application defect: exact millisecond interval containment is too
strict for the observed duration-preserving endpoint shifts.** `preservesIntervals`
requires the fresh interval to cover the old start exactly. The 265ms uncovered
prefix rejects the entire September 13 transaction even though the matching
candidate interval has the same duration. Eligibility and per-package total guards
passed before this rejection. This is not a missing-generation, stale-write,
date-window or decreased-package-total rejection. The physical origin of the
endpoint shifts (for example clock correction or platform timestamp conversion)
is **not established**; do not label a specific Android/OEM mechanism proven.

September 13 therefore remains **132s / unavailable** instead of accepting the
11,275s candidate. September 11 remains 9,450s; September 14 remains **10,892s /
unavailable**, while its successive native candidates reported 13,603s and 14,504s.
Thus the shared guard also blocks current-day durable snapshots, not only history.
The UI can still receive live totals; that does not establish successful storage.
Only the first rejected interval is logged: fixing this one comparison does not
prove every subsequent guard will pass or certify the whole candidate day.

Post-confirmation SQLite integrity is `ok`; saved data was preserved. Diagnostics
correctly identify the same rejection twice, and the planned diagnostic task is
complete. No acceptance rule was changed. Five diagnostic tests and Android
validation remain as recorded above (75 passed, 1 skipped; lint/build passed).

Evidence: `build/device-session-1/diagnostic-resume-logcat.txt`,
`diagnostic-confirmed-comparison.json`, `diagnostic-confirmed-summary.json`, and
private SQLite copy. The comparison asserted equal start/end offsets, unchanged
29,506ms duration, and retry spacing of at least 15 minutes.

### Next correction — proposed, not implemented

Correct the shared interval-preservation comparison for narrowly matched,
duration-preserving timestamp translations, with a bounded one-to-one matching
rule. Keep strict containment for ordinary intervals and retain all package-total,
coverage, stale-write and transaction guards. Do not simply waive arbitrary small
gaps or accept the larger whole-day total. Validate the observed +265/+387/+140ms
cases and rejection of missing/shortened sessions, ambiguous/reused matches,
excessive shifts, false zeroes and date-boundary changes before updating `.dev`.
Then repeat the affected recovery/persistence checks, not passed timing exercises.

**Production gate: stop and fix this reproduced P0 persistence/recovery defect
before merging.** Enforcement/multi-window work remains pending and is not a reason
to waive this defect. No commit, push, master merge or production readiness claim.

### Timestamp-translation correction — implemented September 14

The shared `UsageSnapshotStore.preservesIntervals` guard retains exact coverage
as its primary rule. If that fails, a fallback accepts only a same-package,
overlapping match whose start moves at most **1,000ms**, with unchanged duration.
Both intervals must stay inside the captured day/query bounds. Candidate selection
must be unique in both directions and cannot reuse a candidate already supplying
strict coverage for another stored interval. Ambiguous, missing, disjoint, shorter
or excessively shifted matches remain rejected.

An interval ending exactly at the previous accepted snapshot's `covered_until_ms`
may have grown in the new query: it was clipped at that snapshot boundary. Such a
match must still retain at least its previous duration and satisfy the same bounded,
one-to-one rules. Closed sessions cannot arbitrarily grow through this fallback.
The previous coverage value is read inside the existing write transaction.

The one-second bound is a conservative engineering policy based on the measured
140/265/387ms translations, **not an Android timestamp-stability guarantee**. It
is a named constant; larger shifts remain unavailable rather than being accepted
blindly. Per-package duration preservation, coarse event coverage, generation,
staleness, cooldown, atomic writes and schema v5 remain unchanged. No new public
API or schema migration. UI/ViewModel/repository ownership is unchanged: both
worker and Flutter-triggered snapshots reach this shared native store.

AUTOMATED TEST VERIFIED (fresh runs):
- Flutter **109 passed**: `dart.exe --disable-analytics flutter_tools.snapshot test --no-pub`.
- Flutter analysis **no issues**: same launcher, `analyze --no-pub`.
- Android **82 discovered / 81 passed / 1 existing benchmark skipped**, zero failures/errors:
  Gradle 8.12 `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain`.
  Debug lint and APK build passed. Final Android run followed the strict-coverage
  contributor review adjustment.
- Six new tests cover observed shifts and negative/boundary offsets, idempotence,
  missing/shortened/excessive/ambiguous matches and false zeroes, candidate reuse
  including strict coverage, clipped-session extension, cross-day/disjoint matches,
  and rollback after a translated interval was accepted. Earlier diagnostics,
  recovery, migration and lifecycle tests remain present.

Logs: `build/recovery-translation-flutter.log`, `recovery-translation-analyze.log`,
`recovery-translation-android-final.log`. Exact APK/results:
`build/device-session-1/translation-build.json`.

DEVICE VERIFIED — installation/data preservation only: `adb install -r` successfully
updated `com.stepandemianenko.focustrace.dev`, 1.0.6-dev / 7. APK
`build/app/outputs/apk/debug/app-debug.apk`, SHA-256
`f432784af18a9cfafbbf452d802a7e9d2f7ffb8623616e381a2b87f6d74b3549`.
Baseline `497272da9bd1d4bdf0998120e8f4b1da06c54693` plus uncommitted changes.
Pre/post-install daily, interval, settings, restriction and metadata rows are
identical (`translation-install-preservation.json` and private SQLite snapshots).
No production-package operation, clear/uninstall, commit, push or merge.

### Post-update device checkpoint — September 14, 18:48–18:57 BST

Device: Samsung SM-A366B, Android 16/API 36; the correction APK identified above.
No further production logic changes were made during this checkpoint.

**DEVICE VERIFIED — September 13 repair: PASS.** The ordinary recovery request
captured `now=1789408112135`, with the historical day window
`1789254000000..1789340400000` in Europe/London. Native reconstruction logged
11,275 seconds and `result=saved`. SQLite increased from 132 to **11,260 seconds**,
with `status=reconciled` and `covered_until_ms=1789340400000`. Native logging floors
the aggregate milliseconds; persisted totals floor each package separately, so
these two sums differ by 15 seconds. The historical dashboard displays **3h 7m**.
This verifies repair of a real partial day; it does not establish controlled
wall-clock accuracy for every recovered session or verify an overnight scenario.

**DEVICE VERIFIED — repeated historical reads: PASS within the recheck interval.**
After Today → Yesterday navigation, all 31 daily rows, 299 intervals and the
September 13 metadata row were identical across three database captures.
Historical request logs show `candidates=[]`; no historical query/rewrite occurred.
The current-day query still runs when opening Today, as designed. SQLite schema
is v5 and `integrity_check` is `ok`. No duplicated intervals or zeroing observed.

**DEVICE VERIFIED — current-day persistence: FAIL, reproduced.** Requests captured
at `1789408112135`, `1789408343134`, `1789408343191`, `1789408596585` and
`1789408624734` reject the same Clock interval. Stored interval
`1789376100882..1789376112543` and candidate
`1789376101022..1789376112683` both last 11,661ms, shifted +140ms. A nearby stored
65ms interval (`1789376112578..1789376112643`) lies inside that translated candidate.
Source inspection after reproduction shows that strict coverage reserves the
candidate for the short interval, preventing its use as the long interval's
translation match. This is a remaining matching/ownership defect in the guard.
The full replacement sequence for the tiny interval has not yet been captured;
do not infer that weakening the overlap check alone is safe.

Today remains at **10,892 stored seconds**, `status=unavailable`, with previous
accepted coverage retained, while the last native candidate totals **14,981s**.
Valid data survives, but newer data is not persisted. This is not a timing-test
failure and is not resolved by the successful September 13 repair.

**NOT YET VERIFIED — September 11 repair.** The corrected build rejected a 125ms
browser interval shifted +387ms, which does not overlap its stored position.
One eligible attempt is captured on this build. Leave the normal 15-minute retry
intact; another eligible capture is needed before classifying this distinct case
as reproduced under the corrected build. Existing 9,450 seconds remain intact.

Evidence (private, ignored): `build/device-session-1/translation-ready-logcat.txt`,
`translation-ready-comparison.json`, `translation-history-repeat-logcat.txt`,
`translation-history-stability.json`, `translation-history-settled.png`, and the
`translation-ready`, `translation-history-first`, `translation-history-repeat`
SQLite snapshots. Earlier passed timing exercises were not repeated.

**Recommendation: stop and fix the reproduced P0 persistence guard defect.**
No enforcement, force-stop, reboot, split-screen, PiP or overnight test was performed.
The previous automated results remain evidence for this installed build; suites
were not rerun for this documentation-only checkpoint. No commit/push/master merge,
production-package operation or production-readiness claim.

### Complete-sequence matching correction — September 14, 19:05 BST

CODE VERIFIED: `UsageSnapshotStore` now also recognizes a unique uniform shift
of the complete stored package sequence. Every stored session must have a unique
candidate at the same offset, within the existing 1,000ms/day bounds and with
unchanged duration (or previously allowed snapshot-clipped growth). Old sessions
must not overlap, at least two are required, and at least one must overlap its
translated counterpart. This avoids assigning a long translated session to the
adjacent tiny session when the entire sequence is accounted for independently.
An isolated disjoint short session still fails the original safeguard.

No missing session, shorter duration, inconsistent sequence shift, ambiguous
complete shift or out-of-bounds translation is waived by this new route. Existing
strict coverage and individual translation rules remain as fallbacks. Per-package
totals, transactions, generation checks, stale-write protection and schema v5 are
unchanged. The bounded per-day scan remains an explicit performance tradeoff.
No Flutter/UI ownership change or additional logging was needed.

AUTOMATED TEST VERIFIED: two new tests cover the captured Clock intervals with
a controlled complete replacement sequence, idempotence, and missing/shortened/
inconsistent/ambiguous tiny-session replacements. The replacement for the third
65ms interval is synthetic until captured on-device; this is not device evidence.
All earlier tests remain unchanged.

Fresh validation:
- `dart.exe --disable-analytics flutter_tools.snapshot test --no-pub`: **109 passed**.
- Same launcher `analyze --no-pub`: **no issues**.
- Gradle 8.12 `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain`:
  **84 discovered / 83 passed / 1 existing benchmark skipped**, zero failures/errors;
  lint and APK build passed.
- Logs: `build/recovery-sequence-{android,flutter,analyze}.log`.

DEVICE VERIFIED — install preservation: `adb install -r` succeeded for
`com.stepandemianenko.focustrace.dev`, `1.0.6-dev` / 7, baseline
`497272da9bd1d4bdf0998120e8f4b1da06c54693` plus uncommitted P0 changes.
APK: `build/app/outputs/apk/debug/app-debug.apk`; SHA-256
`c1fbf76b3f93ca6f9a666c7c2e5822b665c36fac5f915790a86867fffee180f6`.
All seven existing database tables were identical before/after installation
(`sequence-install-preservation.json`, `sequence-preinstall`, `sequence-postinstall`
under `build/device-session-1`). No production data was touched.

NOT YET VERIFIED: the phone is screen-off/locked, and the newly installed process
has not emitted a recovery request. Unlock is required to verify today's accepted
snapshot, the actual tiny Clock replacement, historical repair and repeated-read
stability. Do not repeat passed timing exercises or bypass historical backoff.
This correction is not yet a device-confirmed resolution. Production gate remains
open; no commit, push, merge, P1–P3, enforcement or multi-window work performed.

### Complete-sequence correction — DEVICE VERIFIED September 14, 19:09–19:10 BST

Samsung SM-A366B / Android 16, same `.dev` APK SHA-256 `c1fbf76b...180f6` above.
The phone was unlocked; only FocusTrace navigation and read-only captures were used.
No code changes or repeated timing exercises in this checkpoint.

**Current-day persistence: PASS for the reproduced Clock defect.** Native requests
at `1789409343002`, `1789409370268` and `1789409402530` each logged `result=saved`.
The latter two native totals were 15,313s and 15,346s; SQLite stored 15,305s and
15,338s respectively (per-package flooring), up from the previously stuck 10,892s.
The dashboard screenshot shows 4h 15m. Metadata is `partial`, with both query time
and accepted coverage advancing to `1789409402530`, not falsely finalized today.

All three Clock intervals are now physically captured in the accepted database:

| Start ms | End ms | Duration ms |
| --- | --- | ---: |
| 1789376100600 | 1789376100988 | 388 |
| 1789376101022 | 1789376112683 | 11,661 |
| 1789376112718 | 1789376112783 | 65 |

Each endpoint is +140ms from its previous stored counterpart; all durations and
three separate sessions survive. This confirms the third replacement that was
previously only a synthetic test fixture.

**Concurrent stale-write protection: PASS for an observed race.** A request captured
at `1789409342993` reached persistence after the newer `1789409343002` snapshot.
It logged `rejected=stale_result`; the newer partial snapshot remained accepted.
This is one real concurrency observation, not exhaustive race verification.

**Repeated historical reads: PASS inside cooldown.** September 13 retained all
31 daily rows, 299 intervals and identical reconciliation metadata across captures.
History requests logged `candidates=[]`, with no historical query/rewrite. Database
integrity is `ok`. Current-day queries on Today navigation are independent.

**September 11: NOT YET VERIFIED on this build.** Its previous attempt timestamp
is `1789409020272`, so the ordinary 15-minute retry becomes eligible at
19:18:40.272 BST. These reads correctly skipped it during backoff; its 9,450 saved
seconds remain intact. Do not equate this skip with a successful repair or bypass
the retry policy. Next step is the eligible historical recovery observation.

Evidence under `build/device-session-1`: `sequence-unlocked-logcat.txt`,
`sequence-unlocked-ui.png`, `sequence-clock-accepted.json`,
`sequence-verified-logcat.txt`, `sequence-verified-summary.json`, and SQLite copies
`sequence-unlocked`, `sequence-history-first`, `sequence-history-repeat`.
The installed build's prior automated totals remain 109 Flutter / 83 Android passed,
1 existing Android benchmark skipped; no suites rerun for this documentation update.
Production gate remains open for unresolved history and the previously listed
lifecycle, enforcement, reboot, split-screen, PiP and overnight checks.

### September 11 eligible retry — September 14, 19:19 BST

DEVICE VERIFIED: ordinary historical navigation after the 15-minute backoff
triggered a recovery request at `1789409958032` (19:19:18.032 BST).
Query window: `1788994800000..1789409958032`, 11,791 retained events.
The target day remained `1789081200000..1789167600000` in Europe/London.
No cooldown, timestamps, device clock or database state was manually altered.

**Recovery completeness: FAIL for this attempt; distinct rejection not yet reproduced.**
The log now identifies `com.google.android.apps.healthdata`, with stored interval
`1789140880197..1789140880290` and candidate
`1789140880584..1789140880677`. Both last 93ms; endpoints differ by +387ms.
Only one stored interval exists for this package on this day. No temporal overlap
or multi-session package anchor is available for the installed guard's fallback.
The previous browser interval is no longer the reported first rejection; that
alone does not establish that every other interval is recoverable.

Native candidate total: **13,748s**. SQLite remains **9,450s**, UI **2h 37m**,
status `unavailable`; last accepted coverage remains `1789142050835`.
All **25 daily rows and 275 intervals** are byte-for-value unchanged across the
before/after SQLite query results. `integrity_check=ok`. Preservation: **PASS**.
Subsequent historical reads log `candidates=[]`: retry backoff is respected.
An independent current-day request still logged `result=saved`.

Evidence: `build/device-session-1/sep11-retry-{before,after}` database captures,
`sep11-retry-logcat.txt`, `sep11-retry-ui.png`, `sep11-retry-comparison.json`.
No production logic changed; no automated suites rerun for this evidence update.

Next: repeat this distinct rejection after its next normal eligibility at
**19:34:18.032 BST** before considering any further code change. Do not weaken
isolated-short-session data protection on this single observation. Historical
recovery is not fully device-verified; the production gate and Session 2 remain open.

### Final bounded production gate — September 15

The user's final scope supersedes earlier requirements for exhaustive lifecycle,
multi-window and overnight verification. Keep passed timing, screen-off, refresh,
September 13 recovery, Clock persistence, stale-write and preservation checks closed
unless a new change could affect them.

September 11: **P1 / deferred, non-blocking limitation**. The observed recovery
attempt failed to reconcile; preservation passed. The cause/acceptability of the
isolated shifted session remains inconclusive. Do not relabel it as successful
recovery or repeat it unless normal current usage shows the same material problem.

Remaining execution order:
1. Core enforcement: smallest practical limit, use to threshold, observe block,
   reopen once and verify restriction. Required; ordinary failure is P0.
2. One normal reboot: launch, settings/limits and history preserved, tracking and
   enforcement work in the normal flow. Significant user-facing failure is P0.
3. One short split-screen or PiP sanity check if practical. Ambiguous accounting
   alone is a documented limitation, not a release blocker.

Initial connection check: `adb devices -l` returned no devices. These final checks
are **NOT YET VERIFIED**, not failed. Connect/unlock the Samsung to begin core
enforcement. No code change or final submission recommendation at this checkpoint.

September 15, approximately 11:56 BST: connection restored to SM-A366B
(device serial retained only in private evidence). `.dev` launches; Usage Access and overlay app-ops are allowed.
Configured Calculator (`com.sec.android.app.popupcalculator`) through the normal
Restrictions UI with the minimum **5-minute daily limit**. SQLite settings confirm
`type=dailyLimit, limitMinutes=5`; existing TikTok schedule remains present.
No Calculator daily row was stored for September 15 at setup. This is a stored
baseline, not proof of zero native usage. Before/after captures:
`build/device-session-1/gate-enforcement-before` and `gate-limit-saved`;
minimum-limit UI: `gate-limit-minimum.png`. Enforcement test is prepared, not passed.

September 15, approximately 12:04 BST — **Core enforcement: DEVICE VERIFIED PASS**.
User reports Calculator blocked after using it with the 5-minute rule. SQLite
records `blocked / dailyLimit` at `1789470205780`. One ordinary launcher-icon
reopen displayed the full-screen Calculator / Daily limit reached / Until 00:00
overlay. Window Manager identifies its owner as `.dev` with a displayed
`APPLICATION_OVERLAY` surface. No trivial reopen bypass observed. Exact initial
block latency was not independently timed; this is the bounded functional check.
Returning to FocusTrace persisted Calculator usage at 320 seconds and native logs
show `result=saved`. Evidence: `gate-block-observed`, `gate-block-reopen.png`,
`gate-pre-reboot-settled`, `gate-pre-reboot-logcat.txt` under the private evidence
directory. No production code change required. Next: one normal reboot.

### September 15 reboot finding and focused correction

The normal reboot completed (boot IDs differ; `sys.boot_completed=1`). FocusTrace
cold-launched. All 5 settings, 653 daily rows and 6,812 intervals matched the
pre-reboot snapshot exactly; Calculator retained 320 seconds and its 5-minute rule.
SQLite integrity was `ok`. **Preservation: PASS.**

**Reboot enforcement: reproduced P0 before correction.** Calculator reopened
without a block, then remained usable after a Home/reopen repeat and accepted
numeric input. The `.dev` blocker service was running in the foreground. Android's
post-reboot trace contained less earlier usage; the blocker bootstrapped solely
from that trace. Current-day persistence also repeatedly rejected a duration
decrease (stored 113s vs queried 111s for another package), preserving the entire
old day but preventing fresh usage writes. This affects normal reboot use and
meets the user's significant normal-flow failure standard; it is not the deferred
September 11 edge case.

Evidence: `gate-reboot-comparison.json`, `gate-reboot-launch.png`,
`gate-reboot-calculator.png`, `gate-reboot-reopen-repeat.png`,
`gate-reboot-logcat.txt` and `gate-post-reboot-{before-open,open}` SQLite captures
under `build/device-session-1`.

CODE VERIFIED correction uses the existing accepted current-day snapshot as a
prefix. The native store reads totals, intervals and coverage together under a
transaction, requiring matching date boundaries, generation and nonfuture query
time. Blocker bootstrap restores at least accepted usage plus observed events
after that boundary; incremental ticks then add new time. A rejected current-day
replacement can continue that prefix with post-boundary intervals in the existing
atomic replacement transaction. It stays `partial`; lost reboot gaps are not
certified complete. Historical acceptance rules remain unchanged. No new schema,
Flutter persistence owner or service was added. SQLite reads occur at bootstrap,
not every enforcement tick; snapshot fallback retains the existing per-day writes.

AUTOMATED TEST VERIFIED: Gradle 8.12
`:app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain` passed:
**89 discovered / 88 passed / 1 existing benchmark skipped**, zero failures/errors;
lint/build passed (`build/gate-reboot-fix-android-final.log`). Five focused tests
cover missing pre-reboot events/current-day continuation, repeated saves,
spent/partial allowance and day reset, generation/date guards, rollback, and the
real blocker bootstrap reading SQLite with no earlier Android events. Flutter was
unchanged and its earlier 109-test/clean-analysis result was not rerun or relabeled.

Installed `.dev` 1.0.6-dev / 7 using `adb install -r`; all compared settings, daily
rows, intervals, metadata and restriction events were unchanged across install
(`gate-fix-install-preservation.json`). APK `build/app/outputs/apk/debug/app-debug.apk`,
SHA-256 `cefdaf67dcf3bc75f40b3c575232ccbcf6a82a206747ec2e1c83500103e783f6`.
Baseline remains `497272da9bd1d4bdf0998120e8f4b1da06c54693` plus uncommitted changes.

DEVICE VERIFIED partial result: after update, current-day writes resumed via
`result=continued` at `1789470921138` and `1789470921240`; retained prefix plus
new usage was 6,831s (the subsequent generic log line reports the shorter raw
Android query separately). Evidence: `gate-fix-launch-logcat.txt` and
`gate-fixed-pre-reboot`. Final corrected reboot enforcement verification is pending;
one post-fix reboot repeats only the affected failed flow. No P1/P2 work or publishing.

September 15, approximately 12:19 BST — **Corrected reboot: DEVICE VERIFIED PASS**.
User confirms Calculator remains blocked after reboot; SQLite independently records
a new `blocked/dailyLimit` event at `1789471121715`. Boot ID changed again. All five
settings remain identical, Calculator retains 663 seconds, all 653 daily keys
survive without duration decreases, and all old intervals survive (6,817 to 6,821
with new usage). Integrity is `ok`. Current-day continuation writes succeed after
boot, advancing accepted usage from 6,831s to 6,847s in the captured logs. This
completes the single post-fix verification of the reproduced failure.
Evidence: `gate-fixed-post-reboot`, `gate-fixed-post-reboot-logcat.txt`,
`gate-fixed-reboot-result.json`, `gate-fixed-reboot-preservation.json`.

## Final production-gate decision — September 15

The user requested completion after the corrected reboot check. Optional multi-window
testing was therefore not performed. Earlier failures and pending checkpoints remain
above as chronological evidence; this section is the current release assessment.

| Check | Result | Severity | Action |
| --- | --- | --- | --- |
| Core enforcement | PASS | — | Five-minute Calculator limit blocked ordinary use; one reopen was blocked. |
| Reboot | PASS after fix | P0 resolved in tested flow | Accepted usage restored; settings/history survive; blocking and current-day writes verified after the single post-fix reboot. |
| Multi-window | LIMITATION — not tested | P1 verification limitation; no observed defect | Optional check skipped on request to finish; split-screen/PiP behavior is not certified. |

**READY WITH DOCUMENTED NON-BLOCKING LIMITATIONS**

This recommendation applies to the tested uncommitted source and `.dev` build
identified by SHA-256 `cefdaf67dcf3bc75f40b3c575232ccbcf6a82a206747ec2e1c83500103e783f6`
on Samsung SM-A366B / Android 16. It is not evidence that a production release
artifact has been built, signed, uploaded or tested on other Android/OEM versions.

Accepted limitations: September 11 remains incomplete but safely preserved (P1);
split-screen/PiP and the controlled overnight scenario remain unverified; uncertain
reboot gaps are not reconstructed aggressively. No unresolved P0 was observed in
the final tested normal flow. Normal process-death permutations were not added to
this bounded session.

Final relevant validation: Android 88 passed / 1 existing benchmark skipped,
lint/build passed. Earlier Flutter 109 passed and clean analysis remain prior
evidence, not new runs after the native-only correction. No source changes followed
the installed correction's successful device verification.

Files changed for the final correction: `UsageSnapshotStore.kt` (accepted snapshot
read), `UsageStats.kt` (blocker bootstrap restoration), `UsageHistoryRecovery.kt`
(current-day continuation), `UsageHistoryRecoveryTest.kt` (five focused tests),
and this audit. The earlier audit fixes remain intact. Calculator's five-minute
test restriction remains configured in `.dev`; existing production-package data
was untouched. No commit, push, merge, publishing or GitHub issue creation occurred.
Final gate work stopped here.

## Publication review and production baseline metrics — September 16

Current gate: **READY WITH DOCUMENTED NON-BLOCKING LIMITATIONS**. This section and
September 15's final decision supersede all earlier open-P0 drafts, pending device
checklists, and interim failures. Chronological evidence above is retained.

The final source review covered shared event reconstruction, blocker/bootstrap and
boot receiver paths, native snapshot transactions, Flutter schema ownership,
generation/stale-result guards, current-day continuation, and regression tests.
No new material P0 was found. Historical acceptance remains conservative; failed
recovery preserves stored evidence. Android has one paired snapshot writer;
Flutter owns additive schema v5 migration and reads reports transactionally.

Recovery diagnostics are intentionally retained behind FLAG_DEBUGGABLE. They log
query bounds, aggregate counts and rejected package/interval evidence, never
recovery-generation tokens or app content. They are disabled in release builds.
No temporary debug override, forced retry, private database, unrestricted logcat,
screenshot, APK, signing secret or environment file belongs in the commit.
The removed activity helper was dead code. Generated localization files have no
content diff and are excluded; skill installations are unrelated local work.

### Production baseline metrics

| Metric | Verified baseline |
| --- | --- |
| Final Flutter validation | September 16: 109 tests passed; static analysis reported no issues. |
| Final Android validation | September 16: 89 discovered, 88 passed, 1 existing benchmark skipped; 0 failures/errors. |
| Lint / artifact | Debug and release lint passed, each with 0 errors and 26 warnings; release APK assembly passed. |
| Core enforcement | Five-minute (300s) Calculator daily limit blocked use. Persisted usage on returning to FocusTrace was 320s; exact block latency was not timed. |
| Ordinary reopen | One launcher reopen remained blocked; no trivial bypass observed. |
| Reboot preservation | All 5 settings and 653 daily keys preserved; durations did not decrease; old intervals survived (6,817 to 6,821 with new usage). |
| Corrected reboot enforcement | Passed on September 15; Calculator remained blocked and retained 663s. |
| Current-day persistence | Accepted continuation resumed after reboot, advancing from 6,831s to 6,847s; partial coverage remained explicit. |
| Stale-write protection | Observed stale request rejected while the newer accepted snapshot survived. |
| September 13 recovery | Passed: persisted usage rose from 132s to 11,260s; 31 daily rows and 299 intervals remained stable on repeat reads. |
| September 11 limitation | Incomplete, non-blocking P1; 9,450s, 25 daily rows and 275 intervals preserved through failed recovery. |
| Database integrity | Device SQLite integrity_check returned ok. |
| Crash count | No aggregate crash count established by this audit; not reported as zero. |
| Physical verification identity | Samsung SM-A366B, Android 16/API 36, user 0; com.stepandemianenko.focustrace.dev, 1.0.6-dev / versionCode 7. |
| Device-verified APK | SHA-256 cefdaf67dcf3bc75f40b3c575232ccbcf6a82a206747ec2e1c83500103e783f6; baseline 497272da9bd1d4bdf0998120e8f4b1da06c54693 plus the reviewed reliability source. |

Final commands used the installed Dart executable with `--disable-analytics` and
`C:/Flutter/flutter/bin/cache/flutter_tools.snapshot`: `test --no-pub` and
`analyze --no-pub`. Gradle 8.12 ran
`:app:testDebugUnitTest :app:lintDebug :app:lintRelease :app:assembleRelease --console=plain`.
`git diff --check` passed. Logs and artifact remain ignored under
`build/closure-{flutter,analyze,android}.log` and `build/app/outputs/apk/release/`.
The release artifact was assembled locally; it was not installed or submitted to Play.

No production logic changed after the device-verified correction. The physical
matrix was not rerun. Split-screen/PiP and exhaustive overnight/process-lifecycle
permutations remain unverified. The former history-recovery and enforcement P0
issue drafts are superseded; seven P1/P2 drafts remain backlog. No GitHub issues
were created. Publication uses a focused reliability commit on the existing
feature/closed-test development branch, without a master merge.
