import '../models/app_usage_summary.dart';
import '../models/daily_app_usage.dart';
import '../models/usage_session.dart';

abstract class UsageRepository {
  Future<bool> hasUsageAccess();

  Future<void> openUsageAccessSettings();

  Future<List<AppUsageSummary>> getTodaySummaries();

  /// Today's most recently stored snapshot, without querying platform usage.
  Future<List<AppUsageSummary>> getCachedTodaySummaries(DateTime day);

  /// Per-app totals stored for [day] (snapshotted whenever today's usage is
  /// fetched), longest first. Empty when nothing was recorded that day.
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day);

  /// Per-app totals aggregated across every locally stored day.
  Future<List<AppUsageSummary>> getAllTimeSummaries();

  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  );

  /// The longest recorded sessions for [appKey] on [date], longest first.
  /// Returns an empty list on platforms without local session storage.
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  });

  Future<void> insertSession(UsageSession session);

  Future<void> clearAllData();
}

/// Optional repository capability for enriching persisted usage-only rows with
/// current platform app names and icons.
abstract interface class AppMetadataRepository {
  Future<List<AppUsageSummary>> hydrateAppMetadata(
    List<AppUsageSummary> summaries,
  );
}
