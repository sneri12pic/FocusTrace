# Physical-device verification protocol (archived reference)

The September 15 bounded gate is complete: **READY WITH DOCUMENTED NON-BLOCKING LIMITATIONS**. Core five-minute enforcement, ordinary reopen, corrected reboot, and current-day persistence passed. September 11 reconstruction remains safely incomplete; split-screen/PiP and exhaustive lifecycle/overnight permutations remain unverified. See [the authoritative audit](closed-test-audit.md).

The instructions below preserve the original protocol as reference. They are not outstanding release requirements and must not restart the completed matrix.

## Device and evidence

- Connected/approved target: Samsung SM-A366B, Android 16 / API 36, user 0.
- Original audit target: Samsung SM-M135F, Android 14 / API 34; run this same matrix
  on it separately. SM-A366B results cannot be labeled SM-M135F/Android 14 results.
- Test package: `com.stepandemianenko.focustrace.dev`. Production package is separate.
- Before starting, record APK SHA-256, baseline/dirty state, model/API, profile,
  date/time/timezone, battery optimization, Usage Access/overlay/notification permissions.
- Save existing restriction settings via the app's export if desired. Use two
  harmless launchable apps A/B without existing limits for accuracy tests. Avoid
  unsaved work in any app that will later be force-stopped. Do not disable/change
  production FocusTrace or its data. Record if its existing restrictions interfere.
- Use a stopwatch and per-app **before/after deltas**, since existing daily totals
  must survive. Digital Wellbeing is a comparison source, not an exact oracle:
  record its rounding/update lag separately. A proposed controlled-session
  tolerance is ±3 seconds per 60 seconds; unexplained excess remains a failure.
- Never record messages, page contents, credentials or notification text.

Use this record for **every numbered case**:

```text
Case / device / APK hash / timezone:
Start/end timestamps and steps:
Expected (seconds / accounting policy / allowance):
FocusTrace before → after / delta:
Digital Wellbeing before → after / delta / rounding:
Raw Android events if available (type, package, timestamp):
Difference (FocusTrace minus stopwatch; separately minus Wellbeing):
Recovery metadata or block/service evidence:
Pass / Fail / Inconclusive and reason:
```

## 1. Start evidence capture and verify installation

Open the `.dev` app; verify existing data survives and no permission changes are
unexpected. This first open performs the v5 migration if needed. Record crashes,
DB errors and existing history before interpreting any totals. Check package and
version independently; both launchers may have the same visible name.

PowerShell helpers (replace serial only after confirming the target):

```powershell
$adb = 'C:/Users/Stepan/AppData/Local/Android/sdk/platform-tools/adb.exe'
$serial = '<approved-device-serial>'
$devPackage = 'com.stepandemianenko.focustrace.dev'
& $adb -s $serial shell dumpsys package $devPackage
& $adb -s $serial shell cmd appops get $devPackage GET_USAGE_STATS
& $adb -s $serial shell cmd appops get $devPackage SYSTEM_ALERT_WINDOW
& $adb -s $serial logcat -v epoch 'FTUsageRecovery:D' 'FocusTrace:E' '*:S'
```

Recovery logs are debug-only and contain query boundaries, event counts, candidate
dates, saved/preserved outcomes and aggregate seconds; no screen content. An empty
candidate list and no following recovery query demonstrates a skipped historical
request. Live-today requests still query today; distinguish them by `today=true`.
Do not clear global logcat. Save only the test interval under ignored `build/`.
If necessary, `adb shell dumpsys usagestats` supplies system evidence; retain only
selected test packages/event types/timestamps, not the unrestricted dump in Git.

For metadata, use Android Studio Database Inspector if this runtime supports it,
or a consistent read-only SQLite snapshot. Do not copy only the live DB while a
journal/WAL transaction may be active. Useful read-only SQL:

```sql
PRAGMA user_version;
SELECT day, status, start_ms, end_ms, timezone_id, queried_at_ms, covered_until_ms
FROM usage_snapshot_days ORDER BY day;
SELECT day, app_key, duration_seconds FROM daily_app_usage
WHERE app_key IN ('TEST_PACKAGE_A', 'TEST_PACKAGE_B') ORDER BY day;
SELECT app_key, started_at, ended_at FROM usage_intervals
WHERE app_key IN ('TEST_PACKAGE_A', 'TEST_PACKAGE_B') ORDER BY started_at;
```

## 2. A — accuracy and resume

Run in order, recording each independently. Keep unrelated foreground use out of
measurement intervals; stopwatch time includes only the specified test phase.

