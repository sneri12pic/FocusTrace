import '../../domain/models/app_usage_interval.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/models/restriction_event.dart';
import '../../domain/models/usage_report.dart';

class ReportGenerationService {
  const ReportGenerationService();

  static const wakeInactivity = Duration(hours: 4);
  static const firstUseStartHour = 4;
  static const firstUseEndHour = 14;

  UsageReport generate({
    required UsageReportPeriod period,
    required DateTime now,
    required List<DailyAppUsage> dailyUsage,
    required List<AppUsageInterval> intervals,
    required List<RestrictionEvent> restrictionEvents,
  }) {
    final from = period.startDate(now);
    final to = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final usageInRange = dailyUsage
        .where((entry) => !entry.day.isBefore(from) && entry.day.isBefore(to))
        .toList();
    final totalSeconds = usageInRange.fold<int>(
      0,
      (total, entry) => total + entry.summary.totalDurationSeconds,
    );
    final activeDayKeys = usageInRange
        .where((entry) => entry.summary.totalDurationSeconds > 0)
        .map((entry) => _dayKey(entry.day))
        .toSet();
    final firstUses = _firstUseSamples(
      intervals: intervals,
      fromInclusive: from,
      toExclusive: to,
    );
    final averageFirstUseMinute = firstUses.isEmpty
        ? null
        : firstUses
                  .map(
                    (sample) => sample.usedAt.hour * 60 + sample.usedAt.minute,
                  )
                  .reduce((first, second) => first + second) ~/
              firstUses.length;

    return UsageReport(
      period: period,
      fromInclusive: from,
      toExclusive: to,
      totalDurationSeconds: totalSeconds,
      averageDailyDurationSeconds: activeDayKeys.isEmpty
          ? 0
          : totalSeconds ~/ activeDayKeys.length,
      activeDays: activeDayKeys.length,
      hourlyDurationSeconds: _hourlyDurations(
        intervals,
        fromInclusive: from,
        toExclusive: to,
      ),
      topApps: _topApps(usageInRange),
      firstUseSamples: firstUses,
      averageFirstUseMinute: averageFirstUseMinute,
      firstUseVariationMinutes: averageFirstUseMinute == null
          ? null
          : firstUses
                    .map(
                      (sample) =>
                          ((sample.usedAt.hour * 60 + sample.usedAt.minute) -
                                  averageFirstUseMinute)
                              .abs(),
                    )
                    .fold<int>(0, (total, value) => total + value) ~/
                firstUses.length,
      mostCommonFirstAppName: _mostCommonFirstApp(firstUses),
      restrictionEvents:
          restrictionEvents
              .where(
                (event) =>
                    !event.occurredAt.isBefore(from) &&
                    event.occurredAt.isBefore(to),
              )
              .toList()
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
    );
  }

  List<int> _hourlyDurations(
    List<AppUsageInterval> intervals, {
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    final totals = List<int>.filled(24, 0);
    for (final interval in intervals) {
      var cursor = interval.startedAt.isBefore(fromInclusive)
          ? fromInclusive
          : interval.startedAt;
      final end = interval.endedAt.isAfter(toExclusive)
          ? toExclusive
          : interval.endedAt;
      while (cursor.isBefore(end)) {
        final nextHour = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
          cursor.hour + 1,
        );
        final segmentEnd = nextHour.isBefore(end) ? nextHour : end;
        totals[cursor.hour] += segmentEnd.difference(cursor).inSeconds;
        cursor = segmentEnd;
      }
    }
    return totals;
  }

  List<FirstUseSample> _firstUseSamples({
    required List<AppUsageInterval> intervals,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    final sorted =
        intervals.where((interval) => interval.durationSeconds > 0).toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final samples = <FirstUseSample>[];
    for (
      var day = fromInclusive;
      day.isBefore(toExclusive);
      day = day.add(const Duration(days: 1))
    ) {
      final earliest = DateTime(
        day.year,
        day.month,
        day.day,
        firstUseStartHour,
      );
      final latest = DateTime(day.year, day.month, day.day, firstUseEndHour);
      final candidates = sorted.where(
        (interval) =>
            !interval.startedAt.isBefore(earliest) &&
            interval.startedAt.isBefore(latest),
      );
      for (final candidate in candidates) {
        AppUsageInterval? previous;
        for (final interval in sorted) {
          if (interval.endedAt.isAfter(candidate.startedAt)) {
            break;
          }
          previous = interval;
        }
        if (previous != null &&
            candidate.startedAt.difference(previous.endedAt) < wakeInactivity) {
          continue;
        }
        samples.add(
          FirstUseSample(
            day: day,
            appKey: candidate.appKey,
            appName: candidate.appName,
            usedAt: candidate.startedAt,
          ),
        );
        break;
      }
    }
    return samples;
  }

  List<AppUsageSummary> _topApps(List<DailyAppUsage> usage) {
    final totals = <String, int>{};
    final latest = <String, AppUsageSummary>{};
    for (final entry in usage) {
      final summary = entry.summary;
      totals.update(
        summary.appKey,
        (value) => value + summary.totalDurationSeconds,
        ifAbsent: () => summary.totalDurationSeconds,
      );
      latest[summary.appKey] = summary;
    }
    final grandTotal = totals.values.fold<int>(0, (sum, value) => sum + value);
    final result =
        [
          for (final entry in totals.entries)
            latest[entry.key]!.copyWith(
              totalDurationSeconds: entry.value,
              percentageOfTotal: grandTotal == 0 ? 0 : entry.value / grandTotal,
            ),
        ]..sort(
          (first, second) =>
              second.totalDurationSeconds.compareTo(first.totalDurationSeconds),
        );
    return result.take(5).toList();
  }

  String? _mostCommonFirstApp(List<FirstUseSample> samples) {
    if (samples.isEmpty) {
      return null;
    }
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final sample in samples) {
      counts.update(sample.appKey, (value) => value + 1, ifAbsent: () => 1);
      names[sample.appKey] = sample.appName;
    }
    final key = counts.entries.reduce((first, second) {
      if (second.value > first.value) {
        return second;
      }
      return first;
    }).key;
    return names[key];
  }

  String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';
}
