import '../../domain/models/os_usage_bucket.dart';
import '../datasources/focus_trace_local_data_source.dart';
import '../datasources/platform_usage_data_source.dart';

/// Android's aggregated history from before FocusTrace recorded anything.
///
/// Approximate by nature, so callers use it only for days or months with no
/// precisely recorded usage, and mark it as such.
class OsUsageHistoryRepository {
  OsUsageHistoryRepository({
    required FocusTraceLocalDataSource localDataSource,
    required PlatformUsageDataSource platformDataSource,
  }) : _localDataSource = localDataSource,
       _platformDataSource = platformDataSource;

  final FocusTraceLocalDataSource _localDataSource;
  final PlatformUsageDataSource _platformDataSource;
  Future<DateTime?>? _import;

  /// Copies what Android still retains into local storage, once per app run.
  /// Returns the earliest day found, or null when there was nothing (no
  /// access yet, unsupported platform, or a failure; those retry next call).
  Future<DateTime?> importOnce() => _import ??= _importNow();

  Future<DateTime?> _importNow() async {
    DateTime? earliest;
    final platform = _platformDataSource;
    if (platform is OsUsageHistoryDataSource) {
      try {
        final buckets = await (platform as OsUsageHistoryDataSource)
            .getOsUsageHistory();
        await _localDataSource.upsertOsUsageBuckets(buckets);
        for (final bucket in buckets) {
          final day = DateTime(
            bucket.start.year,
            bucket.start.month,
            bucket.start.day,
          );
          if (earliest == null || day.isBefore(earliest)) earliest = day;
        }
      } catch (_) {
        // Offline-first: history import is optional and never blocks a screen.
      }
    }
    if (earliest == null) _import = null;
    return earliest;
  }

  /// [appKey]'s approximate seconds per local day in the half-open range.
  Future<Map<DateTime, int>> dailySeconds(
    String appKey,
    DateTime fromInclusive,
    DateTime toExclusive,
  ) => _sum(OsUsageInterval.daily, appKey, fromInclusive, toExclusive);

  /// [appKey]'s approximate seconds per calendar month in the range.
  Future<Map<DateTime, int>> monthlySeconds(
    String appKey,
    DateTime fromInclusive,
    DateTime toExclusive,
  ) => _sum(OsUsageInterval.monthly, appKey, fromInclusive, toExclusive);

  Future<Map<DateTime, int>> _sum(
    OsUsageInterval interval,
    String appKey,
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    final totals = <DateTime, int>{};
    try {
      final buckets = await _localDataSource.getOsUsageBuckets(
        interval,
        fromInclusive,
        toExclusive,
      );
      for (final bucket in buckets) {
        if (bucket.appKey != appKey) continue;
        final key = interval == OsUsageInterval.daily
            ? bucket.day
            : bucket.month;
        if (key.isBefore(fromInclusive) || !key.isBefore(toExclusive)) {
          continue;
        }
        totals.update(
          key,
          (total) => total + bucket.durationSeconds,
          ifAbsent: () => bucket.durationSeconds,
        );
      }
    } catch (_) {
      // Missing approximate history only means fewer filled-in days.
    }
    return totals;
  }
}
