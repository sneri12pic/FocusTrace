# Health Connect integration: plan

Optional Android Health Connect integration. Decisions that were implemented
are in `health-connect-architecture.md`; current state is in
`health-connect-progress.md`.

## Scope (v1)

- Import exercise sessions (`ExerciseSessionRecord`) written by other apps,
  including Hevy, through Health Connect. Read-only.
- Off by default. A switch in Settings > Activity & data > Health Connect, and
  an optional onboarding step that uses the same view model and permission
  flow. Skipping or denying never blocks onboarding.
- Manual "Import now" and opt-in automatic import (periodic WorkManager job,
  needs Health Connect's background-read feature and permission).
- Status: last successful import, last outcome (with "no new workouts"
  distinct from failures), revoked-access and background-blocked warnings.
- A minimal list of imported workouts with their source app, and "Delete
  imported workouts".
- Required Play Console declarations and privacy policy text.

## Non-goals

- Writing anything to Health Connect. FocusTrace owns no health data (see
  "Export" below).
- Screen time, restrictions or blocking as health records. Health Connect is a
  health-data API; usage data is not health data.
- Exercise routes, heart rate, sets/reps or any other record type.
- Reading more than 30 days before the permission grant
  (`READ_HEALTH_DATA_HISTORY`).
- Sending health data through cloud sync, the portable backup, or Android Auto
  Backup. Changing that needs the owner's explicit approval.
- Goals, streaks, reminders or productivity scoring (see "Future phase").

## Export: unresolved

Export controls are not shipped. FocusTrace does not create workouts, steps,
sleep or any other record type Health Connect defines, so there is nothing
legitimate to export. Screen time is not a Health Connect data type and must
not be disguised as one (for example as an exercise or mindfulness session).

Open question for the owner: is there a FocusTrace-created activity you want
other apps to see in Health Connect? The only plausible candidate is a
**mindfulness session** (`MindfulnessSessionRecord`) for a deliberate focus
block the user starts, and only if the product gains such a feature that the
user explicitly logs. Until a use case like that is agreed, export stays out.

## Acceptance criteria (v1)

1. With the integration off (the default), FocusTrace makes no Health Connect
   calls apart from availability and permission status for the Settings screen,
   and no import work is scheduled.
2. Turning it on requests only `READ_EXERCISE`; turning on automatic import
   additionally requests `READ_HEALTH_DATA_IN_BACKGROUND`, only where the
   feature is available.
3. Turning it off stops reads at the next checkpoint, cancels the periodic job,
   keeps imported workouts and explains that the system permission and Health
   Connect data are unchanged.
4. Imports are idempotent by Health Connect record id; source edits update,
   source deletions remove, own-package records are skipped.
5. Revoked access, unavailable Health Connect and a missing background
   permission are shown as actionable states, never as "no new data".
6. Usage tracking, restrictions and blocking work identically with Health
   Connect missing, disabled or failing.

## Remaining work

- Device verification with a real Hevy workout (see progress).
- Play Console: complete the health apps declaration and Data safety answers
  in `docs/releases/PLAY_RELEASE.md` before the first release that ships this.
- Resolve the export question above.

## Optional future phase: workout goals (not started)

Do not start without the owner's explicit agreement.

- Users may set an optional weekly workout target (for example 3 sessions a
  week). Goals are off unless the user creates one.
- Progress comes automatically from imported sessions.
- Consistency streaks count weeks, not days, so planned rest days never break
  a streak.
- Stale or unavailable health data (Health Connect off, access revoked, the
  source app not synced yet) must never count as a missed goal; the week is
  shown as "unknown" instead.
- No reminders or productivity scoring as part of this phase.
