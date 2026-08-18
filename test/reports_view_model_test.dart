import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

class _FakeReportRepository implements ReportRepository {
  final requests = <(DateTime, DateTime)>[];

  @override
  Future<UsageReportSourceData> loadSourceData(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    requests.add((fromInclusive, toExclusive));
    return UsageReportSourceData(
      dailyUsage: [
        DailyAppUsage(
          day: DateTime(2026, 8, 18),
          summary: const AppUsageSummary(
            appName: 'Reader',
            packageName: 'reader',
            totalDurationSeconds: 1200,
            percentageOfTotal: 1,
          ),
        ),
      ],
      intervals: const [],
      restrictionEvents: const [],
    );
  }

  @override
  Future<void> recordRestrictionEvent(RestrictionEvent event) async {}
}

void main() {
  test('loads weekly report and reloads for monthly selection', () async {
    final repository = _FakeReportRepository();
    final viewModel = ReportsViewModel(
      repository: repository,
      now: () => DateTime(2026, 8, 19, 12),
    );

    await viewModel.load();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.report?.totalDurationSeconds, 1200);
    expect(repository.requests.first.$1, DateTime(2026, 8, 17));

    await viewModel.selectPeriod(UsageReportPeriod.monthly);

    expect(viewModel.state.period, UsageReportPeriod.monthly);
    expect(repository.requests.last.$1, DateTime(2026, 8));
  });
}
