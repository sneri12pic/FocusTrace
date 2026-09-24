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

  /// The account this installation is signed into, when it is known.
  Future<String?> accountEmail();

  /// Opt-in, and off until the user says otherwise.
  ///
  /// Nothing in this repository consults it: [syncNow] is the raw capability
  /// and stays callable, because the decision to sync is the app's, not the
  /// data layer's. Every caller that syncs without the user asking - the
  /// background scheduler, when it exists - must check this first.
  Future<bool> isSyncEnabled();

  Future<void> setSyncEnabled(bool enabled);

  /// When [syncNow] last reached the server, for display only.
  Future<DateTime?> lastSuccessfulSyncAt();

  Future<void> createAccount({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Permanently deletes the signed-in cloud account and everything the server
  /// holds for it, confirmed with the current [password]. Local usage history is
  /// never touched. On success this installation is signed out, sync is off and
  /// account-specific progress is reset, so a later account uploads everything
  /// again. Throws [SyncAuthException] when the deletion was not confirmed.
  Future<void> deleteAccount({required String password});

  /// Registers this installation if needed and uploads every local day that has
  /// changed since the last successful run. Never throws.
  /// Background callers must require opt-in; it is checked inside the run gate.
  Future<SyncRunResult> syncNow({bool requireEnabled = false});

  /// Reads this account's history back, across every device it has registered.
  /// [from] inclusive, [to] exclusive, at most 400 days.
  Future<List<RemoteUsageDay>> readRemoteHistory({
    required DateTime from,
    required DateTime to,
    String? deviceId,
  });
}
