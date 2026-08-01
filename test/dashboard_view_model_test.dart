import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test(
    'past Android history remains available without current usage access',
    () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final repository = _DashboardUsageRepository(hasUsageAccess: false)
        ..dailyResult = const [
          AppUsageSummary(
            appName: 'Yesterday app',
            packageName: 'example.yesterday',
            totalDurationSeconds: 600,
            percentageOfTotal: 1,
          ),
        ]
        ..allTimeResult = const [
          AppUsageSummary(
            appName: 'All-time leader',
            packageName: 'example.leader',
            totalDurationSeconds: 3600,
            percentageOfTotal: 1,
          ),
        ]
        ..historyResult = [
          DailyAppUsage(
            day: yesterday,
            summary: const AppUsageSummary(
              appName: 'Yesterday app',
              packageName: 'example.yesterday',
              totalDurationSeconds: 600,
              percentageOfTotal: 0,
            ),
          ),
          DailyAppUsage(
            day: yesterday.subtract(const Duration(days: 1)),
            summary: const AppUsageSummary(
              appName: 'Yesterday app',
              packageName: 'example.yesterday',
              totalDurationSeconds: 400,
              percentageOfTotal: 0,
            ),
          ),
        ];
      final viewModel = DashboardViewModel(
        usageRepository: repository,
        settingsRepository: _DashboardSettingsRepository(),
        platform: UsagePlatform.android,
      );

      await viewModel.previousDay();

      expect(viewModel.state.dayOffset, -1);
      expect(viewModel.state.hasUsageAccess, isFalse);
      expect(viewModel.state.summaries.single.appName, 'Yesterday app');
      expect(viewModel.state.allTimeTopApps.first.appName, 'All-time leader');
      expect(
        viewModel.state.trendsByAppKey['example.yesterday']?.dayChangePercent,
        50,
      );
    },
  );

  test('a slower day load cannot overwrite the latest selected day', () async {
    final firstResult = Completer<List<AppUsageSummary>>();
    final repository = _DashboardUsageRepository()
      ..dailyResults = [
        firstResult.future,
        Future.value(const [
          AppUsageSummary(
            appName: 'Latest selection',
            packageName: 'example.latest',
            totalDurationSeconds: 300,
            percentageOfTotal: 1,
          ),
        ]),
      ];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.windows,
    );

    final slowerLoad = viewModel.previousDay();
    await Future<void>.delayed(Duration.zero);
    await viewModel.previousDay();
    firstResult.complete(const [
      AppUsageSummary(
        appName: 'Stale selection',
        packageName: 'example.stale',
        totalDurationSeconds: 900,
        percentageOfTotal: 1,
      ),
    ]);
    await slowerLoad;

    expect(viewModel.state.dayOffset, -2);
    expect(viewModel.state.summaries.single.appName, 'Latest selection');
  });
}

class _DashboardUsageRepository implements UsageRepository {
  _DashboardUsageRepository({bool hasUsageAccess = true})
    : _hasUsageAccess = hasUsageAccess;

  final bool _hasUsageAccess;
  List<AppUsageSummary> dailyResult = const [];
  List<AppUsageSummary> allTimeResult = const [];
  List<DailyAppUsage> historyResult = const [];
  List<Future<List<AppUsageSummary>>> dailyResults = const [];
  int _dailyCallCount = 0;

  @override
  Future<bool> hasUsageAccess() async => _hasUsageAccess;

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) {
    if (_dailyCallCount < dailyResults.length) {
      return dailyResults[_dailyCallCount++];
    }
    return Future.value(dailyResult);
  }

  @override
  Future<List<AppUsageSummary>> getTodaySummaries() async => const [];

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() async => allTimeResult;

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => historyResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DashboardSettingsRepository implements SettingsRepository {
  @override
  Future<List<String>> excludedApps() async => const [];

  @override
  Future<Set<String>> hiddenAppsForToday() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
