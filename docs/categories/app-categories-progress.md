# App categories — progress

Date: 2026-10-11
Agent: Claude Code
Goal: Redesign the category tags (user asked to "redesign the tags").
Completed: one shared `CategoryPill` (tinted stadium, category icon plus name)
now renders list-row labels (compact), the details tag (with edit icon, 48dp
touch target, button semantics); filter chips use the same icons. Filter `ChoiceChip`s
are stadium-shaped with a category-tinted selected state and no checkmark.
Picker rows show the category icon. `CategoryDot` removed. Colors unchanged.
Files materially changed: `app_category_widgets.dart`, `usage_bubble_screen.dart`,
`test/widget_test.dart` (tag assertions read `CategoryPill.category`).
Verification: PASS `flutter analyze --no-pub`; PASS `flutter test --no-pub` (325,
1 skipped live-backend test); PASS `dart format --set-exit-if-changed` on the 3
files; PASS `git diff --check`. A temporary widget test (deleted) put all six
pills on a 360x640 dark screen at 1x and 2x text: Android tap-target, labelled
tap-target and text-contrast guidelines PASS.
Decisions made: icons are Material outlined icons; no new dependency.
Remaining: on-device visual check; filter chips not probed separately.
Risks / unresolved questions: none known.
Relevant commit: None; uncommitted as requested.

Date: 2026-10-07
Agent: Claude Code
Goal: Re-verify the uncommitted category stage without a phone.
Completed: re-ran tests and checks below; reviewed the widgets. A temporary
widget test (deleted afterwards) put the details tag and picker on a 360x640
dark screen at 1x and 2x text: Android tap-target, labelled tap-target and text
contrast guidelines PASS, the tag exposes "Entertainment" with tooltip "App
category" as a button, and Save is reachable after scrolling. Dashboard filter
chips are stock `ChoiceChip`s and were not probed separately. Review notes, not
fixed: a failed save shows error text that is not a live region, so TalkBack may
not announce it; the Save spinner has no semantic label.
Verification: `flutter test` of `data_transfer`, `widget`, `arb_key_parity`,
`usage_bubble_view_model` PASS (19); full `flutter test` PASS (296, one
live-backend skip); `flutter analyze` PASS; `dart format --set-exit-if-changed`
on lib/test PASS; `git diff --check` PASS. Clean release AAB contains the
category strings (backend progress, 2026-10-07).
Remaining: physical visual, touch and TalkBack validation NOT RUN (protocol
case 6 in `docs/backend/backend-sync-v1-plan.md`).
Relevant commit: none; still uncommitted.

---

Date: 2026-10-05
Agent: Codex
Goal: Implement issue #28 category tags and filtering without redesigning the app.

Completed:
- Dashboard represented-category filters and compact dots/labels.
- Colored details tag and scrollable picker with Automatic/reset and save errors.
- Shared resolution/state, durable app-key overrides, import/clear refresh.
- Seven-locale messages and regression coverage for today/history, failed writes,
  unchanged usage/restrictions, restart, reset, malformed data, and backup/import.

Files materially changed:
- Domain category resolver and settings repository contract/implementation.
- Shared category ViewModel/provider and category widgets.
- Usage bubble ViewModel/screen, summary tile, details screen, settings screen.
- Localization ARBs/generated output; widget/data-transfer tests and settings fakes.
- `docs/categories/app-categories-{plan,architecture,progress}.md`.

Verification:
- PASS: `flutter gen-l10n`.
- PASS: `flutter test --no-pub test/data_transfer_test.dart test/widget_test.dart
  test/arb_key_parity_test.dart test/usage_bubble_view_model_test.dart` — 19 tests.
- PASS: `flutter test --no-pub` — 296 tests; 1 existing live-backend sync test
  skipped because `FOCUSTRACE_SYNC_BASE_URL` was not configured.
- PASS: `flutter analyze --no-pub` — no issues.
- PASS: `dart format --output=none --set-exit-if-changed` on changed Dart files
  and the two new Dart files — 24 files, 0 changes.
- PASS: `git diff --check`.

Decisions made: Reuse local settings JSON and the existing six categories;
filters are presentation-only; no tracking schema, dependency, or backend changes.
Remaining: Physical-device visual/accessibility validation; no install performed.
Risks / unresolved questions: Automatic labels retain the existing app-name
heuristic; users can correct them. No physical-device behavior claim is made.
Relevant commit: None; changes remain uncommitted as requested.
