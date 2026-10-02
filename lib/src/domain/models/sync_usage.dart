/// Domain models for optional cloud sync (backend architecture sections 9.1-9.3).
///
/// These mirror the published API contract deliberately: the contract is the
/// domain here, and a second set of DTOs would duplicate it without a boundary
/// reason. Nothing in this file touches HTTP or SQLite.
library;

/// One app's total for one local day, as the API carries it.
class SyncUsageApp {
  const SyncUsageApp({
    required this.appKey,
    required this.appName,
    required this.durationSeconds,
    required this.launchCount,
  });

  final String appKey;
  final String appName;
  final int durationSeconds;
  final int launchCount;

  @override
  bool operator ==(Object other) =>
      other is SyncUsageApp &&
      other.appKey == appKey &&
      other.appName == appName &&
      other.durationSeconds == durationSeconds &&
      other.launchCount == launchCount;

  @override
  int get hashCode =>
      Object.hash(appKey, appName, durationSeconds, launchCount);

  @override
  String toString() =>
      'SyncUsageApp($appKey, $appName, ${durationSeconds}s, $launchCount)';
}

/// A complete daily snapshot, ready to upload.
///
/// [localDate] is the `YYYY-MM-DD` key `daily_app_usage` already uses, and
/// [snapshotVersion] is `usage_snapshot_days.queried_at_ms` for a measured day
/// or `sync_imported_version_ms` for a versionless one (architecture 7.1-7.2).
class SyncUsageDay {
  const SyncUsageDay({
    required this.localDate,
    required this.timezoneId,
    required this.snapshotVersion,
    required this.sourceStatus,
    required this.apps,
  });

  final String localDate;
  final String timezoneId;
  final int snapshotVersion;
  final String sourceStatus;
  final List<SyncUsageApp> apps;

  Map<String, Object?> toJson() => {
    'localDate': localDate,
    'timezoneId': timezoneId,
    'snapshotVersion': snapshotVersion,
    'sourceStatus': sourceStatus,
    'apps': [
      for (final app in apps)
        {
          'appKey': app.appKey,
          'appName': app.appName,
          'durationSeconds': app.durationSeconds,
          'launchCount': app.launchCount,
        },
    ],
  };
}

/// What the server did with one submitted day (architecture 9.2).
enum SyncDayOutcome { applied, duplicate, stale, conflict }

class SyncUploadResult {
  const SyncUploadResult({
    required this.localDate,
    required this.outcome,
    required this.storedVersion,
  });

  factory SyncUploadResult.fromJson(Map<String, Object?> json) =>
      SyncUploadResult(
        localDate: json['localDate']! as String,
        outcome: SyncDayOutcome.values.byName(
          (json['outcome']! as String).toLowerCase(),
        ),
        storedVersion: (json['storedVersion']! as num).toInt(),
      );

  final String localDate;
  final SyncDayOutcome outcome;
  final int storedVersion;

  @override
  String toString() => '$localDate=${outcome.name}@$storedVersion';
}

/// A day read back from the server, with its source device intact
/// (architecture 9.3). Days from different devices are never merged.
class RemoteUsageDay {
  const RemoteUsageDay({
    required this.deviceId,
    required this.deviceName,
    required this.localDate,
    required this.timezoneId,
    required this.snapshotVersion,
    required this.apps,
  });

  factory RemoteUsageDay.fromJson(Map<String, Object?> json) => RemoteUsageDay(
    deviceId: json['deviceId']! as String,
    deviceName: json['deviceName']! as String,
    localDate: json['localDate']! as String,
    timezoneId: json['timezoneId']! as String,
    snapshotVersion: (json['snapshotVersion']! as num).toInt(),
    apps: [
      for (final app in (json['apps']! as List).cast<Map<String, Object?>>())
        SyncUsageApp(
          appKey: app['appKey']! as String,
          appName: app['appName']! as String,
          durationSeconds: (app['durationSeconds']! as num).toInt(),
          launchCount: (app['launchCount']! as num).toInt(),
        ),
    ],
  );

  final String deviceId;
  final String deviceName;
  final String localDate;
  final String timezoneId;
  final int snapshotVersion;
  final List<SyncUsageApp> apps;

  @override
  String toString() => 'RemoteUsageDay($deviceName/$localDate, ${apps.length})';
}

/// Why a sync run failed, in terms the UI can act on.
///
/// [SyncRunResult.failure] is a developer string: it can name an exception type
/// and is never shown to anyone. This is the classification a screen may
/// present, so it carries no status code, no server text and no transport
/// detail - only the handful of cases a user can do something about.
enum SyncFailureReason {
  notSignedIn,
  offline,
  temporary,
  sessionExpired,
  refused,
  unknown,
}

/// Why signing in or creating an account failed.
///
/// Sign-in reports failure by throwing, because there is no useful "partial"
/// result, while [SyncRunResult] reports it by value. Both classify into cases
/// a user can act on and nothing more.
enum SyncAuthFailure {
  offline,
  invalidCredentials,
  invalidRegistration,

  /// Registration: the server rejected the email address.
  invalidEmail,

  /// Registration: the server rejected the password (length, blocklist, or
  /// equal to the email's local part).
  passwordRejected,
  accountCreatedSignInRequired,
  emailTaken,
  weakPassword,

  /// The server's per-network attempt limit was reached (HTTP 429).
  throttled,

  /// The session was rejected. Only account deletion reports it: sign-in and
  /// account creation have no session yet.
  sessionExpired,
  unknown,
}

/// The only authentication error that leaves the sync repository.
///
/// Deliberately carries no status code, no server body and no inner exception:
/// this is the object a screen sees, and the layer above the repository has no
/// business knowing HTTP happened.
class SyncAuthException implements Exception {
  const SyncAuthException(this.failure);

  final SyncAuthFailure failure;

  @override
  String toString() => 'SyncAuthException($failure)';
}

/// Outcome of one sync run. Best-effort by design: [failure] being set never
/// means local data changed.
class SyncRunResult {
  const SyncRunResult({
    required this.uploadedDays,
    required this.results,
    required this.rejectedDays,
    this.failure,
    this.reason,
  });

  const SyncRunResult.failed(
    String this.failure, [
    this.reason = SyncFailureReason.unknown,
  ]) : uploadedDays = 0,
       results = const <SyncUploadResult>[],
       rejectedDays = 0;

  final int uploadedDays;
  final List<SyncUploadResult> results;

  /// Days the server rejected as invalid (400). They stay local and are not
  /// retried unchanged (architecture 9.1, client obligations).
  final int rejectedDays;
  final String? failure;

  /// Set whenever [failure] is. Defaults to [SyncFailureReason.unknown] so a
  /// caller never has to handle "failed but unclassified".
  final SyncFailureReason? reason;

  bool get succeeded => failure == null;

  int countOf(SyncDayOutcome outcome) =>
      results.where((result) => result.outcome == outcome).length;

  @override
  String toString() => failure == null
      ? 'SyncRunResult($uploadedDays uploaded, $rejectedDays rejected, $results)'
      : 'SyncRunResult(failed: $failure)';
}
