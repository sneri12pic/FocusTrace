import 'dart:io';

import 'support/test_sync_execution_gate.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Phase 2 proof against the real Spring backend and real PostgreSQL.
///
/// Two independent installations, one account: Device A uploads its local days
/// and Device B reads them back with the source device intact, while repeated
/// sync stays idempotent and a third account sees nothing.
///
/// Skipped unless a live backend is pointed at:
///
/// ```bash
/// flutter test test/sync_end_to_end_test.dart \
///   --dart-define=FOCUSTRACE_SYNC_BASE_URL=http://localhost:18080
/// ```
///
/// It is excluded from the default `flutter test` run on purpose: the suite
/// must not need Docker, a database or a server to pass.
const baseUrl = String.fromEnvironment('FOCUSTRACE_SYNC_BASE_URL');

const password = 'Violet-Quarry-Lantern-8214';

void main() {
  if (baseUrl.isEmpty) {
    test(
      'Phase 2 end-to-end sync',
      () {},
      skip:
          'Set --dart-define=FOCUSTRACE_SYNC_BASE_URL=http://host:port with a '
          'live backend to run this proof.',
    );
    return;
  }

  // Needed for the mock credential channel below. It also installs an
  // HttpOverrides that answers every request with 400, and this suite talks to
  // a real backend, so the override goes straight back out.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late _Installation deviceA;
  late _Installation deviceB;
  late _Installation otherAccount;
  late Map<String, String> nativeKeystore;

  setUp(() async {
    sqfliteFfiInit();
    nativeKeystore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('focustrace/sync'), (
          call,
        ) async {
          switch (call.method) {
            case 'readSyncCredential':
              return nativeKeystore['refresh_token'];
            case 'writeSyncCredential':
              nativeKeystore['refresh_token'] = call.arguments as String;
              return null;
            case 'clearSyncCredential':
              nativeKeystore.remove('refresh_token');
              return null;
          }
          return null;
        });
    deviceA = await _Installation.create('e2e-a', 'E2E Device A');
    deviceB = await _Installation.create('e2e-b', 'E2E Device B');
    otherAccount = await _Installation.create('e2e-c', 'E2E Device C');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('focustrace/sync'), null);
    await deviceA.dispose();
    await deviceB.dispose();
    await otherAccount.dispose();
  });

  test('Device B reads Device A history, and repeated sync is idempotent',
      () async {
    final email = 'e2e-${DateTime.now().microsecondsSinceEpoch}@example.com';
    final sharedDate = _dayKey(DateTime.now().toUtc().subtract(
          const Duration(days: 2),
        ));
    final soloDate = _dayKey(DateTime.now().toUtc().subtract(
          const Duration(days: 3),
        ));

    // 1. An account exists.
    await deviceA.repository.createAccount(email: email, password: password);
    final deviceAId = await deviceA.repository.installationId();

    // 2-3. Device A registers and uploads its local days on the first run.
    await deviceA.seed(soloDate, queriedAtMs: 1_700_000_000_001,
        appKey: 'com.solo', appName: 'Solo', durationSeconds: 111);
    await deviceA.seed(sharedDate, queriedAtMs: 1_700_000_000_002,
        appKey: 'com.shared', appName: 'Shared', durationSeconds: 222);
    final localBefore = await deviceA.usageRows();

    final firstRun = await deviceA.repository.syncNow();
    expect(firstRun.failure, isNull);
    expect(firstRun.countOf(SyncDayOutcome.applied), 2,
        reason: 'first upload of two fresh days');

    // 4. Running again sends nothing: the watermark already covers both days.
    final secondRun = await deviceA.repository.syncNow();
    expect(secondRun.succeeded, isTrue);
    expect(secondRun.uploadedDays, 0);
    expect(secondRun.results, isEmpty);

    // 5. Forcing the same upload again is a DUPLICATE, not a second copy.
    await deviceA.local.writeSetting(SyncSettingKeys.usageWatermarkMs, '0');
    final forcedRun = await deviceA.repository.syncNow();
    expect(forcedRun.countOf(SyncDayOutcome.duplicate), 2);
    expect(forcedRun.countOf(SyncDayOutcome.applied), 0);

    // 6. Device B is a separate installation on the same account. It uploads
    //    the same date with different content, which must not merge with A's.
    await deviceB.repository.signIn(email: email, password: password);
    final deviceBId = await deviceB.repository.installationId();
    expect(deviceBId, isNot(deviceAId));
    await deviceB.seed(sharedDate, queriedAtMs: 1_700_000_000_003,
        appKey: 'com.shared', appName: 'Shared', durationSeconds: 999);
    expect((await deviceB.repository.syncNow()).countOf(SyncDayOutcome.applied),
        1);

    // 7-9. Device B reads the account's history: Device A's days are there,
    //      each labelled with the device that measured it.
    final history = await deviceB.repository.readRemoteHistory(
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.now().toUtc().add(const Duration(days: 1)),
    );

    final fromA = history.where((day) => day.deviceId == deviceAId).toList();
    final fromB = history.where((day) => day.deviceId == deviceBId).toList();
    expect(fromA.map((day) => day.localDate),
        containsAll(<String>[soloDate, sharedDate]));
    expect(fromB.map((day) => day.localDate), [sharedDate]);
    expect(fromA.map((day) => day.deviceName).toSet(), {'E2E Device A'});
    expect(fromB.single.deviceName, 'E2E Device B');

    // The same date on two devices stays two rows with their own measurements.
    final sharedEverywhere =
        history.where((day) => day.localDate == sharedDate).toList();
    expect(sharedEverywhere, hasLength(2));
    expect(
      sharedEverywhere.map((day) => day.apps.single.durationSeconds).toSet(),
      {222, 999},
    );

    // 10-11. Re-running both installations changes nothing.
    await deviceA.repository.syncNow();
    await deviceB.repository.syncNow();
    final afterRerun = await deviceB.repository.readRemoteHistory(
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    expect(afterRerun.length, history.length);
    expect(
      afterRerun.map((day) => '${day.deviceId}/${day.localDate}').toSet(),
      history.map((day) => '${day.deviceId}/${day.localDate}').toSet(),
    );
    for (final day in afterRerun) {
      expect(day.apps, hasLength(1), reason: 'no accumulation within a day');
    }

    // 12. Device A's local record is exactly what it was.
    expect(await deviceA.usageRows(), localBefore);

    // 13. A different account sees neither device.
    final otherEmail =
        'e2e-other-${DateTime.now().microsecondsSinceEpoch}@example.com';
    await otherAccount.repository
        .createAccount(email: otherEmail, password: password);
    final otherHistory = await otherAccount.repository.readRemoteHistory(
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    expect(otherHistory, isEmpty);
    expect(
      await otherAccount.repository
          .readRemoteHistory(
            from: DateTime.utc(2026, 1, 1),
            to: DateTime.now().toUtc().add(const Duration(days: 1)),
            deviceId: deviceAId,
          ),
      isEmpty,
      reason: 'a foreign deviceId filters to nothing (D16)',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a restart restores the session from secure storage', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'e2e-restart-$stamp@example.com';
    final date = _dayKey(
      DateTime.now().toUtc().subtract(const Duration(days: 4)),
    );

    // Every Dart object below is rebuilt from nothing but `deviceA.local` and
    // whatever the keystore kept, which is what a cold start actually has.
    SyncRepositoryImpl launch() => SyncRepositoryImpl(
      executionGate: TestSyncExecutionGate(),
      api: FocusTraceSyncApi(
        baseUrl: Uri.parse(baseUrl),
        credentials: const SecureSyncCredentialStore(),
      ),
      localDataSource: deviceA.local,
      usageDataSource: deviceA.local,
      deviceName: () async => 'E2E Device A',
    );

    await launch().createAccount(email: email, password: password);
    await deviceA.seed(
      date,
      queriedAtMs: 1700000000004,
      appKey: 'com.restart',
      appName: 'Restart',
      durationSeconds: 333,
    );
    expect(nativeKeystore['refresh_token'], isNotNull);
    expect(nativeKeystore.values, isNot(contains(contains(password))));

    // The process dies here.
    final afterRestart = launch();

    expect(await afterRestart.isSignedIn, isTrue);
    // Uploading proves the restored token bought a real access token from the
    // real backend, through its real rotation and replay detection.
    final run = await afterRestart.syncNow();
    expect(run.failure, isNull);
    expect(run.countOf(SyncDayOutcome.applied), 1);
    expect(
      (await afterRestart.readRemoteHistory(
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.now().toUtc().add(const Duration(days: 1)),
      )).map((day) => day.localDate),
      contains(date),
    );

    // Signing out empties the keystore, and the next launch is anonymous.
    await afterRestart.signOut();
    expect(nativeKeystore, isEmpty);
    expect(await launch().isSignedIn, isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// One FocusTrace installation: its own database, its own installation UUID and
/// its own credential store.
class _Installation {
  _Installation(this.directory, this.local, this.db, this.repository);

  static Future<_Installation> create(String prefix, String deviceName) async {
    final directory = await Directory.systemTemp.createTemp(prefix);
    final local = SqfliteFocusTraceLocalDataSource(
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => directory,
    );
    await local.prepareUsageRecovery();
    final db = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'focus_trace.db'),
    );
    return _Installation(
      directory,
      local,
      db,
      SyncRepositoryImpl(
        executionGate: TestSyncExecutionGate(),
        api: FocusTraceSyncApi(
          baseUrl: Uri.parse(baseUrl),
          credentials: _MemoryCredentialStore(),
        ),
        localDataSource: local,
        usageDataSource: local,
        deviceName: () async => deviceName,
      ),
    );
  }

  final Directory directory;
  final SqfliteFocusTraceLocalDataSource local;
  final Database db;
  final SyncRepositoryImpl repository;

  Future<void> seed(
    String day, {
    required int queriedAtMs,
    required String appKey,
    required String appName,
    required int durationSeconds,
  }) async {
    await db.insert('usage_snapshot_days', {
      'day': day,
      'start_ms': 0,
      'end_ms': 0,
      'timezone_id': 'Europe/London',
      'queried_at_ms': queriedAtMs,
      'covered_until_ms': 0,
      'status': 'reconciled',
    });
    await db.insert('daily_app_usage', {
      'day': day,
      'app_key': appKey,
      'app_name': appName,
      'duration_seconds': durationSeconds,
      'launch_count': 4,
    });
  }

  Future<List<Map<String, Object?>>> usageRows() =>
      db.query('daily_app_usage', orderBy: 'day ASC, app_key ASC');

  Future<void> dispose() async {
    await db.close();
    await local.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}

class _MemoryCredentialStore implements SyncCredentialStore {
  String? _token;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
