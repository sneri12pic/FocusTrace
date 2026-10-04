import '../datasources/focus_trace_local_data_source.dart';
import '../datasources/platform_usage_data_source.dart';

/// Shared entry point for statistics and reports; OS retention decisions and
/// all Android snapshot writes belong to the native recovery component.
Future<void> recoverUsageHistory(
  FocusTraceLocalDataSource local,
  PlatformUsageDataSource platform,
  DateTime fromInclusive,
  DateTime toExclusive,
) async {
  if (platform is! UsageHistoryRecoveryDataSource) return;
  try {
    if (local is UsageRecoveryDatabase) {
      await (local as UsageRecoveryDatabase).prepareUsageRecovery();
    }
    await (platform as UsageHistoryRecoveryDataSource).recoverUsageHistory(
      fromInclusive,
      toExclusive,
    );
  } catch (_) {
    // Missing permissions, locked user, expired events or SQLite failure must
    // leave the persisted history readable. Native writes are transactional.
  }
}
