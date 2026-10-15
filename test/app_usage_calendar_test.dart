import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/widgets/trend_color.dart';
import 'package:focustrace/src/presentation/widgets/usage_calendar.dart';

const _appKey = 'com.zhiliaoapp.musically';

DailyAppUsage _usage(DateTime day, int minutes, {int launches = 0}) {
  return DailyAppUsage(
    day: day,
    summary: AppUsageSummary(
      appName: 'TikTok',
      packageName: _appKey,
      totalDurationSeconds: minutes * 60,
      percentageOfTotal: 0,
      launchCount: launches,
    ),
  );
}

AppUsageInterval _interval(DateTime start, int minutes, {String? appKey}) {
  return AppUsageInterval(
    id: '${start.millisecondsSinceEpoch}-${appKey ?? _appKey}',
    appKey: appKey ?? _appKey,
    appName: 'TikTok',
    startedAt: start,
    endedAt: start.add(Duration(minutes: minutes)),
  );
}

AppUsageDetailsRequest _request(DateTime day, {int minutes = 46}) {
  return AppUsageDetailsRequest(
    summary: AppUsageSummary(
      appName: 'TikTok',
      packageName: _appKey,
      totalDurationSeconds: minutes * 60,
      percentageOfTotal: 0,
      launchCount: 12,
    ),
    selectedDate: day,
    platform: UsagePlatform.android,
  );
}

