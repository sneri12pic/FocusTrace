# Restrictions redesign — plan

## Scope and acceptance

- [x] Adopt the selected app-first overview and full-height setup sheet using the
  existing dark theme, backgrounds and blue ColorScheme. No global theme change.
- [x] Today / This week usage, top-three app actions, an all-app picker, real
  hourly usage and an editable schedule suggestion. Missing days are excluded
  from averages; insufficient interval evidence does not produce a suggestion.
- [x] Daily limit, immediate block and weekday schedule editors; direct duration
  entry; app metadata, average comparison, and Easy / Moderate / Hard choices.
- [x] Persist weekdays and difficulty compatibly; enforce active-rule changes
  natively, including editing, deleting, changing type and early unblocking.
- [x] Preserve category groups, limit progress, routines, permissions and navigation.
- [x] Seven-locale copy, focused model/widget/native tests, regression checks.
- [x] Refinement (2026-10-23, extended overview mockup): restrictions first with
  count and one Add; mockup-style rule cards with an overflow menu that never
  offers a refused unblock; "Choose apps to limit" with Today / This week tabs
  and one search route to all apps; compact busiest-hours card; routines with
  paused state and shared-limit progress; compact popup with one header,
  presets, "Edit duration", a compact difficulty selector with one explanation
  and "Save changes" when editing.

- [x] Routines (2026-10-23): last-app removal asks Keep / Delete and keeps
  empty routines; shared picker with round marks, category selection with
  partial state, most-used-first ordering; warm "Add routine name" prompt;
  optional per-app caps inside the shared allowance, enforced natively; every
  active block reason shown; app details from the routine screen.

## Non-goals

Backend changes, system-level tamper or uninstall prevention, changes to the
existing grouped-routine model, cloud dependency, commits and publishing.

## Remaining

Physical Android device validation: TalkBack, permissions revoked while
blocking, five-minute cooldown across actual process death/reboot, OEM overlay
behavior, and the rule-card menu for actively blocking Easy, Moderate and Hard
rules (not exercised on the device so the user's real restrictions stayed
untouched). Large system font sizes were checked in renders only. Routine
app caps, shared-allowance exhaustion and multi-reason block screens were
verified by native and Flutter tests only; they still need a real block on the
device. Per-app caps have no five-minute warning notification yet (the shared
allowance does). Automated tests do not replace these checks.

See [architecture](restrictions-redesign-architecture.md) and
[progress](restrictions-redesign-progress.md) for implemented semantics and evidence.
