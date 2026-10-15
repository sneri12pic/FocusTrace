# Earlier usage history import - progress

Date: 2026-10-15
Agent: Claude Code
Goal: Pull usage from before installation, mark it approximate, and mention it in onboarding (requested by the user).
Completed: native reader, `os_usage_buckets` table, `OsUsageHistoryRepository`, approximate fill in the app detail chart (7 days to a year) and in the calendar (days, month stats, comparison), "≈" markers and a note, and the onboarding line saying how far back history goes.
Files materially changed: `OsUsageHistory.kt`, `MainActivity.kt`, `platform_usage_data_source.dart`, `focus_trace_local_data_source.dart`, `os_usage_history_repository.dart`, `os_usage_bucket.dart`, `app_usage_details_view_model.dart`, `app_usage_calendar_view_model.dart`, `usage_details_charts.dart`, `usage_calendar.dart`, `usage_details_screen.dart`, `onboarding_screen.dart`, `providers.dart`, `lib/l10n/*`, `test/os_usage_history_test.dart`, and stubs in two test fakes.
Verification: PASS `flutter analyze`; PASS `flutter test`; PASS `dart format --set-exit-if-changed lib test`; PASS `flutter build apk --profile --target-platform android-arm64`.
Decisions made: see the architecture document (daily and monthly buckets only, recorded data always wins, device-local, no version bump).
Remaining: on-device check of how much history the Samsung phone retains NOT RUN.
Risks / unresolved questions: OEM bucket boundaries may put a daily bucket on a neighbouring local day. That is acceptable for values marked approximate.
Relevant commit: see the branch history.
