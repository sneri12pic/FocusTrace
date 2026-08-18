import 'app_usage_summary.dart';
import 'restriction_event.dart';

enum UsageReportPeriod {
  weekly,
  monthly,
  yearly;

  DateTime startDate(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return switch (this) {
      UsageReportPeriod.weekly => day.subtract(
        Duration(days: day.weekday - DateTime.monday),
      ),
      UsageReportPeriod.monthly => DateTime(day.year, day.month),
      UsageReportPeriod.yearly => DateTime(day.year),
    };
  }
}

class FirstUseSample {
  const FirstUseSample({
    required this.day,
    required this.appKey,
    required this.appName,
    required this.usedAt,
  });

  final DateTime day;
  final String appKey;
  final String appName;
  final DateTime usedAt;
}

class UsageReport {
  const UsageReport({
    required this.period,
    required this.fromInclusive,
    required this.toExclusive,
    required this.totalDurationSeconds,
    required this.averageDailyDurationSeconds,
    required this.activeDays,
    required this.hourlyDurationSeconds,
    required this.topApps,
    required this.firstUseSamples,
    required this.averageFirstUseMinute,
    required this.firstUseVariationMinutes,
    required this.mostCommonFirstAppName,
    required this.restrictionEvents,
  });

  final UsageReportPeriod period;
  final DateTime fromInclusive;
  final DateTime toExclusive;
  final int totalDurationSeconds;
  final int averageDailyDurationSeconds;
  final int activeDays;
  final List<int> hourlyDurationSeconds;
  final List<AppUsageSummary> topApps;
  final List<FirstUseSample> firstUseSamples;
  final int? averageFirstUseMinute;
  final int? firstUseVariationMinutes;
  final String? mostCommonFirstAppName;
  final List<RestrictionEvent> restrictionEvents;

  bool get isEmpty =>
      totalDurationSeconds == 0 &&
      firstUseSamples.isEmpty &&
      restrictionEvents.isEmpty;

  int? get peakUsageHour {
    var peakHour = -1;
    var peakSeconds = 0;
    for (var hour = 4; hour < hourlyDurationSeconds.length; hour++) {
      final seconds = hourlyDurationSeconds[hour];
      if (seconds > peakSeconds) {
        peakSeconds = seconds;
        peakHour = hour;
      }
    }
    return peakHour < 0 ? null : peakHour;
  }

  int get blockedCount => restrictionEvents
      .where((event) => event.type == RestrictionEventType.blocked)
      .length;

  int get unblockedCount => restrictionEvents
      .where((event) => event.type == RestrictionEventType.unblocked)
      .length;
}
