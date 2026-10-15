import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _app = 'com.zhiliaoapp.musically';

OsUsageBucket _daily(DateTime day, int minutes, {String appKey = _app}) {
  // Android's daily buckets need not start at local midnight.
  final start = day.add(const Duration(hours: 2));
  return OsUsageBucket(
    interval: OsUsageInterval.daily,
    start: start,
    end: start.add(const Duration(days: 1)),
    appKey: appKey,
    appName: 'TikTok',
    durationSeconds: minutes * 60,
  );
}

OsUsageBucket _monthly(DateTime month, int minutes) => OsUsageBucket(
  interval: OsUsageInterval.monthly,
  start: month,
  end: DateTime(month.year, month.month + 1),
  appKey: _app,
  appName: 'TikTok',
  durationSeconds: minutes * 60,
);

DailyAppUsage _recorded(DateTime day, int minutes, {String appKey = _app}) =>
    DailyAppUsage(
      day: day,
      summary: AppUsageSummary(
        appName: appKey,
        packageName: appKey,
        totalDurationSeconds: minutes * 60,
        percentageOfTotal: 0,
      ),
    );

void main() {
  late Directory tempDir;
  late SqfliteFocusTraceLocalDataSource local;
  late _OsPlatform platform;
  late OsUsageHistoryRepository history;

  setUp(() async {
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('os_history_test');
    local = SqfliteFocusTraceLocalDataSource(
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => tempDir,
    );
    platform = _OsPlatform();
    history = OsUsageHistoryRepository(
      localDataSource: local,
      platformDataSource: platform,
    );
  });

  tearDown(() async {
    await local.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'imports once, keeps buckets Android has dropped, clears with data',
    () async {
      platform.buckets = [
        _daily(DateTime(2025, 3, 10), 30),
        _monthly(DateTime(2024, 11), 900),
      ];
      expect(await history.importOnce(), DateTime(2024, 11));
      platform.buckets = [_daily(DateTime(2025, 3, 10), 45)];
      // Memoized for the app run, so the refreshed value is not read yet.
      expect(await history.importOnce(), DateTime(2024, 11));
      expect(platform.calls, 1);

      await OsUsageHistoryRepository(
        localDataSource: local,
        platformDataSource: platform,
      ).importOnce();
      // The day refreshed in place; November survives though Android dropped it.
      expect(
        await history.dailySeconds(_app, DateTime(2025, 3), DateTime(2025, 4)),
        {DateTime(2025, 3, 10): 45 * 60},
      );
      expect(
        await history.monthlySeconds(
          _app,
          DateTime(2024, 1),
          DateTime(2025, 1),
        ),
        {DateTime(2024, 11): 900 * 60},
      );
      // Backups never carry approximate history.
      expect(
        (await local.exportPortableData()).keys,
        isNot(contains('os_usage_buckets')),
      );

      await local.clearAllData();
      expect(
        await history.dailySeconds(_app, DateTime(2025, 3), DateTime(2025, 4)),
        isEmpty,
      );
    },
  );

  test('nothing found retries on the next call', () async {
    expect(await history.importOnce(), isNull);
    platform.buckets = [_daily(DateTime(2025, 3, 10), 30)];
    expect(await history.importOnce(), DateTime(2025, 3, 10));
  });

  test('details fill only unrecorded days and empty months', () async {
    platform.buckets = [
      // Unrecorded: becomes an approximate point.
      _daily(DateTime(2025, 3, 12), 40),
      // Recorded (another app has a row): this app really was at zero.
      _daily(DateTime(2025, 3, 13), 50),
      _monthly(DateTime(2024, 10), 600),
      // March has daily data, so its monthly total is never used.
      _monthly(DateTime(2025, 3), 9999),
    ];
    final usage = _HistoryUsage([
      _recorded(DateTime(2025, 3, 13), 20, appKey: 'other.app'),
    ]);
    final request = AppUsageDetailsRequest(
      summary: const AppUsageSummary(
        appName: 'TikTok',
        packageName: _app,
        totalDurationSeconds: 600,
        percentageOfTotal: 0,
      ),
      selectedDate: DateTime(2025, 3, 15),
      platform: UsagePlatform.android,
    );
    final viewModel = AppUsageDetailsViewModel(
      usageRepository: usage,
      settingsRepository: _ChartSettings(),
      request: request,
      osHistory: history,
    );
    await viewModel.load();
    final week = {
      for (final point in viewModel.state.points) point.day.day: point,
    };
    expect(week[12]!.durationSeconds, 40 * 60);
    expect(week[12]!.isApproximate, isTrue);
    expect(week[13]!.durationSeconds, 0);
    expect(week[13]!.isApproximate, isFalse);
    expect(week[15]!.isApproximate, isFalse);
    expect(viewModel.state.hasApproximate, isTrue);

    await viewModel.selectPeriod(UsageDetailsPeriod.year);
    final months = {
      for (final point in viewModel.state.points)
        DateTime(point.day.year, point.day.month): point,
    };
    expect(months[DateTime(2024, 10)]!.durationSeconds, 600 * 60);
    expect(months[DateTime(2024, 10)]!.isApproximate, isTrue);
    expect(months[DateTime(2025, 3)]!.durationSeconds, (40 + 10) * 60);
    expect(months[DateTime(2025, 3)]!.isApproximate, isTrue);
    expect(months[DateTime(2024, 12)]!.isApproximate, isFalse);
    viewModel.dispose();
  });

  test(
    'calendar marks approximate days and falls back to month totals',
    () async {
      platform.buckets = [
        _daily(DateTime(2025, 3, 12), 40),
        _monthly(DateTime(2025, 2), 2800),
      ];
      final viewModel = AppUsageCalendarViewModel(
        reportRepository: _HistoryReports([
          _recorded(DateTime(2025, 3, 13), 20, appKey: 'other.app'),
        ]),
        request: AppUsageDetailsRequest(
          summary: const AppUsageSummary(
            appName: 'TikTok',
            packageName: _app,
            totalDurationSeconds: 600,
            percentageOfTotal: 0,
            launchCount: 3,
          ),
          selectedDate: DateTime(2025, 3, 15),
          platform: UsagePlatform.android,
        ),
        osHistory: history,
        clock: () => DateTime(2025, 3, 15),
      );
      await viewModel.load();
      var state = viewModel.state;
      expect(state.isApproximateDay(DateTime(2025, 3, 12)), isTrue);
      expect(state.dayUsage(DateTime(2025, 3, 12)).durationSeconds, 40 * 60);
      expect(state.isApproximateDay(DateTime(2025, 3, 15)), isFalse);
      expect(state.isMonthApproximate, isTrue);
      // February is known only as Android's monthly total, prorated to 15 days.
      expect(state.hasPreviousMonth, isTrue);
      expect(state.previousSameSpan.durationSeconds, 2800 * 60 * 15 ~/ 28);

      await viewModel.showPreviousMonth();
      state = viewModel.state;
      expect(state.days, isEmpty);
      expect(state.monthTotal.durationSeconds, 2800 * 60);
      expect(state.isMonthApproximate, isTrue);
      viewModel.dispose();
    },
  );
}

class _OsPlatform implements PlatformUsageDataSource, OsUsageHistoryDataSource {
  List<OsUsageBucket> buckets = [];
  int calls = 0;

  @override
  Future<List<OsUsageBucket>> getOsUsageHistory() async {
    calls++;
    return buckets;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoryUsage implements UsageRepository {
  _HistoryUsage(this.history);

  final List<DailyAppUsage> history;

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => history;

  @override
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoryReports implements ReportRepository {
  _HistoryReports(this.daily);

  final List<DailyAppUsage> daily;

  @override
  Future<UsageReportSourceData> loadSourceData(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => UsageReportSourceData(
    dailyUsage: [
      for (final entry in daily)
        if (!entry.day.isBefore(fromInclusive) &&
            entry.day.isBefore(toExclusive))
          entry,
    ],
    intervals: const [],
    restrictionEvents: const [],
  );

  @override
  Future<void> recordRestrictionEvent(RestrictionEvent event) async {}
}

class _ChartSettings implements SettingsRepository {
  @override
  Future<UsageDetailsChart> usageDetailsChart() async => UsageDetailsChart.bars;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
