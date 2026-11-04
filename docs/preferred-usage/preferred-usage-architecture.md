# Preferred usage time — architecture

## Storage and sync

`PreferredLimit` (`lib/src/domain/models/preferred_limit.dart`) is stored as JSON
under the SQLite settings key `preferred_limits`, so export/import and clear data
already cover it. `RestrictionsViewModel` owns the state.

Only Dart can classify apps, so every `_sync` expands limits with
`preferredLimitsForBlocker` and sends them in the existing restriction JSON as
`preferredLimits: [{limitMinutes, apps}]`. Sharing that JSON means the blocker
start conditions, boot restart and per-tick reload work without new channels.
Changing an app's category resyncs. The installed-app list is read once per
launch, so a newly installed app joins its category limit on the next launch.
A failure here sends no soft limits and never stops rules or routines syncing.

Preferred limits are not `RestrictionRule`s: they skip `RestrictionChangeGuard`,
can be edited at any time, and never appear in `blockReasons`.

## Setting a time

`showPreferredMinutesSheet` is a bottom sheet, shared by onboarding and Settings,
with `CupertinoTimerPicker` wheels at one-minute precision (up to 23h 59m) and
presets for 15m, 30m, 1h and 2h. The picker comes from the Flutter SDK, so no
dependency was added. Stored minutes were already plain integers, so existing
limits and native code are unchanged. A limit of zero cannot be saved.

## Nudge

A permanent outline was tried first and replaced: it was too loud and easy to
tune out. The nudge is transient instead: a soft edge glow plus a time label,
held 3 seconds. Amber near the limit, red once reached. The label shows the
minutes left, then the minutes over the limit.

`BlockerService.tick` computes `RestrictionConfiguration.preferredNudge` only for
an open, unblocked app, and `NudgeSchedule` decides whether it is due: on crossing
90%, on reaching the limit, on every reopen, and every 5 minutes. Away means 3
seconds or more, so an in-app screen change is not a reopen. Leaving the app removes a visible nudge at once. A category
limit counts all its apps together.

The nudge is a touch-through full-screen window. Its opacity is fixed on
`WindowManager.LayoutParams.alpha`, and fading happens on the view, because
Android 12+ drops touches under an overlay window more opaque than 0.8.

The nudge needs the overlay and usage access permissions, like blocking. A user
with only preferred limits still gets the blocker's foreground notification.

Accessibility permission is deliberately not used here: it is too strong for
this feature.
