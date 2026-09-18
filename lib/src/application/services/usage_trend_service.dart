import '../../domain/models/daily_app_usage.dart';

class UsageTrendService {
  const UsageTrendService();

  Map<String, UsageTrend> calculate({
    required Iterable<DailyAppUsage> history,
    required DateTime throughDay,
    required Iterable<String> appKeys,
  }) {
    final normalizedThroughDay = _normalizedUtcDay(throughDay);
    final totalsByAge = <int, Map<String, int>>{};
    // Oldest day with any recorded usage, across all apps. A previous window
    // reaching past it is only partly covered, and its total would be a
    // deflated denominator rather than a baseline.
    // ponytail: coverage inferred from usage rows; a fully idle day at the very
    // edge reads as uncovered. Use usage_snapshot_days if that ever matters.
    var oldestAge = -1;

    for (final entry in history) {
      final age = normalizedThroughDay
          .difference(_normalizedUtcDay(entry.day))
          .inDays;
      if (age < 0 || age >= 60) {
        continue;
      }
      if (age > oldestAge) {
        oldestAge = age;
      }
      final totals = totalsByAge.putIfAbsent(age, () => <String, int>{});
      totals.update(
        entry.summary.appKey,
        (total) => total + entry.summary.totalDurationSeconds,
        ifAbsent: () => entry.summary.totalDurationSeconds,
      );
    }

    return {
      for (final appKey in appKeys)
        appKey: UsageTrend(
          day: _changeForWindow(totalsByAge, oldestAge, appKey, windowDays: 1),
          week: _changeForWindow(totalsByAge, oldestAge, appKey, windowDays: 7),
          month: _changeForWindow(
            totalsByAge,
            oldestAge,
            appKey,
            windowDays: 30,
          ),
        ),
    };
  }

  UsageTrendChange _changeForWindow(
    Map<int, Map<String, int>> totalsByAge,
    int oldestAge,
    String appKey, {
    required int windowDays,
  }) {
    var current = 0;
    var previous = 0;
    for (final entry in totalsByAge.entries) {
      final value = entry.value[appKey] ?? 0;
      if (entry.key < windowDays) {
        current += value;
      } else if (entry.key < windowDays * 2) {
        previous += value;
      }
    }

    return UsageTrendChange.compare(
      currentSeconds: current,
      previousSeconds: previous,
      previousWindowCovered: oldestAge >= windowDays * 2 - 1,
    );
  }

  DateTime _normalizedUtcDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
