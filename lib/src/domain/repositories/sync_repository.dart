import '../models/sync_usage.dart';

/// Optional cloud sync of daily usage history.
///
/// Every method is best-effort and off the critical path. Nothing here is
/// required for tracking, restrictions, blocking, schedules, local history or
/// normal UI, and a failure never changes local data. The local database stays
/// authoritative; the server holds a copy.
///
/// Layering: `domain -> sync repository -> remote data source`. Widgets, screens
/// and view models talk to this interface, never to HTTP.
abstract interface class SyncRepository {
  /// This installation's UUID, generated on first use (architecture section 3).
  Future<String> installationId();

  Future<bool> get isSignedIn;

  Future<void> createAccount({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Registers this installation if needed and uploads every local day that has
  /// changed since the last successful run. Never throws.
  Future<SyncRunResult> syncNow();

  /// Reads this account's history back, across every device it has registered.
  /// [from] inclusive, [to] exclusive, at most 400 days.
  Future<List<RemoteUsageDay>> readRemoteHistory({
    required DateTime from,
    required DateTime to,
    String? deviceId,
  });
}
