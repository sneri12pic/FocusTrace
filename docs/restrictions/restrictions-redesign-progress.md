# Restrictions redesign - progress

Date: 2026-10-16
Agent: Claude Code
Goal: Finish the "App first" Restrictions redesign that Codex started (it stopped at its usage limit), matching the two mockups in `.local/design/restrictions-app-first/`.
Completed:
- Reviewed Codex's uncommitted overview, setup sheet, rule model, Easy/Moderate/Hard enforcement and tests, and kept all of it.
- Moved the native `requestRestrictionChange` and `syncRestrictions` handlers off the main thread, because validating a changed daily limit reads today's usage (about 1 s cold). The read-check-write of the native rules is now serialized with a lock.
- Brought the visuals closer to the mockups:
  - Most-used rows show the name and time on one line with the bar below, and "+ Limit" / "Edit" are tonal buttons.
  - Hour labels are compact ("6 PM", or "18" on a 24-hour clock), and the action arrow sits after the label.
  - Restriction rows read "1h / day · Easy" on the left, with the live status on the right: "12m left today", "Blocked until …" in red, or "Starts Fri 9:00 PM". The limit bar stays underneath without a duplicate label.
  - In the setup sheet, the duration shows large numbers with small units, the comparison with the user's average has a green down arrow and is centred, unselected type tiles use the muted colour, and the protection note has an info icon.
- Added strings `rxPerDay`, `rxUntil`, `rxLeftToday` and `rxStarts` to all seven ARBs, and fixed three analyzer infos.
Files materially changed: `MainActivity.kt`, `restrictions_screen.dart`, `restriction_setup_form.dart`, `restriction_discovery.dart`, `restriction_rule.dart`, `lib/l10n/*`, `test/restriction_redesign_test.dart`, `test/restrictions_view_model_test.dart`.
Verification: PASS `dart format --set-exit-if-changed lib test`; PASS `flutter analyze`; PASS `flutter test`; PASS `gradlew :app:testDebugUnitTest` (RestrictionChangeGuardTest 5/5); PASS `flutter build apk --profile --target-platform android-arm64`. Visuals were checked by rendering the overview and the setup sheet with sample data at 412 and 360 dp widths.
Decisions made: kept the delete button on each restriction row (the mockup shows only a chevron) because the editor has no delete action. Kept the generic "Plan a block for these hours" label, since the detected window is not always the evening.
Remaining: physical-device checks listed in the plan (TalkBack, real icons, cooldown across process death or reboot, revoked permissions while blocking, OEM overlay behaviour). Grouped routines still have no difficulty setting, as planned.
Risks / unresolved questions: native and SQLite stores are reconciled, not written atomically (see architecture). Cooldowns use wall-clock time.
Relevant commit: none. Uncommitted as requested.

---

Date: 2026-10-23
Agent: Claude Code
Goal: Refine the overview and setup popup to the extended overview mockup and the earlier setup mockup, keeping the dark palette and all enforcement semantics.
Completed:
- Overview order is now permissions/errors, "Your restrictions" (count badge, one Add), "Choose apps to limit", "Your busiest hours", block routines. The app-bar search icon and the separate "Add restriction" button were removed; Add and "Search all apps" open the same all-app picker (search autofocuses the filter).
- Rule cards follow the mockup: icon, name, "Daily limit · 1h 30m" / "Schedule · 9:00 PM – 7:00 AM" with weekdays / "Block now · Until …", progress with used and left time, status line, difficulty tag. Edit, unblock and delete moved to an overflow menu. Hard rules that are blocking show "Locked until …" and no unblock or delete; Moderate shows "Unblock after 5-minute wait" with a specific confirmation.
- "Choose apps to limit": compact Today / This week tabs, "Today's usage so far" versus "Daily average · N recorded days", three compact rows with "+ Limit" or "Edit".
- Busiest hours is a compact card with the peak window as the headline, highlighted bars, six-hour labels and "Plan a schedule".
- Routines show app names, "Shared daily limit · …", Paused tag, switch, and used/left progress when enabled.
- Popup: one header with Close, compact type selector, duration with minus/plus, "Edit duration" (hours + minutes fields, no drag handles) and presets, schedule tiles and weekday circles, compact difficulty selector with one explanation panel, "Save changes" when editing. Large text stacks selectors and lets the header scroll.
- New strings in all seven ARBs; `rxPlanBlock` now reads "Plan a schedule".
Files materially changed: `restrictions_screen.dart`, `restriction_discovery.dart`, `restriction_setup_form.dart`, `restriction_editor_sheet.dart` (optional confirmation body), `lib/l10n/*`, `test/widget_test.dart`, `test/restriction_redesign_test.dart`.
Verification: PASS `dart format --set-exit-if-changed lib test`; PASS `flutter analyze`; PASS `flutter test` (346, 1 skipped), including a new editor test for difficulty explanations, presets and "Save changes". Renders of the overview with sample rules and routines and of all three editor modes were inspected at 360 and 412 dp and at 200% text. ADB now starts (the earlier "failed to create fdevent interrupt socketpair" error did not recur). The .dev profile build was installed over the existing .dev app with `adb install -r` (data kept) and checked on the SM-A366B: overview, scrolling, search across installed apps, all three popup modes and keyboard entry in Edit duration. Nothing was saved on the device. The first build reused a stale cache; `flutter clean` fixed it. Native code was not changed, so the Kotlin unit tests were not rerun.
Remaining: see the plan's Remaining section.
Relevant commit: none. Uncommitted as requested.

---

Date: 2026-10-23
Agent: Claude Code
Goal: Finish the routines experience: last-app removal, a better app picker, a name prompt, per-app caps inside the shared allowance, combined blocking with specific reasons, and app details from the routine screen.
Completed:
- Model: `RoutineApp.limitMinutes` (optional, additive JSON); `BlockRoutine.fromJson` keeps empty routines (disabled); `isSharedAllowanceReached` / `isAppCapReached` mirror native rules.
- Native: `RoutineMember.limitMinutes`, `RoutineLimit.isAppCapReached`, `RestrictionConfiguration.blockReasons` (all active reasons across rules and overlapping routines); `BlockerService` lists every reason on the block screen with the latest end time and records the first as the event reason. Capped apps are included in the usage query. New Android strings in all seven locales.
- Routine details: Keep / Delete dialog for the last app (dismiss keeps), empty-routine message, multi-select "Add apps", per-app limit chip with a remove option, active block reasons per app, icon and name open the existing usage details screen while the switch, limit chip and remove button stay separate.
- `RoutineAppPicker` used by the editor and "Add apps"; editor shows the warm "Add routine name" hint once apps are selected and the name is blank.
- Fixed screen-reader tap actions lost under `excludeSemantics` in the picker rows, routine app rows and setup-form weekday toggles.
Verification: PASS `dart format --set-exit-if-changed lib test`; PASS `flutter analyze`; PASS `flutter test` (354, 1 skipped; new `routine_experience_test.dart`, updated `block_routine_test.dart` and `routine_editor_sheet_test.dart`); PASS `gradlew :app:testDebugUnitTest` (142, including new cap, overlap and legacy tests). Device (SM-A366B, .dev, `adb install -r` after `flutter clean`): created a throwaway routine without a shared limit, checked category select and partial state, the name prompt, app details navigation and back, setting an app limit, Keep (empty routine survived a force-stop and relaunch), adding an app back, and Delete. The user's existing routine was not touched and the throwaway routine was deleted.
Remaining: see the plan. A real on-device block from a per-app cap or a used-up shared allowance was not triggered, to avoid blocking the user's apps.
Relevant commit: none. Uncommitted as requested.
