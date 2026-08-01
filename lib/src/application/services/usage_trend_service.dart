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

    for (final entry in history) {
      final age = normalizedThroughDay
          .difference(_normalizedUtcDay(entry.day))
          .inDays;
      if (age < 0 || age >= 60) {
        continue;
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
          dayChangePercent: _changeForWindow(
            totalsByAge,
            appKey,
            windowDays: 1,
          ),
          weekChangePercent: _changeForWindow(
            totalsByAge,
            appKey,
            windowDays: 7,
          ),
          monthChangePercent: _changeForWindow(
            totalsByAge,
            appKey,
            windowDays: 30,
          ),
        ),
    };
  }

  double? _changeForWindow(
    Map<int, Map<String, int>> totalsByAge,
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

    // No prior-window usage means there is nothing to compare against, so a
    // first-seen app shows no badge instead of a misleading +100%.
    if (previous == 0) {
      return null;
    }
    return (current - previous) / previous * 100;
  }

  DateTime _normalizedUtcDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
