import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
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
    return history;
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