| Case | Controlled steps | Expected |
|---|---|---|
| A1 | A visible continuously for 60s, then Home | About 60s for A |
| A2 | Three 10s A sessions, 10s on Home between | About 30s A, no gap inflation |
| A3 | A 30s → Home 30s | A stops accumulating at transition |
| A4 | A 30s → B 30s | About 30s each, no overlap inflation |
| A5 | A 30s → lock 30s → unlock/A 30s | About 60s A; locked interval excluded |
| A6 | A 20s → screen off 40s → wake/Home | About 20s A; screen-off interval excluded |
| A7 | A visible, untouched for 60s | Counts as foreground use; touch inactivity is not excluded |
| A8 | A 20s → shade open 20s → dismiss/A 20s | Record OEM event behavior; assess against foreground semantics, not assumption |
| A9 | Open `.dev`, note total, use A 60s, return; also return to an already selected historical date | Today refreshes; selected recent history reloads if repaired; no manual restart needed |

## 3. B — historical recovery (mandatory)

1. Without repeatedly opening `.dev`, use A for 60s and B for 30s; leave `.dev`
   backgrounded for at least one natural WorkManager execution (15 minutes is a
   minimum interval, **not** an execution deadline). Record worker logs and the
   current-day partial metadata/totals. A delayed worker is not itself a defect.
2. Open an available recent historical day that is partial/missing. Capture its
   stored totals, intervals and metadata before/after the recovery query. If
   trustworthy events are unavailable, expected result is **preserved data**,
   not a forced zero or false successful reconciliation.
3. Reopen that date, details, 7/14/30-day charts and reports immediately. Reconciled
   days should be skipped; unsuccessful attempts should back off for 15 minutes.
   A reconciled day may get a guarded recheck after six hours while still recent.
4. Restart the `.dev` process using a genuinely observed normal OS termination
   where practical; reopen and confirm history/status survives. If only an
   intentional force-stop is feasible, record it as a separate recovery test,
   **not** proof of normal OS process-death behavior.
5. Full overnight case: record a snapshot near 23:45, use A for a timed additional
   session before midnight, wait for a naturally delayed post-midnight worker,
   then compare yesterday/today and metadata. No clock changes or forced timing.
   If naturally obtaining this exact schedule is impractical, steps 1–4 are a
   partial device substitute only. **Full midnight behavior remains NOT VERIFIED.**

## 4. C — limits

Choose the smallest practical UI limit (currently 5 minutes), using an app with
less than that much usage today. Otherwise choose its existing usage plus about
five minutes, or another little-used app. Record the initial allowance. Do not
clear history or reset the clock to manufacture a fresh allowance.

1. Continuous use until threshold: actual block must appear and prevent ongoing
   target use. Measure block latency; an on-screen number alone is not a pass.
2. Home → target return; verify spent allowance is retained and block returns.
3. Another app → target return; same check.
4. Lock → unlock; no unintended allowance reset.
5. Force-stop **target app** via Settings, then relaunch; allowance stays spent.
6. Normal `.dev` process death/restart, if safely observable: record actual PID/
   service change and cause. `am kill` may not kill a foreground service; an
   unsuccessful kill does not establish recovery. Do not substitute `.dev`
   force-stop silently. Deliberate `.dev` force-stop/manual reopen is a distinct
   platform-stopped test and does not promise tamper resistance.
7. Use the reboot case below after recording a partial allowance. Verify actual
   next-day reset only across a real date boundary; otherwise leave it pending.

## 5. D — split screen

Try restricted A | unrestricted B, unrestricted A | restricted B, and both
restricted, in both launch/focus orders. If unsupported by an app, record N/A.
Use 30–60s phases and explicitly change touch focus without reopening activities.
Record which app accumulates, combined duration vs wall time, whether restricted
usage continues while visible, and whether the block prevents ongoing use.
The current policy is exclusive last-resumed attribution: combined totals should
not exceed wall time, but failing to enforce a visible restricted app is still a
P0 concern. Do not call touch focus equivalent to resume without event evidence.

## 6. E — PiP

For a supporting app, enter PiP, use B for 60s, then return. Record both deltas,
visibility/resume events and any restriction behavior. Repeat at a practical
limit threshold where supported. Document observed behavior even if PiP is later
defined as excluded. Unsupported PiP is N/A, not a passed enforcement test.

## 7. F — reboot and allowance recovery

With approximately 2 minutes used from a 5-minute allowance, capture totals,
remaining allowance, history and metadata. Reboot, unlock, continue the same app
for another minute, then inspect again. Expected: approximately 2 minutes remain,
prior usage/history survives, eligible service restarts, and blocking occurs at
the original daily threshold. Preserve exact timezone and date; any midnight
crossing must be evaluated as a separate next-day reset case.

## Exit decision

Update each case as DEVICE VERIFIED, FAILED or NOT YET VERIFIED with evidence.
Keep unexecuted midnight, OEM lifecycle, multi-window and PiP cases open. Do not
infer production readiness from the installed build, passing automated tests,
recovery log presence, or successful database migration alone.
