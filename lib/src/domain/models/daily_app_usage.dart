import 'app_usage_summary.dart';

class DailyAppUsage {
  const DailyAppUsage({required this.day, required this.summary});

  final DateTime day;
  final AppUsageSummary summary;
}

class UsageTrend {
  const UsageTrend({
    this.dayChangePercent,
    this.weekChangePercent,
    this.monthChangePercent,
  });

  final double? dayChangePercent;
  final double? weekChangePercent;
  final double? monthChangePercent;

  bool get hasData =>
      dayChangePercent != null ||
      weekChangePercent != null ||
      monthChangePercent != null;
}
