import 'dart:math' as math;
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

    await pump(isGood: true);
    expect(cellColor(), usageHeatColor(theme, 4, isGood: true));
    expect(
      usageHeatColor(theme, 4, isGood: true),
      isNot(usageHeatColor(theme, 4, isGood: false)),
    );
    viewModel.dispose();
  });

  testWidgets('swiping the calendar changes month', (tester) async {
    final viewModel = AppUsageCalendarViewModel(
      reportRepository: _CalendarReportRepository(),
      request: _request(DateTime(2025, 3, 18)),
      clock: () => DateTime(2025, 3, 18),
    );
    await viewModel.load();
    var previous = 0, next = 0;
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: UsageCalendar(
              state: viewModel.state,
              isGood: false,
              onPreviousMonth: () => previous++,
              onNextMonth: () => next++,
              onDaySelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await pump();
    final grid = find.byKey(const ValueKey('usage-calendar-swipe'));
    await tester.fling(grid, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(previous, 1);
    // The current month has no next month, so a left swipe does nothing.
    await tester.fling(grid, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(next, 0);
    viewModel.dispose();
  });

  testWidgets('timeline shows exact times of the stretch touched', (
    tester,
  ) async {
    final day = DateTime(2025, 3, 4);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 480,
            child: UsageDayTimeline(
              day: day,
              intervals: [
                _interval(day.add(const Duration(hours: 12)), 10),
                _interval(day.add(const Duration(hours: 12, minutes: 20)), 5),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Tap or drag for exact times · hold to restrict a time frame'),
      findsOne,
    );
    expect(find.text('15m'), findsOne); // the day's total in the centre
    final dial = tester.getRect(
      find.byKey(const ValueKey('usage-day-timeline')),
    );
    // 12:22 on a 24-hour dial (midnight at the top, clockwise), on the ring.
    final angle = -math.pi / 2 + (12 * 60 + 22) / 1440 * 2 * math.pi;
    final radius = dial.shortestSide / 2 - 45;
    await tester.tapAt(
      dial.center + Offset(math.cos(angle), math.sin(angle)) * radius,
    );
    await tester.pump();
    // The second of two close sessions, with its exact times.
    expect(find.text('12:20 – 12:25'), findsOne);
    expect(find.text('5m'), findsOne);
  });

  testWidgets(
    'hold picks a time frame, drag moves its end, restrict reports it',
    (tester) async {
      final day = DateTime(2025, 3, 4);
      (int, int)? restricted;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: UsageDayTimeline(
                  day: day,
                  intervals: [
                    _interval(
                      day.add(const Duration(hours: 12, minutes: 41)),
                      57,
                    ),
                  ],
                  onRestrictRange: (start, end) => restricted = (start, end),
                ),
              ),
            ),
          ),
        ),
      );
      final dial = tester.getRect(
        find.byKey(const ValueKey('usage-day-timeline')),
      );
      Offset at(int minute) {
        final angle = -math.pi / 2 + minute / 1440 * 2 * math.pi;
        return dial.center +
            Offset(math.cos(angle), math.sin(angle)) *
                (dial.shortestSide / 2 - 45);
      }

      // Holding on the session picks its quarter-hours: 12:30 to 13:45.
      await tester.longPressAt(at(13 * 60));
      await tester.pumpAndSettle();
      expect(find.text('12:30 – 13:45'), findsOne);
      expect(find.text('Restrict this time frame?'), findsOne);
      // Tapping 15:10 moves the end to 15:15.
      await tester.tapAt(at(15 * 60 + 10));
      await tester.pump();
      expect(find.text('12:30 – 15:15'), findsOne);
      await tester.tap(find.text('Restrict'));
      await tester.pump();
      expect(restricted, (12 * 60 + 30, 15 * 60 + 15));
      expect(find.text('Restrict this time frame?'), findsNothing);
    },
  );

  testWidgets('schedule dial moves the nearer end, snapping to quarter-hours', (
    tester,
  ) async {
    var range = (21 * 60, 7 * 60);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ScheduleRangeDial(
              startMinute: range.$1,
              endMinute: range.$2,
              onChanged: (start, end) => setState(() => range = (start, end)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('21:00 – 07:00'), findsOne);
    expect(find.text('Ends the next day'), findsOne);
    final dial = tester.getRect(
      find.byKey(const ValueKey('schedule-range-dial')),
    );
    Offset at(int minute) {
      final angle = -math.pi / 2 + minute / 1440 * 2 * math.pi;
      return dial.center +
          Offset(math.cos(angle), math.sin(angle)) *
              (dial.shortestSide / 2 - 45);
    }

    // 08:10 is nearer the end (07:00): it snaps to 08:15.
    await tester.tapAt(at(8 * 60 + 10));
    await tester.pump();
    expect(range, (21 * 60, 8 * 60 + 15));
    // 19:50 is nearer the start: it snaps to 19:45.
    await tester.tapAt(at(19 * 60 + 50));
    await tester.pump();
    expect(range, (19 * 60 + 45, 8 * 60 + 15));
    expect(find.text('19:45 – 08:15'), findsOne);
  });

  testWidgets('scrolling over the dial or tapping away from sessions selects '
      'nothing', (tester) async {
    final day = DateTime(2025, 3, 4);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: [
              UsageDayTimeline(
                day: day,
                intervals: [_interval(day.add(const Duration(hours: 12)), 10)],
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    final dial = tester.getRect(
      find.byKey(const ValueKey('usage-day-timeline')),
    );
    Offset at(int minute) {
      final angle = -math.pi / 2 + minute / 1440 * 2 * math.pi;
      return dial.center +
          Offset(math.cos(angle), math.sin(angle)) *
              (dial.shortestSide / 2 - 45);
    }

    final selection = find.byKey(
      const ValueKey('usage-day-timeline-selection'),
    );
    // A scroll that starts on the session scrolls, it does not select.
    await tester.dragFrom(at(12 * 60 + 5), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(selection, findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    // The middle of the dial and empty parts of the ring select nothing.
    await tester.tapAt(dial.center);
    await tester.tapAt(at(18 * 60));
    await tester.pump();
    expect(selection, findsNothing);
    // A tap on the session does.
    await tester.tapAt(at(12 * 60 + 5));
    await tester.pump();
    expect(selection, findsOne);
  });

  test('quarter-hour slots split sessions by clock time', () {
    final day = DateTime(2025, 3, 4);
    final slots = usageBySlot(day, [
      _interval(day.add(const Duration(hours: 12, minutes: 10)), 10),
      // Runs past midnight: only today's part counts.
      _interval(day.add(const Duration(hours: 23, minutes: 50)), 20),
    ]);
    expect(slots[48], 5 * 60); // 12:00-12:15
    expect(slots[49], 5 * 60); // 12:15-12:30
    expect(slots[95], 10 * 60); // 23:45-24:00
    expect(slots.reduce((a, b) => a + b), 20 * 60);
  });

  testWidgets('month stats add today in green', (tester) async {
    final reports = _CalendarReportRepository()
      ..daily = [
        _usage(DateTime(2025, 3, 4), 60, launches: 3),
        // Today's figures come from the live summary (46m, 12 opens).
        _usage(DateTime(2025, 3, 18), 30, launches: 5),
      ];
    final viewModel = AppUsageCalendarViewModel(
      reportRepository: reports,
      request: _request(DateTime(2025, 3, 18)),
      clock: () => DateTime(2025, 3, 18, 15),
    );
    await viewModel.load();
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: UsageMonthStats(state: viewModel.state, isGood: false),
        ),
      ),
    );
    await pump();
    expect(find.textContaining('+46m', findRichText: true), findsOne);
    expect(find.textContaining('+12', findRichText: true), findsOne);
    // A past month has no "today" to add.
    await viewModel.load(month: DateTime(2025, 2));
    await pump();
    expect(find.textContaining('+', findRichText: true), findsNothing);
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
                  KeyedSubtree(
                    key: const ValueKey('usage-day-dial'),
                    child: UsageDayTimeline(
                      day: state.selectedDay!,
                      intervals: state.intervalsOn(state.selectedDay!),
                      emptyLabel: 'No sessions',
                    ),
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
          'usage-day-dial',
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
