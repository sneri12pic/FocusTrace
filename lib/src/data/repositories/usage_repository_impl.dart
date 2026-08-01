import '../../application/services/usage_aggregation_service.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/usage_repository.dart';
import '../datasources/focus_trace_local_data_source.dart';
import '../datasources/platform_usage_data_source.dart';

class UsageRepositoryImpl implements UsageRepository {
  UsageRepositoryImpl({
    required UsagePlatform platform,
    required FocusTraceLocalDataSource localDataSource,
    required PlatformUsageDataSource platformDataSource,
    UsageAggregationService aggregationService =
        const UsageAggregationService(),
  }) : _platform = platform,
       _localDataSource = localDataSource,
       _platformDataSource = platformDataSource,
       _aggregationService = aggregationService;

  final UsagePlatform _platform;
  final FocusTraceLocalDataSource _localDataSource;
  final PlatformUsageDataSource _platformDataSource;
  final UsageAggregationService _aggregationService;

  @override
  Future<bool> hasUsageAccess() {
    return _platformDataSource.hasUsageAccess();
  }

  @override
  Future<void> openUsageAccessSettings() {
    return _platformDataSource.openUsageAccessSettings();
  }

  @override
  Future<List<AppUsageSummary>> getTodaySummaries() async {
    final summaries = _aggregationService.withPercentages(
      await _fetchTodaySummaries(),
    );
    try {
      // Snapshot today's totals so history stays queryable for statistics.
      await _localDataSource.saveDailySummaries(DateTime.now(), summaries);
    } catch (_) {
      // History is best-effort; never block the dashboard on a storage error.
    }
    return summaries;
  }

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async {
    final stored = await _localDataSource.getDailySummaries(day);
    return _withCurrentMetadata(stored);
  }

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() async {
    final stored = await _localDataSource.getAllTimeSummaries();
    return _withCurrentMetadata(stored);
  }

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) {
    return _localDataSource.getUsageHistory(fromInclusive, toExclusive);
  }

  Future<List<AppUsageSummary>> _withCurrentMetadata(
    List<AppUsageSummary> stored,
  ) async {
    if (_platform != UsagePlatform.android || stored.isEmpty) {
      return _aggregationService.withPercentages(stored);
    }

    if (_platformDataSource is! AppMetadataDataSource) {
      return _aggregationService.withPercentages(stored);
    }
    final metadataDataSource = _platformDataSource as AppMetadataDataSource;

    try {
      final metadata = await metadataDataSource.getAppMetadata(
        stored.map((summary) => summary.appKey),
      );
      final metadataByKey = {
        for (final summary in metadata) summary.appKey: summary,
      };
      return _aggregationService.withPercentages(
        stored.map((summary) {
          final current = metadataByKey[summary.appKey];
          if (current == null) {
            return summary;
          }
          return summary.copyWith(
            appName: current.appName.isEmpty
                ? summary.appName
                : current.appName,
            iconBytes: current.iconBytes,
          );
        }),
      );
    } catch (_) {
      // Historical totals stay useful even when package metadata lookup fails.
      return _aggregationService.withPercentages(stored);
    }
  }

  Future<List<AppUsageSummary>> _fetchTodaySummaries() async {
    switch (_platform) {
      case UsagePlatform.android:
        return _platformDataSource.getTodayUsageStats();
      case UsagePlatform.windows:
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final sessions = await _localDataSource.getSessionsForDate(now);
        return _aggregationService.summarizeSessions(
          sessions,
          from: startOfToday,
          to: startOfToday.add(const Duration(days: 1)),
        );
      case UsagePlatform.macos:
      case UsagePlatform.ios:
      case UsagePlatform.linux:
      case UsagePlatform.unsupported:
        return const <AppUsageSummary>[];
    }
  }

  @override
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  }) async {
    if (_platform != UsagePlatform.windows) {
      // Android summaries come from the OS; no per-session rows exist.
      return const <UsageSession>[];
    }

    final sessions = await _localDataSource.getSessionsForDate(date);
    final matching =
        sessions.where((session) => session.appKey == appKey).toList()
          ..sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    return matching.take(limit).toList();
  }

  @override
  Future<void> insertSession(UsageSession session) {
    return _localDataSource.insertSession(session);
  }

  @override
  Future<void> clearAllData() {
    return _localDataSource.clearAllData();
  }
}
