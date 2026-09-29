import 'dart:math';

import '../../domain/models/sync_usage.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/focus_trace_local_data_source.dart';
import '../datasources/focus_trace_sync_api.dart';
import '../datasources/installation_marker_store.dart';
import '../datasources/sync_execution_gate.dart';

/// Coordinates local selection, sanitization, device registration and upload.
///
/// It owns no storage of its own: local usage stays in SQLite and is never
/// deleted or rewritten here, and the watermark is an optimisation rather than
/// a correctness mechanism, so losing it only costs a harmless re-upload.
class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl({
    required FocusTraceSyncApi api,
    required SyncExecutionGate executionGate,
    required FocusTraceLocalDataSource localDataSource,
    required UsageSyncDataSource usageDataSource,
    required Future<String> Function() deviceName,
    Future<void> Function(bool enabled)? reconcileSchedule,
    InstallationMarkerStore? installationMarker,
    String platform = 'android',
    Random? random,
    DateTime Function()? now,
  }) : _api = api,
       _gate = executionGate,
       _local = localDataSource,
       _usage = usageDataSource,
       _deviceName = deviceName,
       _reconcileSchedule = reconcileSchedule,
       _installationMarker = installationMarker,
       _platform = platform,
       _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  // Architecture 9.1. Mirrored here so a day that cannot be accepted is left
  // out rather than failing the whole request on every retry.
  static const maxDaysPerRequest = 31;
  static const maxAppsPerDay = 500;
  static const maxAppRowsPerRequest = 1000;
  static const maxDurationSeconds = 90000;
  static const maxAppKeyUnits = 255;
  static const maxAppNameUnits = 200;
  static const maxTimezoneIdUnits = 64;
  static final DateTime minLocalDate = DateTime.utc(2026, 1, 1);

  final FocusTraceSyncApi _api;
  final SyncExecutionGate _gate;
  final FocusTraceLocalDataSource _local;
  final UsageSyncDataSource _usage;
  final Future<String> Function() _deviceName;
  final Future<void> Function(bool)? _reconcileSchedule;

  /// Null where nothing is backed up behind the app's back (tests, platforms
  /// without the marker); the database id is then the whole identity.
  final InstallationMarkerStore? _installationMarker;
  final String _platform;
  final Random _random;
  final DateTime Function() _now;

  @override
  Future<bool> get isSignedIn => _sessionOperation(() => _api.hasSession);

  // This is the ownership boundary. API and credential helpers never reacquire.
  // The identity is settled before anything else, so a database restored from
  // another installation has lost its opt-in before any caller reads it.
  Future<T> _sessionOperation<T>(Future<T> Function() operation) =>
      _gate.run(() async {
        await _api.reconcileSession();
        await _installationId();
        return operation();
      });

  @override
  Future<String?> accountEmail() =>
      _local.readSetting(SyncSettingKeys.accountEmail);

  @override
  Future<bool> isSyncEnabled() async =>
      await _local.readSetting(SyncSettingKeys.enabled) == 'true';

  @override
  Future<void> setSyncEnabled(bool enabled) => _gate.run(() async {
    await _local.writeSetting(SyncSettingKeys.enabled, enabled ? 'true' : 'false');
    await _reconcileSchedule?.call(enabled);
  });

  @override
  Future<DateTime?> lastSuccessfulSyncAt() async {
    final stored = await _readInt(SyncSettingKeys.lastSuccessMs);
    return stored == null ? null : DateTime.fromMillisecondsSinceEpoch(stored);
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) => _sessionOperation(() async {
    await _authenticating(() async {
      await _api.register(email, password);
      await _api.signIn(email, password);
    });
    await _local.writeSetting(SyncSettingKeys.accountEmail, email);
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _sessionOperation(() async {
        await _authenticating(() => _api.signIn(email, password));
        await _local.writeSetting(SyncSettingKeys.accountEmail, email);
      });

  /// Translates the transport's exception into the domain's, so nothing above
  /// this repository can see a status code or a server message.
  Future<void> _authenticating(Future<void> Function() action) async {
    try {
      await action();
    } on SyncApiException catch (error) {
      throw SyncAuthException(_authFailureFor(error));
    }
  }

  static SyncAuthFailure _authFailureFor(SyncApiException error) {
    if (error.statusCode == 0) {
      return SyncAuthFailure.offline;
    }
    return switch (error.statusCode) {
      400 || 401 => SyncAuthFailure.invalidCredentials,
      409 => SyncAuthFailure.emailTaken,
      422 => SyncAuthFailure.weakPassword,
      _ => SyncAuthFailure.unknown,
    };
  }

  /// Leaves the upload watermark alone: the server still holds what this
  /// device uploaded, and signing back in should not re-send all of it.
  @override
  Future<void> signOut() => _sessionOperation(() async {
    try {
      await _api.signOut();
    } finally {
      await _local.writeSetting(SyncSettingKeys.accountEmail, '');
      await _local.writeSetting(SyncSettingKeys.enabled, 'false');
      await _reconcileSchedule?.call(false);
    }
  });

  /// Backend D19. The whole operation holds the shared execution gate, so no sync,
  /// sign-in or sign-out - foreground or headless - interleaves with it.
  ///
  /// Order: stop periodic work, reset the upload watermark, ask the server, and
  /// only on its confirmation clear the account's local state.
  ///
  /// The watermark is reset before the request because a lost response cannot be
  /// told apart from a failure: the account may be gone while this installation
  /// still believes otherwise, and a later account must not inherit "already
  /// uploaded". Losing it is safe by design - at worst the same account re-sends
  /// days that come back DUPLICATE. It is restored only when the server certainly
  /// deleted nothing (400, 403, 429).
  ///
  /// Kept on success: the installation id (it names this app install, not an
  /// account), `sync_imported_version_ms` (it versions local content) and every
  /// local usage row and non-sync setting.
  @override
  Future<void> deleteAccount({required String password}) =>
      _sessionOperation(() async {
        await _reconcileSchedule?.call(false);
        final watermark = await _local.readSetting(
          SyncSettingKeys.usageWatermarkMs,
        );
        await _local.writeSetting(SyncSettingKeys.usageWatermarkMs, '0');
        try {
          await _api.deleteAccount(password);
        } on Object catch (error) {
          final status = error is SyncApiException ? error.statusCode : null;
          if (watermark != null && const {400, 403, 429}.contains(status)) {
            await _local.writeSetting(
              SyncSettingKeys.usageWatermarkMs,
              watermark,
            );
          }
          await _reconcileSchedule?.call(await isSyncEnabled());
          if (error is SyncApiException) {
            throw SyncAuthException(_deletionFailureFor(error));
          }
          rethrow;
        }
        await _local.writeSetting(SyncSettingKeys.enabled, 'false');
        await _local.writeSetting(SyncSettingKeys.accountEmail, '');
        await _local.writeSetting(SyncSettingKeys.lastSuccessMs, '');
        await _reconcileSchedule?.call(false);
      });

  static SyncAuthFailure _deletionFailureFor(SyncApiException error) {
    return switch (error.statusCode) {
      0 => SyncAuthFailure.offline,
      // Only after a failed refresh: the session is gone, which the API has
      // already cleared locally. The account may or may not still exist.
      401 => SyncAuthFailure.sessionExpired,
      400 || 403 => SyncAuthFailure.invalidCredentials,
      _ => SyncAuthFailure.unknown,
    };
  }

  @override
  Future<List<RemoteUsageDay>> readRemoteHistory({
    required DateTime from,
    required DateTime to,
    String? deviceId,
  }) => _sessionOperation(
    () => _api.readHistory(from: from, to: to, deviceId: deviceId),
  );

  /// A random UUID v4, never derived from hardware, never `ANDROID_ID` and
  /// never an advertising id (architecture section 3). Clearing local data
  /// removes it and the installation legitimately becomes a new device.
  @override
  Future<String> installationId() => _sessionOperation(_installationId);

  /// Architecture section 3. The database value is trusted only when the
  /// never-backed-up marker holds the same value. Otherwise the database was
  /// restored or transferred from another installation - or predates the
  /// marker - and gets a new identity, except for a pre-marker installation
  /// that holds a session: credentials are never backed up, so that database
  /// is its own. Always called inside the execution gate.
  Future<String> _installationId() async {
    final stored = await _local.readSetting(SyncSettingKeys.installationId);
    final hasStored = stored != null && stored.isNotEmpty;
    final marker = _installationMarker;
    if (marker == null) {
      if (hasStored) {
        return stored;
      }
      final generated = _randomUuidV4();
      await _local.writeSetting(SyncSettingKeys.installationId, generated);
      return generated;
    }
    final bound = await marker.read();
    if (hasStored && bound == stored) {
      return stored;
    }
    if (hasStored && bound == null && await _api.hasSession) {
      await marker.write(stored);
      return stored;
    }
    final generated = _randomUuidV4();
    // Marker first: if it cannot be written, nothing has changed and nothing
    // can be registered under an unbound id.
    await marker.write(generated);
    if (hasStored) {
      // Settings copied from another installation: its consent, account and
      // status are not this one's. The watermark stays - the history it covers
      // was uploaded by the installation that measured it, and is not
      // re-attributed to this one.
      await _local.writeSetting(SyncSettingKeys.enabled, 'false');
      await _local.writeSetting(SyncSettingKeys.accountEmail, '');
      await _local.writeSetting(SyncSettingKeys.lastSuccessMs, '');
      await _reconcileSchedule?.call(false);
    }
    // The commit point: until this write, a retry starts the transition again.
    await _local.writeSetting(SyncSettingKeys.installationId, generated);
    return generated;
  }

  @override
  Future<SyncRunResult> syncNow({bool requireEnabled = false}) async {
    try {
      return await _sessionOperation(() async {
        if (requireEnabled && !await isSyncEnabled()) {
          return const SyncRunResult(uploadedDays: 0, results: [], rejectedDays: 0);
        }
        return _syncNow();
      });
    } on SyncApiException catch (error) {
      return SyncRunResult.failed(error.message, _reasonFor(error));
    } on Object {
      return const SyncRunResult.failed(
        'Sync failed.',
        SyncFailureReason.unknown,
      );
    }
  }

  Future<SyncRunResult> _syncNow() async {
    if (!await _api.hasSession) {
      return const SyncRunResult.failed(
        'Not signed in.',
        SyncFailureReason.notSignedIn,
      );
    }
    // Upload progress is the account's, not the installation's (architecture
    // 8.2): progress earned for another account - one signed out of, or copied
    // in by a restore - or of unknown ownership counts as none. Watermark first,
    // owner second, so an interrupted switch repeats rather than half-applies.
    final account = await _api.accountId();
    if (await _local.readSetting(SyncSettingKeys.usageWatermarkAccount) !=
        account) {
      if ((await _readInt(SyncSettingKeys.usageWatermarkMs) ?? 0) != 0) {
        await _local.writeSetting(SyncSettingKeys.usageWatermarkMs, '0');
      }
      await _local.writeSetting(SyncSettingKeys.usageWatermarkAccount, account);
    }
    final watermark = await _readInt(SyncSettingKeys.usageWatermarkMs) ?? 0;
    final days = _sanitize(
      await _usage.readSyncUsageDays(
        watermarkMs: watermark,
        importedVersionMs: await _importedVersion(),
      ),
    );
    if (days.isEmpty) {
      // Nothing to send is still a run that reached its conclusion, so the
      // "last synced" stamp advances rather than looking permanently stale.
      await _recordSuccess();
      return const SyncRunResult(
        uploadedDays: 0,
        results: <SyncUploadResult>[],
        rejectedDays: 0,
      );
    }

    var deviceId = await _installationId();
    final displayName = await _deviceName();
    // Idempotent: 201 once, 200 for every run after, and it keeps
    // last_seen_at current. It never creates a second device.
    try {
      await _api.registerDevice(
        deviceId: deviceId,
        displayName: displayName,
        platform: _platform,
      );
    } on SyncApiException catch (error) {
      if (error.statusCode != 409) {
        rethrow;
      }
      // D12: another account owns this id - one this installation signed out
      // of. Ownership never moves, so this installation becomes a new device
      // for the signed-in account. Marker first, database id as the commit
      // point, as in _installationId; consent and progress are this account's.
      deviceId = _randomUuidV4();
      await _installationMarker?.write(deviceId);
      await _local.writeSetting(SyncSettingKeys.installationId, deviceId);
      await _api.registerDevice(
        deviceId: deviceId,
        displayName: displayName,
        platform: _platform,
      );
    }

    final results = <SyncUploadResult>[];
    var rejected = 0;
    var highWater = watermark;
    for (final batch in _batches(days)) {
      try {
        results.addAll(await _api.uploadDays(deviceId, batch));
      } on SyncApiException catch (error) {
        if (!error.isPermanent) {
          // Transient. Leave the watermark where it is and try again later;
          // batches already sent will simply answer DUPLICATE.
          rethrow;
        }
        // Deterministic rejection. Resending it unchanged would loop forever
        // (architecture 9.1, client obligations), so it is counted and passed
        // over. The local record is untouched and stays authoritative.
        rejected += batch.length;
      }
      for (final day in batch) {
        if (day.snapshotVersion > highWater) {
          highWater = day.snapshotVersion;
        }
      }
    }
    await _local.writeSetting(SyncSettingKeys.usageWatermarkMs, '$highWater');
    await _recordSuccess();
    return SyncRunResult(
      uploadedDays: days.length - rejected,
      results: results,
      rejectedDays: rejected,
    );
  }

  Future<void> _recordSuccess() => _local.writeSetting(
    SyncSettingKeys.lastSuccessMs,
    '${_now().millisecondsSinceEpoch}',
  );

  /// The status is deliberately not carried any further than this. Everything
  /// above sees one of a handful of cases a user can act on.
  static SyncFailureReason _reasonFor(SyncApiException error) {
    if (error.statusCode == 0) {
      return SyncFailureReason.offline;
    }
    if (error.isUnauthenticated) {
      return SyncFailureReason.sessionExpired;
    }
    if (error.isPermanent) {
      return SyncFailureReason.refused;
    }
    if (const {408, 429, 500, 502, 503, 504}.contains(error.statusCode)) {
      return SyncFailureReason.temporary;
    }
    return SyncFailureReason.unknown;
  }

  // --- upload selection --------------------------------------------------------

  /// Splits into requests that satisfy both request-wide limits.
  static List<List<SyncUsageDay>> _batches(List<SyncUsageDay> days) {
    final batches = <List<SyncUsageDay>>[];
    var current = <SyncUsageDay>[];
    var rows = 0;
    for (final day in days) {
      if (current.isNotEmpty &&
          (current.length == maxDaysPerRequest ||
              rows + day.apps.length > maxAppRowsPerRequest)) {
        batches.add(current);
        current = <SyncUsageDay>[];
        rows = 0;
      }
      current.add(day);
      rows += day.apps.length;
    }
    if (current.isNotEmpty) {
      batches.add(current);
    }
    return batches;
  }

  // --- client sanitization (architecture 9.1) ----------------------------------

  /// Deterministic: the same local day always produces the same request, so a
  /// re-upload of unchanged content is recognised as a duplicate rather than a
  /// conflict. Never mutates the local record.
  List<SyncUsageDay> _sanitize(List<SyncUsageDay> days) {
    final latest = DateTime.utc(
      _now().toUtc().year,
      _now().toUtc().month,
      _now().toUtc().day,
    ).add(const Duration(days: 1));
    final sanitized = <SyncUsageDay>[];
    for (final day in days) {
      final date = DateTime.tryParse(day.localDate);
      if (date == null ||
          date.isBefore(minLocalDate) ||
          DateTime.utc(date.year, date.month, date.day).isAfter(latest)) {
        // A clock that was wrong at boot can write such a day. Sending it would
        // fail the whole request on every retry.
        continue;
      }
      sanitized.add(
        SyncUsageDay(
          localDate: day.localDate,
          timezoneId: _timezoneId(day.timezoneId),
          snapshotVersion: day.snapshotVersion,
          sourceStatus: day.sourceStatus,
          apps: _sanitizeApps(day.apps),
        ),
      );
    }
    return sanitized;
  }

  static String _timezoneId(String value) {
    final trimmed = value.trim();
    // Resolvability is the server's call (ZoneId.of); Dart has no zone
    // database to check it against. Only the shape is enforced here.
    if (trimmed.isEmpty || trimmed.length > maxTimezoneIdUnits) {
      return 'UTC';
    }
    return trimmed;
  }

  static List<SyncUsageApp> _sanitizeApps(List<SyncUsageApp> apps) {
    final byKey = <String, SyncUsageApp>{};
    for (final app in apps) {
      final key = _storable(app.appKey, maxAppKeyUnits);
      if (key.isEmpty) {
        // Nothing identifies this row after sanitization; the server would
        // reject the whole day for it.
        continue;
      }
      final name = _storable(app.appName, maxAppNameUnits);
      byKey.putIfAbsent(
        key,
        () => SyncUsageApp(
          appKey: key,
          appName: name.isEmpty ? key : name,
          durationSeconds: app.durationSeconds.clamp(0, maxDurationSeconds),
          launchCount: app.launchCount < 0 ? 0 : app.launchCount,
        ),
      );
    }
    final kept = byKey.values.toList()
      // Longest first so a truncated day keeps the usage that matters, with
      // appKey breaking ties so the order never depends on map iteration.
      ..sort((a, b) {
        final byDuration = b.durationSeconds.compareTo(a.durationSeconds);
        return byDuration != 0 ? byDuration : a.appKey.compareTo(b.appKey);
      });
    final bounded = kept.length > maxAppsPerDay
        ? kept.sublist(0, maxAppsPerDay)
        : kept;
    // Stable wire order, independent of how many were dropped.
    return bounded..sort((a, b) => a.appKey.compareTo(b.appKey));
  }

  /// Drops what PostgreSQL and the JDBC driver cannot store faithfully, then
  /// truncates without splitting a surrogate pair.
  static String _storable(String value, int maxUnits) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit == 0) {
        // PostgreSQL text cannot hold NUL.
        continue;
      }
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        final next = i + 1 < value.length ? value.codeUnitAt(i + 1) : 0;
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer
            ..writeCharCode(unit)
            ..writeCharCode(next);
          i++;
          continue;
        }
        // Unpaired: the driver would store '?', so a retry would differ.
        continue;
      }
      if (unit >= 0xDC00 && unit <= 0xDFFF) {
        continue;
      }
      buffer.writeCharCode(unit);
    }
    final cleaned = buffer.toString().trim();
    if (cleaned.length <= maxUnits) {
      return cleaned;
    }
    final lastUnit = cleaned.codeUnitAt(maxUnits - 1);
    final end = lastUnit >= 0xD800 && lastUnit <= 0xDBFF
        ? maxUnits - 1
        : maxUnits;
    return cleaned.substring(0, end).trim();
  }

  // --- local sync state ----------------------------------------------------------

  Future<int?> _readInt(String key) async {
    final stored = await _local.readSetting(key);
    return stored == null ? null : int.tryParse(stored);
  }

  /// The version every day without a `usage_snapshot_days` row uploads under
  /// (architecture 7.2). `_invalidateUsageRecovery` advances it whenever an
  /// import or a clear rewrites that content; this only seeds it.
  Future<int> _importedVersion() async {
    final stored = await _readInt(SyncSettingKeys.importedVersionMs);
    if (stored != null && stored > 0) {
      return stored;
    }
    final seeded = _now().millisecondsSinceEpoch;
    await _local.writeSetting(SyncSettingKeys.importedVersionMs, '$seeded');
    return seeded;
  }

  String _randomUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
