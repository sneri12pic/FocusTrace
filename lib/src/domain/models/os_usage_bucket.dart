/// How long a span Android aggregated an [OsUsageBucket] over.
enum OsUsageInterval { daily, monthly }

/// One app's foreground time in one of Android's own aggregated buckets.
///
/// Approximate history: Android picks the bucket boundaries and retention, and
/// keeps no launch counts or sessions. Stored apart from precisely recorded
/// daily usage and never synced or exported.
class OsUsageBucket {
  const OsUsageBucket({
    required this.interval,
    required this.start,
    required this.end,
    required this.appKey,
    required this.appName,
    required this.durationSeconds,
  });

  final OsUsageInterval interval;
  final DateTime start;
  final DateTime end;
  final String appKey;
  final String appName;
  final int durationSeconds;

  /// The local calendar day a daily bucket stands for. Android's daily
  /// boundaries need not match local midnight, so the midpoint decides.
  DateTime get day {
    final middle = start.add(end.difference(start) ~/ 2);
    return DateTime(middle.year, middle.month, middle.day);
  }

  /// The local calendar month a monthly bucket stands for.
  DateTime get month {
    final middle = start.add(end.difference(start) ~/ 2);
    return DateTime(middle.year, middle.month);
  }
}
