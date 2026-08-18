import '../../domain/models/restriction_event.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/repositories/usage_repository.dart';
import '../datasources/focus_trace_local_data_source.dart';
import '../datasources/platform_usage_data_source.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    required UsageRepository usageRepository,
    required FocusTraceLocalDataSource localDataSource,
    required PlatformUsageDataSource platformDataSource,
  }) : _usageRepository = usageRepository,
       _localDataSource = localDataSource,
       _platformDataSource = platformDataSource;

  final UsageRepository _usageRepository;
  final FocusTraceLocalDataSource _localDataSource;
  final PlatformUsageDataSource _platformDataSource;

  @override
  Future<UsageReportSourceData> loadSourceData(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!today.isBefore(fromInclusive) && today.isBefore(toExclusive)) {
      try {
        await _usageRepository.getTodaySummaries();
      } catch (_) {
        // Reports still work from persisted snapshots when live access fails.
      }
    }

    final intervalSource = _platformDataSource is UsageIntervalDataSource
        ? _platformDataSource as UsageIntervalDataSource
        : null;
    if (intervalSource != null) {
      try {
        final freshIntervals = await intervalSource.getUsageIntervals(
          fromInclusive.subtract(const Duration(days: 1)),
          now,
        );
        await _localDataSource.insertUsageIntervals(freshIntervals);
      } catch (_) {
        // Background snapshots remain available when an OS query fails.
      }
    }

    final intervalFrom = fromInclusive.subtract(const Duration(days: 1));
    final results = await (
      _localDataSource.getUsageHistory(fromInclusive, toExclusive),
      _localDataSource.getUsageIntervals(intervalFrom, toExclusive),
      _localDataSource.getRestrictionEvents(fromInclusive, toExclusive),
    ).wait;
    return UsageReportSourceData(
      dailyUsage: results.$1,
      intervals: results.$2,
      restrictionEvents: results.$3,
    );
  }

  @override
  Future<void> recordRestrictionEvent(RestrictionEvent event) {
    return _localDataSource.insertRestrictionEvent(event);
  }
}
