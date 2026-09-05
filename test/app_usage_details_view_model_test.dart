import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test(
    'chart choice survives repository recreation and period changes',
    () async {
      final storage = _SettingsDataSource();
      final repository = _DetailsUsageRepository();
      final first = _details(repository, SettingsRepositoryImpl(storage));
      await first.load();
      expect(first.state.chart, UsageDetailsChart.bars);
      expect(await first.selectChart(UsageDetailsChart.area), isTrue);
      await first.selectPeriod(UsageDetailsPeriod.month);
      expect(first.state.chart, UsageDetailsChart.area);
      first.dispose();

      final reopened = _details(repository, SettingsRepositoryImpl(storage));
      await reopened.load();
      expect(reopened.state.chart, UsageDetailsChart.area);
      expect(reopened.state.points, hasLength(7));
      reopened.dispose();
    },
  );

  test(
    'unknown chart setting and unavailable preferences keep usage usable',
    () async {
      final storage = _SettingsDataSource()
        ..values['usage_details_chart'] = 'future_chart';
      final settings = SettingsRepositoryImpl(storage);
      expect(await settings.usageDetailsChart(), UsageDetailsChart.bars);
      storage.fail = true;
      final viewModel = _details(_DetailsUsageRepository(), settings);
      await viewModel.load();
      expect(viewModel.state.points, hasLength(7));
      expect(viewModel.state.errorMessage, isNull);
      expect(await viewModel.selectChart(UsageDetailsChart.area), isFalse);
      expect(viewModel.state.chart, UsageDetailsChart.area);
      storage.fail = false;
      expect(await viewModel.selectChart(UsageDetailsChart.bars), isTrue);
      expect(await settings.usageDetailsChart(), UsageDetailsChart.bars);
      viewModel.dispose();
    },
  );

  test(
    'a slower earlier period cannot overwrite the latest period or chart',
    () async {
      final repository = _DetailsUsageRepository();
      final viewModel = _details(repository, _DetailsSettingsRepository());
      await viewModel.load();
      final slowHistory = Completer<List<DailyAppUsage>>();
      repository.historyOverride = slowHistory.future;
      final oldLoad = viewModel.selectPeriod(UsageDetailsPeriod.month);
      repository.historyOverride = null;
      await viewModel.selectPeriod(UsageDetailsPeriod.year);
      await viewModel.selectChart(UsageDetailsChart.area);
      slowHistory.complete([]);
      await oldLoad;
      expect(viewModel.state.period, UsageDetailsPeriod.year);
      expect(viewModel.state.points, hasLength(12));
      expect(viewModel.state.chart, UsageDetailsChart.area);
      viewModel.dispose();
    },
  );

  test(
    'rapid chart choices persist the final choice after a slow write',
    () async {
      final storage = _SettingsDataSource()..writeGate = Completer<void>();
      final settings = SettingsRepositoryImpl(storage);
      final viewModel = _details(_DetailsUsageRepository(), settings);
      await viewModel.load();
      final first = viewModel.selectChart(UsageDetailsChart.area);
      final last = viewModel.selectChart(UsageDetailsChart.bars);
      expect(viewModel.state.chart, UsageDetailsChart.bars);
      storage.writeGate!.complete();
      await Future.wait([first, last]);
      expect(await settings.usageDetailsChart(), UsageDetailsChart.bars);
      viewModel.dispose();
    },
  );

  test(
    'fills a seven-day series and compares selected day with yesterday',
    () async {
      final selectedDate = DateTime(2026, 7, 19);
      final repository = _DetailsUsageRepository()
        ..history = [
          _usage(selectedDate.subtract(const Duration(days: 1)), 600),
          _usage(selectedDate.subtract(const Duration(days: 3)), 300),
        ]
        ..sessions = [
          UsageSession(
            id: 'session',
            platform: UsagePlatform.windows,
            appName: 'Example',
            processName: 'example.exe',
            startedAt: selectedDate,
            endedAt: selectedDate.add(const Duration(minutes: 5)),
            durationSeconds: 300,
            createdAt: selectedDate,
          ),
        ];
      final viewModel = AppUsageDetailsViewModel(
        usageRepository: repository,
        settingsRepository: _DetailsSettingsRepository(),
        request: AppUsageDetailsRequest(
          summary: const AppUsageSummary(
            appName: 'Example',
            processName: 'example.exe',
            totalDurationSeconds: 900,
            percentageOfTotal: 1,
          ),
          selectedDate: selectedDate,
          platform: UsagePlatform.windows,
        ),
      );

      await viewModel.load();

      expect(viewModel.state.points, hasLength(7));
      expect(viewModel.state.points.first.durationSeconds, 0);
      expect(viewModel.state.points.last.durationSeconds, 900);
      expect(viewModel.state.period, UsageDetailsPeriod.sevenDays);
      expect(viewModel.state.totalDurationSeconds, 1800);
      expect(viewModel.state.changeFromYesterdayPercent, 50);
      expect(viewModel.state.sessions.single.id, 'session');
      expect(repository.requestedAppKey, 'example.exe');
      expect(repository.requestedFrom, DateTime(2026, 7, 13));
      expect(repository.requestedTo, DateTime(2026, 7, 20));
    },
  );

  test(
    'loads twelve monthly totals when the year period is selected',
    () async {
      final selectedDate = DateTime(2026, 8, 16);
      final repository = _DetailsUsageRepository()
        ..history = [
          for (var monthOffset = 0; monthOffset < 12; monthOffset++)
            _usage(DateTime(2025, 9 + monthOffset, 2), 60),
        ];
      final viewModel = AppUsageDetailsViewModel(
        usageRepository: repository,
        settingsRepository: _DetailsSettingsRepository(),
        request: AppUsageDetailsRequest(
          summary: const AppUsageSummary(
            appName: 'Example',
            processName: 'example.exe',
            totalDurationSeconds: 120,
            percentageOfTotal: 1,
          ),
          selectedDate: selectedDate,
          platform: UsagePlatform.android,
        ),
      );

      await viewModel.selectPeriod(UsageDetailsPeriod.year);

      expect(viewModel.state.period, UsageDetailsPeriod.year);
      expect(viewModel.state.points, hasLength(12));
      expect(viewModel.state.points.first.day, DateTime(2025, 9));
      expect(viewModel.state.points.last.day, DateTime(2026, 8));
      expect(viewModel.state.points.last.durationSeconds, 180);
      expect(viewModel.state.totalDurationSeconds, 840);
      expect(repository.requestedFrom, DateTime(2025, 9));
      expect(repository.requestedTo, DateTime(2026, 8, 17));
    },
  );
}

