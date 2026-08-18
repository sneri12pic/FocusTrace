import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  const service = ReportGenerationService();
  final now = DateTime(2026, 8, 19, 12);

  test('generates weekly totals, hourly habits, and restriction counts', () {
    final report = service.generate(
      period: UsageReportPeriod.weekly,
      now: now,
      dailyUsage: [
        _daily(DateTime(2026, 8, 17), 'social', 'Social', 3600),
        _daily(DateTime(2026, 8, 17), 'video', 'Video', 1800),
        _daily(DateTime(2026, 8, 18), 'social', 'Social', 5400),
      ],
      intervals: [
        _interval('late', 'Reader', DateTime(2026, 8, 16, 22, 30), 30),
        _interval('social', 'Social', DateTime(2026, 8, 17, 7, 10), 20),
        _interval('video', 'Video', DateTime(2026, 8, 17, 8, 30), 60),
        _interval('night', 'Night', DateTime(2026, 8, 18, 3), 10),
        _interval('social', 'Social', DateTime(2026, 8, 18, 8), 30),
      ],
      restrictionEvents: [
        RestrictionEvent(
          id: 'blocked-1',
          appKey: 'social',
          appName: 'Social',
          type: RestrictionEventType.blocked,
          occurredAt: DateTime(2026, 8, 18, 9),
        ),
        RestrictionEvent(
          id: 'unblocked-1',
          appKey: 'social',
          appName: 'Social',
          type: RestrictionEventType.unblocked,
          occurredAt: DateTime(2026, 8, 18, 9, 5),
        ),
      ],
    );

    expect(report.fromInclusive, DateTime(2026, 8, 17));
    expect(report.totalDurationSeconds, 10800);
    expect(report.activeDays, 2);
    expect(report.averageDailyDurationSeconds, 5400);
    expect(report.topApps.first.appName, 'Social');
    expect(report.topApps.first.totalDurationSeconds, 9000);
    expect(report.hourlyDurationSeconds[8], 3600);
    expect(report.hourlyDurationSeconds[9], 1800);
    expect(report.peakUsageHour, 8);
    expect(report.firstUseSamples, hasLength(2));
    expect(report.averageFirstUseMinute, 455);
    expect(report.mostCommonFirstAppName, 'Social');
    expect(report.blockedCount, 1);
    expect(report.unblockedCount, 1);
  });

  test('first-use inference excludes 00:00 to 04:00 and short gaps', () {
    final report = service.generate(
      period: UsageReportPeriod.weekly,
      now: now,
      dailyUsage: const [],
      intervals: [
        _interval('night', 'Night', DateTime(2026, 8, 17, 3, 30), 20),
        _interval('early', 'Early', DateTime(2026, 8, 17, 5), 10),
        _interval('wake', 'Wake', DateTime(2026, 8, 17, 9, 30), 10),
      ],
      restrictionEvents: const [],
    );

    expect(report.firstUseSamples.single.appName, 'Wake');
    expect(report.averageFirstUseMinute, 570);
  });
}

DailyAppUsage _daily(DateTime day, String appKey, String appName, int seconds) {
  return DailyAppUsage(
    day: day,
    summary: AppUsageSummary(
      appName: appName,
      packageName: appKey,
      totalDurationSeconds: seconds,
      percentageOfTotal: 0,
    ),
  );
}

AppUsageInterval _interval(
  String appKey,
  String appName,
  DateTime startedAt,
  int minutes,
) {
  return AppUsageInterval(
    id: '$appKey:${startedAt.millisecondsSinceEpoch}',
    appKey: appKey,
    appName: appName,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(minutes: minutes)),
  );
}