void main() {
  test('heat buckets follow the legend boundaries', () {
    expect(usageHeatBucket(0), 0);
    expect(usageHeatBucket(29 * 60 + 59), 0);
    expect(usageHeatBucket(30 * 60), 1);
    expect(usageHeatBucket(60 * 60), 2);
    expect(usageHeatBucket(2 * 60 * 60), 3);
    expect(usageHeatBucket(3 * 60 * 60 - 1), 3);
    expect(usageHeatBucket(3 * 60 * 60), 4);
  });

  test(
    'loads the calendar month and compares with the same span last month',
    () async {
      final reports = _CalendarReportRepository()
        ..daily = [
          _usage(DateTime(2025, 3, 1), 42, launches: 5),
          _usage(DateTime(2025, 3, 16), 168, launches: 20),
          _usage(DateTime(2025, 3, 18), 10, launches: 1),
          _usage(DateTime(2025, 3, 2), 999).withKey('other.app'),
          _usage(DateTime(2025, 2, 5), 60, launches: 4),
          _usage(DateTime(2025, 2, 25), 600, launches: 50),
        ]
        ..intervals = [
          _interval(DateTime(2025, 3, 16, 9), 168),
          _interval(DateTime(2025, 3, 18, 23, 30), 60),
          _interval(DateTime(2025, 3, 10, 9), 500, appKey: 'other.app'),
          _interval(DateTime(2025, 2, 28, 9), 600),
        ];
      final viewModel = AppUsageCalendarViewModel(
        reportRepository: reports,
        request: _request(DateTime(2025, 3, 18)),
        clock: () => DateTime(2025, 3, 18, 12),
      );
      await viewModel.load();
      final state = viewModel.state;

      // March, February for the comparison, then January warmed in advance.
      expect(reports.ranges, [
        (DateTime(2025, 3), DateTime(2025, 4)),
        (DateTime(2025, 2), DateTime(2025, 3)),
        (DateTime(2025, 1), DateTime(2025, 2)),
      ]);
      expect(state.elapsedDays, 18);
      // The selected list row (46m, 12 opens) replaces the stored 10m.
      expect(state.dayUsage(DateTime(2025, 3, 18)).durationSeconds, 46 * 60);
      expect(state.monthTotal.durationSeconds, (42 + 168 + 46) * 60);
      expect(state.monthTotal.launchCount, 5 + 20 + 12);
      expect(state.averagePerDaySeconds, (42 + 168 + 46) * 60 ~/ 18);
      // Only February 1-18 is compared with March 1-18.
      expect(state.previousSameSpan.durationSeconds, 60 * 60);
      expect(state.previousSameSpan.launchCount, 4);
      expect(state.previousAveragePerDaySeconds, 660 * 60 ~/ 28);
      expect(state.longestInterval?.durationSeconds, 168 * 60);
      // February's interval belongs to February, not to March.
      expect(state.intervals, hasLength(2));
      expect(state.canShowNextMonth, isFalse);

      // An interval running past midnight is clipped to the selected day.
      final clipped = state.intervalsOn(DateTime(2025, 3, 18)).single;
      expect(clipped.endedAt, DateTime(2025, 3, 19));
      expect(
        state.intervalsOn(DateTime(2025, 3, 19)).single.durationSeconds,
        30 * 60,
      );
      viewModel.dispose();
    },
  );

  test('revisited and warmed months load without fetching again', () async {
    final reports = _CalendarReportRepository();
    final viewModel = AppUsageCalendarViewModel(
      reportRepository: reports,
      request: _request(DateTime(2025, 3, 18)),
      clock: () => DateTime(2025, 3, 18),
    );
    await viewModel.load();
    await Future<void>.delayed(Duration.zero);
    final fetched = reports.ranges.length;
    // February and January are already loaded, so the step back is instant.
    final back = viewModel.showPreviousMonth();
    expect(viewModel.state.month, DateTime(2025, 2));
    expect(viewModel.state.isLoading, isFalse);
    await back;
    await viewModel.showNextMonth();
    expect(viewModel.state.month, DateTime(2025, 3));
    // Only December was warmed; nothing already loaded was fetched again.
    await Future<void>.delayed(Duration.zero);
    expect(reports.ranges.skip(fetched), [
      (DateTime(2024, 12), DateTime(2025, 1)),
    ]);
    viewModel.dispose();
  });

  test('a slower earlier month cannot overwrite the latest month', () async {
    final reports = _CalendarReportRepository();
    final viewModel = AppUsageCalendarViewModel(
      reportRepository: reports,
      request: _request(DateTime(2025, 3, 18)),
      clock: () => DateTime(2025, 3, 18),
    );
    await viewModel.load();
    final slow = Completer<UsageReportSourceData>();
    reports.pending = slow.future;
    final older = viewModel.load(month: DateTime(2024, 6));
    reports.pending = null;
    await viewModel.showNextMonth(); // Disabled: March is the current month.
    await viewModel.load(month: DateTime(2025, 1));
    slow.complete(
      const UsageReportSourceData(
        dailyUsage: [],
        intervals: [],
        restrictionEvents: [],
      ),
    );
    await older;
    expect(viewModel.state.month, DateTime(2025, 1));
    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.canShowNextMonth, isTrue);
    viewModel.dispose();
  });

  testWidgets('calendar shades days and reports the tapped day', (
    tester,
  ) async {
    final reports = _CalendarReportRepository()
      ..daily = [_usage(DateTime(2025, 3, 4), 200)];
    final viewModel = AppUsageCalendarViewModel(
      reportRepository: reports,
      request: _request(DateTime(2025, 3, 18)),
      clock: () => DateTime(2025, 3, 18),
    );
    await viewModel.load();
    DateTime? tapped;
    Future<void> pump({required bool isGood}) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                UsageCalendar(
                  state: viewModel.state,
                  isGood: isGood,
                  onPreviousMonth: () {},
                  onNextMonth: () {},
                  onDaySelected: (day) => tapped = day,
                ),
                UsageDayPanel(
                  state: viewModel.state,
                  day: DateTime(2025, 3, 4),
                  isGood: isGood,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Color cellColor() => tester
        .widget<Material>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('usage-calendar-day-4')),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    await pump(isGood: false);
    expect(find.text('March 2025'), findsOneWidget);
    final theme = ThemeData(brightness: Brightness.dark);
    expect(cellColor(), usageHeatColor(theme, 4, isGood: false));
    await tester.tap(find.byKey(const ValueKey('usage-calendar-day-4')));
    expect(tapped, DateTime(2025, 3, 4));
    expect(find.text('No session details for this day'), findsOneWidget);

    await pump(isGood: true);
    expect(cellColor(), usageHeatColor(theme, 4, isGood: true));
    expect(
      usageHeatColor(theme, 4, isGood: true),
      isNot(usageHeatColor(theme, 4, isGood: false)),
    );
    viewModel.dispose();
  });

  testWidgets('switching months keeps every section the same height', (
    tester,
  ) async {
    // March 2025 needs five grid rows, has usage, sessions and a previous
    // month; June 2024 needs six rows and has nothing at all.
    final reports = _CalendarReportRepository()
      ..daily = [
        _usage(DateTime(2025, 2, 5), 60),
        _usage(DateTime(2025, 3, 4), 200, launches: 3),
      ]
      ..intervals = [_interval(DateTime(2025, 3, 18, 9), 30)];
    final viewModel = AppUsageCalendarViewModel(
      reportRepository: reports,
      request: _request(DateTime(2025, 3, 18)),
      clock: () => DateTime(2025, 3, 18),
    );
    await viewModel.load();

    Future<List<Size>> sizes() async {
      final state = viewModel.state;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  UsageMonthStats(state: state, isGood: false),
                  UsageCalendar(
                    state: state,
                    isGood: false,
                    onPreviousMonth: () {},
                    onNextMonth: () {},
                    onDaySelected: (_) {},
                  ),
                  UsageDayPanel(
                    state: state,
                    day: state.selectedDay!,
                    isGood: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return [
        for (final key in const [
          'usage-month-stats',
          'usage-calendar',
          'usage-day-panel',
        ])
          tester.getSize(find.byKey(ValueKey(key))),
      ];
    }

    final march = await sizes();
    await viewModel.load(month: DateTime(2024, 6));
    // The selected day follows into the shown month.
    expect(viewModel.state.selectedDay, DateTime(2024, 6, 18));
    expect(await sizes(), march);
    viewModel.dispose();
  });
}

extension on DailyAppUsage {
  DailyAppUsage withKey(String key) => DailyAppUsage(
    day: day,
    summary: summary.copyWith(packageName: key),
  );
}

class _CalendarReportRepository implements ReportRepository {
  List<DailyAppUsage> daily = [];
  List<AppUsageInterval> intervals = [];
  Future<UsageReportSourceData>? pending;
  final ranges = <(DateTime, DateTime)>[];

  @override
  Future<UsageReportSourceData> loadSourceData(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) {
    ranges.add((fromInclusive, toExclusive));
    return pending ??
        Future.value(
          UsageReportSourceData(
            dailyUsage: [
              for (final entry in daily)
                if (!entry.day.isBefore(fromInclusive) &&
                    entry.day.isBefore(toExclusive))
                  entry,
            ],
            intervals: intervals,
            restrictionEvents: const [],
          ),
        );
  }

  @override
  Future<void> recordRestrictionEvent(RestrictionEvent event) async {}
}
