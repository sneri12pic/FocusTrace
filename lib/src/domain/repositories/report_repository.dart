import '../models/app_usage_interval.dart';
import '../models/daily_app_usage.dart';
import '../models/restriction_event.dart';

class UsageReportSourceData {
  const UsageReportSourceData({
    required this.dailyUsage,
    required this.intervals,
    required this.restrictionEvents,
  });

  final List<DailyAppUsage> dailyUsage;
  final List<AppUsageInterval> intervals;
  final List<RestrictionEvent> restrictionEvents;
}

abstract class ReportRepository {
  Future<UsageReportSourceData> loadSourceData(
    DateTime fromInclusive,
    DateTime toExclusive,
  );

  Future<void> recordRestrictionEvent(RestrictionEvent event);
}
