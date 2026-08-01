import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_session.dart';

class UsageAggregationService {
  const UsageAggregationService();

  List<AppUsageSummary> summarizeSessions(
    Iterable<UsageSession> sessions, {
    DateTime? from,
    DateTime? to,
  }) {
    final buckets = <String, _UsageBucket>{};

    for (final session in sessions) {
      final clippedStart = _maxDate(session.startedAt, from);
      final clippedEnd = _minDate(session.endedAt, to);

      if (clippedStart == null ||
          clippedEnd == null ||
          !clippedEnd.isAfter(clippedStart)) {
        continue;
      }

      final durationSeconds = clippedEnd.difference(clippedStart).inSeconds;
      if (durationSeconds <= 0) {
        continue;
      }

      final bucket = buckets.putIfAbsent(
        session.appKey,
        () => _UsageBucket(
          appName: session.appName,
          packageName: session.packageName,
          processName: session.processName,
        ),
      );

      bucket
        ..totalDurationSeconds += durationSeconds
        ..launchCount += 1
        ..lastUsedAt = _maxDate(bucket.lastUsedAt, clippedEnd);
    }

    final summaries =
        buckets.values
            .map(
              (bucket) => AppUsageSummary(
                appName: bucket.appName,
                packageName: bucket.packageName,
                processName: bucket.processName,
                totalDurationSeconds: bucket.totalDurationSeconds,
                percentageOfTotal: 0,
                launchCount: bucket.launchCount,
                lastUsedAt: bucket.lastUsedAt,
              ),
            )
            .toList()
          ..sort((a, b) {
            final durationComparison = b.totalDurationSeconds.compareTo(
              a.totalDurationSeconds,
            );
            if (durationComparison != 0) {
              return durationComparison;
            }
            return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
          });

    return withPercentages(summaries);
  }

  int totalDurationSeconds(Iterable<AppUsageSummary> summaries) {
    return summaries.fold<int>(
      0,
      (total, summary) => total + summary.totalDurationSeconds,
    );
  }

  List<AppUsageSummary> withPercentages(Iterable<AppUsageSummary> summaries) {
    final items = summaries.toList();
    final totalSeconds = totalDurationSeconds(items);
    return items
        .map(
          (summary) => summary.copyWith(
            percentageOfTotal: totalSeconds == 0
                ? 0
                : summary.totalDurationSeconds / totalSeconds,
          ),
        )
        .toList();
  }
}

class _UsageBucket {
  _UsageBucket({required this.appName, this.packageName, this.processName});

  final String appName;
  final String? packageName;
  final String? processName;
  int totalDurationSeconds = 0;
  int launchCount = 0;
  DateTime? lastUsedAt;
}

DateTime? _minDate(DateTime? left, DateTime? right) {
  if (left == null) {
    return right;
  }
  if (right == null) {
    return left;
  }
  return left.isBefore(right) ? left : right;
}

DateTime? _maxDate(DateTime? left, DateTime? right) {
  if (left == null) {
    return right;
  }
  if (right == null) {
    return left;
  }
  return left.isAfter(right) ? left : right;
}
