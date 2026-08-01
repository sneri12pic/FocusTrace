import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test('calculates rolling day, week, and month changes per app', () {
    const service = UsageTrendService();
    final throughDay = DateTime(2026, 7, 19);
    final history = [
      _usage(throughDay, 150),
      _usage(throughDay.subtract(const Duration(days: 1)), 100),
      _usage(throughDay.subtract(const Duration(days: 7)), 500),
      _usage(throughDay.subtract(const Duration(days: 30)), 500),
    ];

    final trend = service.calculate(
      history: history,
      throughDay: throughDay,
      appKeys: const ['example.app'],
    )['example.app']!;

    expect(trend.dayChangePercent, 50);
    expect(trend.weekChangePercent, -50);
    expect(trend.monthChangePercent, 50);
  });

  test('shows no trend for first-seen usage or empty apps', () {
    const service = UsageTrendService();
    final throughDay = DateTime(2026, 7, 19);

    final trends = service.calculate(
      history: [_usage(throughDay, 60)],
      throughDay: throughDay,
      appKeys: const ['example.app', 'empty.app'],
    );

    // No prior-window usage means no badge instead of a misleading +100%.
    expect(trends['example.app']!.hasData, isFalse);
    expect(trends['empty.app']!.hasData, isFalse);
  });
}

DailyAppUsage _usage(DateTime day, int seconds) {
  return DailyAppUsage(
    day: day,
    summary: AppUsageSummary(
      appName: 'Example',
      packageName: 'example.app',
      totalDurationSeconds: seconds,
      percentageOfTotal: 0,
    ),
  );
}