DailyAppUsage _usage(DateTime day, int seconds) {
  return DailyAppUsage(
    day: day,
    summary: AppUsageSummary(
      appName: 'Example',
      processName: 'example.exe',
      totalDurationSeconds: seconds,
      percentageOfTotal: 0,
    ),
  );
}

class _DetailsUsageRepository implements UsageRepository {
  Future<List<DailyAppUsage>>? historyOverride;
  List<DailyAppUsage> history = const [];
  List<UsageSession> sessions = const [];
  String? requestedAppKey;
  DateTime? requestedFrom;
  DateTime? requestedTo;

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    requestedFrom = fromInclusive;
    requestedTo = toExclusive;
    return historyOverride ?? history;
  }

  @override
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  }) async {
    requestedAppKey = appKey;
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppUsageDetailsViewModel _details(
  UsageRepository usage,
  SettingsRepository settings,
) {
  return AppUsageDetailsViewModel(
    usageRepository: usage,
    settingsRepository: settings,
    request: AppUsageDetailsRequest(
      summary: const AppUsageSummary(
        appName: 'Example',
        processName: 'example.exe',
        totalDurationSeconds: 120,
        percentageOfTotal: 1,
      ),
      selectedDate: DateTime(2026, 9, 5),
      platform: UsagePlatform.android,
    ),
  );
}

class _DetailsSettingsRepository implements SettingsRepository {
  @override
  Future<UsageDetailsChart> usageDetailsChart() async => UsageDetailsChart.bars;

  @override
  Future<void> setUsageDetailsChart(UsageDetailsChart chart) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SettingsDataSource implements FocusTraceLocalDataSource {
  final values = <String, String>{};
  bool fail = false;
  Completer<void>? writeGate;

  @override
  Future<String?> readSetting(String key) async {
    if (fail) throw StateError('Storage unavailable');
    return values[key];
  }

  @override
  Future<void> writeSetting(String key, String value) async {
    if (fail) throw StateError('Storage unavailable');
    await writeGate?.future;
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
