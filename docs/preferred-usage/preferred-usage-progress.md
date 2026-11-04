# Preferred usage time — progress

Date: 2026-11-01
Agent: Claude
Goal: finer time options than 15 minute steps, and a better editor.

Completed: replaced the slider dialog with a bottom sheet: large time readout,
quick presets and hour and minute wheels at one-minute precision.
Files materially changed: `preferred_limits_editor.dart`, new
`test/preferred_minutes_sheet_test.dart`.
Decisions made: see the architecture document, "Setting a time".
Remaining: device check of the sheet and the wheels.
Relevant commit: none yet.

Date: 2026-10-30
Agent: Claude
Goal: replace the permanent outline with a brief, calmer nudge.

Completed: edge glow and time label, `NudgeSchedule`, native strings for all
seven languages, tests.
Files materially changed: `BlockerService.kt`, `RestrictionRules.kt`, `res/values*/strings.xml`.
Decisions made: see the architecture document; no accessibility permission.
Remaining: device check of the nudge.
Relevant commit: none yet.

Date: 2026-10-30
Agent: Claude
Goal: preferred usage time per category or app, with a red outline and no blocking.

Completed: model and storage, native outline, onboarding page, Settings screen,
translations for all seven languages, tests.
Files materially changed: `preferred_limit.dart`, `restrictions_view_model.dart`,
`preferred_limits_editor.dart`, `onboarding_screen.dart`, `settings_screen.dart`,
`BlockerService.kt`, `RestrictionRules.kt`.
Verification: `flutter analyze` no issues; `flutter test` all passed;
`gradlew :app:testDebugUnitTest` for restriction tests passed.
Decisions made: close threshold is 90%; new onboarding page sits before the
existing "Choose what to limit" page, which still creates blocking daily limits.
Remaining: device check of the outline.
Risks / unresolved questions: the two onboarding pages overlap in purpose.
Relevant commit: none yet.
