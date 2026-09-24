import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_sync_execution_gate.dart';
import 'package:focustrace/src/application/services/background_sync.dart';

/// Sync repository behaviour against a real HTTP server on localhost.
///
/// The server below is a stand-in for the Spring backend, not a mock object:
/// requests are encoded, sent, parsed and answered for real, so the client's
/// JSON, status handling and token lifecycle are all exercised. The contract it
/// enforces is the one in backend architecture 7.3 and 9.1-9.3. The end-to-end
/// proof against the actual backend lives in `sync_end_to_end_test.dart`.
void main() {
  // Needed for the mock method channel below. It also installs an
  // HttpOverrides that answers every request with 400, and this suite talks
  // to a real socket, so the override goes straight back out.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late Directory directory;
  late SqfliteFocusTraceLocalDataSource local;
  late Database db;
  late _FakeBackend backend;
  late TestSyncExecutionGate gate;

  setUp(() async {
    gate = TestSyncExecutionGate();
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('sync_repository');
    local = SqfliteFocusTraceLocalDataSource(
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => directory,
    );
    await local.prepareUsageRecovery();
    db = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'focus_trace.db'),
    );
    backend = await _FakeBackend.start();
  });

  tearDown(() async {
    await backend.stop();
    await db.close();
    await local.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  SyncRepositoryImpl repositoryFor(
    SyncCredentialStore credentials, {
    String deviceName = 'Test device',
    int seed = 7,
    Future<void> Function(bool)? reconcileSchedule,
  }) => SyncRepositoryImpl(
    executionGate: gate,
    reconcileSchedule: reconcileSchedule,
    api: FocusTraceSyncApi(
      baseUrl: backend.baseUrl,
      credentials: credentials,
      timeout: const Duration(seconds: 5),
    ),
    localDataSource: local,
    usageDataSource: local,
    deviceName: () async => deviceName,
    random: Random(seed),
    now: () => DateTime.utc(2026, 9, 19, 12),
  );

  late _MemoryCredentialStore credentials;
  late SyncRepositoryImpl repository;

  setUp(() {
    credentials = _MemoryCredentialStore();
    repository = repositoryFor(credentials);
  });

  Future<void> seedDay(
    String day, {
    required int queriedAtMs,
    String appKey = 'com.example',
    String appName = 'Example',
    int durationSeconds = 600,
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
      'launch_count': 2,
    });
  }

  Future<int?> watermark() async {
    final stored = await local.readSetting(SyncSettingKeys.usageWatermarkMs);
    return stored == null ? null : int.parse(stored);
  }

  group('cross-instance execution', () {
    Future<void> signedInDay() async {
      await repository.signIn(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
    }

    Future<T> queue<T>(Future<T> Function() operation) async {
      final requested = Completer<void>();
      gate.onRequested = () => requested.complete();
      final pending = operation();
      expect(requested.isCompleted, isTrue, reason: 'The contender must reach the gate before checking exclusion.');
      gate.onRequested = null;
      return pending;
    }

    test(
      'two repositories serialize the entire upload and watermark run',
      () async {
        await signedInDay();
        backend.hold('/api/v1/sync/usage-days');
        final first = repository.syncNow();
        await backend.entered!.future;
        final paths = List<String>.of(backend.requestPaths);
        final second = queue(() => repositoryFor(credentials).syncNow());
        // queue's notification proves acquisition was attempted, not just scheduled.
        await Future<void>.value();
        expect(backend.requestPaths, paths);
        expect(await watermark(), isNull);
        backend.proceed!.complete();
        expect((await first).uploadedDays, 1);
        expect((await second).uploadedDays, 0);
        expect(backend.uploadCount, 1);
        expect(await watermark(), 1000);
      },
    );

    test(
      'sync first then logout leaves no session and later sync sends nothing',
      () async {
        await signedInDay();
        backend.hold('/api/v1/sync/usage-days');
        final first = repository.syncNow();
        await backend.entered!.future;
        final logout = queue(() => repositoryFor(credentials).signOut());
        await Future<void>.value();
        expect(backend.requestPaths, isNot(contains('/api/v1/auth/logout')));
        backend.proceed!.complete();
        expect((await first).succeeded, isTrue);
        await logout;
        expect(credentials.refreshToken, isNull);
        final count = backend.requestPaths.length;
        expect(
          (await repository.syncNow()).reason,
          SyncFailureReason.notSignedIn,
        );
        expect(backend.requestPaths.length, count);
      },
    );

    test(
      'logout first then a cached repository cannot restore the old session',
      () async {
        await signedInDay();
        backend.hold('/api/v1/auth/logout');
        final logout = repositoryFor(credentials).signOut();
        await backend.entered!.future;
        final sync = queue(repository.syncNow);
        await Future<void>.value();
        expect(backend.uploadCount, 0);
        backend.proceed!.complete();
        await logout;
        expect((await sync).reason, SyncFailureReason.notSignedIn);
        expect(credentials.refreshToken, isNull);
        expect(backend.uploadCount, 0);
        final count = backend.requestPaths.length;
        await expectLater(
          repository.readRemoteHistory(
            from: DateTime.utc(2026, 9, 1),
            to: DateTime.utc(2026, 9, 20),
          ),
          throwsA(isA<SyncApiException>()),
        );
        expect(backend.requestPaths.length, count);
      },
    );

    for (final create in [false, true]) {
      test(
        'session ${create ? 'creation' : 'sign-in'} waits for an active sync',
        () async {
          await signedInDay();
          backend.hold('/api/v1/sync/usage-days');
          final sync = repository.syncNow();
          await backend.entered!.future;
          final other = repositoryFor(credentials);
          final before = backend.requestPaths.length;
          final auth = queue(
            () => create
                ? other.createAccount(email: 'b@example.com', password: 'pw')
                : other.signIn(email: 'b@example.com', password: 'pw'),
          );
          await Future<void>.value();
          expect(backend.requestPaths.length, before);
          backend.proceed!.complete();
          await sync;
          await auth;
          expect(await repository.accountEmail(), 'b@example.com');
          final rotations = backend.refreshCount;
          // The old repository must discard its cached access token after replacement.
          await repository.readRemoteHistory(
            from: DateTime.utc(2026, 9, 1),
            to: DateTime.utc(2026, 9, 20),
          );
          expect(backend.refreshCount, rotations + 1);
        },
      );
    }

    test(
      'sign-in first completes persistence before a queued sync enters',
      () async {
        await seedDay('2026-09-17', queriedAtMs: 1000);
        backend.hold('/api/v1/auth/login');
        final auth = repository.signIn(email: 'a@example.com', password: 'pw');
        await backend.entered!.future;
        final sync = queue(() => repositoryFor(credentials).syncNow());
        await Future<void>.value();
        expect(credentials.refreshToken, isNull);
        expect(backend.uploadCount, 0);
        backend.proceed!.complete();
        await auth;
        expect((await sync).succeeded, isTrue);
        expect(backend.uploadCount, 1);
      },
    );

    test('failed sync releases so logout can finish', () async {
      await signedInDay();
      backend.hold('/api/v1/sync/usage-days');
      backend.nextUploadStatus = 503;
      final sync = repository.syncNow();
      await backend.entered!.future;
      final logout = queue(() => repositoryFor(credentials).signOut());
      backend.proceed!.complete();
      expect((await sync).succeeded, isFalse);
      await logout;
      expect(credentials.refreshToken, isNull);
    });

    test('thrown sign-in and logout work releases the gate', () async {
      backend.malformedLogin = true;
      await expectLater(
        repository.signIn(email: 'a@example.com', password: 'pw'),
        throwsA(isA<TypeError>()),
      );
      backend.malformedLogin = false;
      await signedInDay();
      backend.malformedRefresh = true;
      await expectLater(
        repositoryFor(credentials).signOut(),
        throwsA(isA<TypeError>()),
      );
      expect(credentials.refreshToken, isNull);
      expect(await repository.isSignedIn, isFalse);
      expect(
        (await repository.syncNow()).reason,
        SyncFailureReason.notSignedIn,
      );
    });
  });

  group('background orchestration', () {
    test('disabled worker does no network or upload even when signed in', () async {
      await repository.signIn(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      backend.requestPaths.clear();
      expect(await runBackgroundSync(repository), 'success');
      expect(backend.requestPaths, isEmpty);
      expect(await watermark(), isNull);
    });

    test('enabling, repeated enable, disabling and logout reconcile authoritative consent', () async {
      final schedules = <bool>[];
      final subject = repositoryFor(credentials, reconcileSchedule: (enabled) async {
        expect(await local.readSetting(SyncSettingKeys.enabled), '$enabled');
        schedules.add(enabled);
      });
      await subject.setSyncEnabled(true);
      await subject.setSyncEnabled(true);
      await subject.setSyncEnabled(false);
      await subject.setSyncEnabled(true);
      await subject.signOut();
      expect(schedules, [true, true, false, true, false]);
      expect(await subject.isSyncEnabled(), isFalse);
      expect(await runBackgroundSync(subject), 'success');
      expect(backend.requestPaths, isEmpty);
    });

    test('background upload uses model name while UUID stays authoritative', () async {
      final subject = repositoryFor(credentials, deviceName: 'SM-A366B');
      await subject.signIn(email: 'a@example.com', password: 'pw');
      await subject.setSyncEnabled(true);
      final id = await subject.installationId();
      await seedDay('2026-09-17', queriedAtMs: 1000);
      expect(await runBackgroundSync(subject), 'success');
      expect(backend.devices.single.displayName, 'SM-A366B');
      expect(backend.devices.single.deviceId, id);
      expect(await subject.installationId(), id);
      expect(await runBackgroundSync(repositoryFor(credentials)), 'success');
      expect(backend.uploadCount, 1);
    });

    for (final status in [400, 500, 502, 503, 504, 408, 429, 501]) {
      test('background classifies upload HTTP $status without guessing unknown retry', () async {
        await repository.signIn(email: 'a@example.com', password: 'pw');
        await repository.setSyncEnabled(true);
        await seedDay('2026-09-17', queriedAtMs: 1000);
        backend.nextUploadStatus = status;
        expect(await runBackgroundSync(repository), status == 400 ? 'success' : status == 501 ? 'failure' : 'retry');
      });
    }

    test('revoked and signed-out background sessions end without retries', () async {
      await repository.setSyncEnabled(true);
      expect(await runBackgroundSync(repository), 'success');
      await credentials.writeRefreshToken('revoked-test-session');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      expect(await runBackgroundSync(repositoryFor(credentials)), 'success');
      expect(credentials.refreshToken, isNull);
    });

    test('network transport failure retries but unconfigured builds do not', () async {
      await repository.signIn(email: 'a@example.com', password: 'pw');
      await repository.setSyncEnabled(true);
      await seedDay('2026-09-17', queriedAtMs: 1000);
      await backend.stop();
      expect(await runBackgroundSync(repository), 'retry');
      expect(await runBackgroundSync(null), 'success');
    });

    test('queued background work checks opt-out after acquiring the manual gate', () async {
      await repository.setSyncEnabled(true);
      final blocker = Completer<void>();
      final entered = Completer<void>();
      final first = gate.run(() async { entered.complete(); await blocker.future; });
      await entered.future;
      final off = repository.setSyncEnabled(false);
      final background = runBackgroundSync(repositoryFor(credentials));
      blocker.complete();
      await first;
      await off;
      expect(await background, 'success');
      expect(backend.requestPaths, isEmpty);
    });

    test('background owns gate, manual and logout wait without session resurrection', () async {
      await repository.signIn(email: 'a@example.com', password: 'pw');
      await repository.setSyncEnabled(true);
      await seedDay('2026-09-17', queriedAtMs: 1000);
      backend.hold('/api/v1/sync/usage-days');
      final background = runBackgroundSync(repositoryFor(credentials));
      await backend.entered!.future;
      final manual = repository.syncNow();
      final logout = repository.signOut();
      expect(backend.uploadCount, 0);
      backend.proceed!.complete();
      expect(await background, 'success');
      expect((await manual).uploadedDays, 0);
      await logout;
      expect(credentials.refreshToken, isNull);
      expect(await runBackgroundSync(repositoryFor(credentials)), 'success');
      expect(backend.uploadCount, 1);
    });

    test('closing a headless database connection leaves foreground usable', () async {
      final background = SqfliteFocusTraceLocalDataSource(
        singleInstance: false,
        databaseFactoryOverride: databaseFactoryFfi,
        applicationSupportDirectoryProvider: () async => directory,
      );
      await background.writeSetting('connection_test', 'ok');
      await background.close();
      expect(await local.readSetting('connection_test'), 'ok');
      await local.writeSetting('connection_test', 'still open');
    });
  });

  group('installation identity', () {
    test('is a random v4 UUID and is stable across calls', () async {
      final first = await repository.installationId();

      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(await repository.installationId(), first);
      expect(await local.readSetting(SyncSettingKeys.installationId), first);
    });

    test('two installations generate different ids', () async {
      final mine = await repository.installationId();
      await local.writeSetting(SyncSettingKeys.installationId, '');
      final theirs = await repositoryFor(
        credentials,
        seed: 99,
      ).installationId();

      expect(theirs, isNot(mine));
    });
  });

  group('syncNow', () {
    test('does nothing at all when signed out', () async {
      await seedDay('2026-09-17', queriedAtMs: 1000);

      final result = await repository.syncNow();

      expect(result.succeeded, isFalse);
      expect(backend.requestPaths, isEmpty);
      expect(await watermark(), isNull);
      expect(await db.query('daily_app_usage'), hasLength(1));
    });

    test('registers the device, uploads, and advances the watermark', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      await seedDay('2026-09-18', queriedAtMs: 2000);

      final result = await repository.syncNow();

      expect(result.succeeded, isTrue);
      expect(result.uploadedDays, 2);
      expect(result.countOf(SyncDayOutcome.applied), 2);
      expect(backend.devices, hasLength(1));
      expect(backend.devices.single.displayName, 'Test device');
      expect(backend.storedDays, hasLength(2));
      expect(await watermark(), 2000);
      // Sync is a copy, never a move.
      expect(await db.query('daily_app_usage'), hasLength(2));
    });

    test('re-running sends nothing and creates no second device', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      await repository.syncNow();
      final uploadsAfterFirst = backend.uploadCount;

      final second = await repository.syncNow();

      expect(second.succeeded, isTrue);
      expect(second.uploadedDays, 0);
      expect(second.results, isEmpty);
      expect(backend.uploadCount, uploadsAfterFirst);
      expect(backend.devices, hasLength(1));
      expect(backend.storedDays, hasLength(1));
    });

    test('a lost watermark re-uploads safely as DUPLICATE', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      await repository.syncNow();

      await local.writeSetting(SyncSettingKeys.usageWatermarkMs, '0');
      final again = await repository.syncNow();

      expect(again.countOf(SyncDayOutcome.duplicate), 1);
      expect(backend.storedDays, hasLength(1));
      expect(backend.storedDays.single.apps, hasLength(1));
    });

    test('a newer snapshot supersedes the stored day wholesale', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000, appKey: 'com.first');
      await repository.syncNow();

      await db.delete('usage_snapshot_days');
      await db.delete('daily_app_usage');
      await seedDay('2026-09-17', queriedAtMs: 3000, appKey: 'com.second');
      final result = await repository.syncNow();

      expect(result.countOf(SyncDayOutcome.applied), 1);
      expect(backend.storedDays.single.apps.single['appKey'], 'com.second');
      expect(await watermark(), 3000);
    });

    test('a transient failure keeps the watermark and the local record', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      backend.nextUploadStatus = 503;

      final failed = await repository.syncNow();

      expect(failed.succeeded, isFalse);
      expect(await watermark(), isNull);
      expect(await db.query('daily_app_usage'), hasLength(1));

      final retried = await repository.syncNow();
      expect(retried.succeeded, isTrue);
      expect(retried.countOf(SyncDayOutcome.applied), 1);
      expect(await watermark(), 1000);
    });

    test('a deterministic 400 is counted, not retried forever', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      backend.rejectEveryUpload = true;

      final rejected = await repository.syncNow();

      expect(rejected.succeeded, isTrue);
      expect(rejected.rejectedDays, 1);
      expect(rejected.uploadedDays, 0);
      expect(await watermark(), 1000);
      expect(await db.query('daily_app_usage'), hasLength(1));

      // The whole point: the same request is not sent again next run.
      final uploads = backend.uploadCount;
      backend.rejectEveryUpload = false;
      expect((await repository.syncNow()).uploadedDays, 0);
      expect(backend.uploadCount, uploads);
    });

    test('an offline backend is reported, never thrown', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      await backend.stop();

      final result = await repository.syncNow();

      expect(result.succeeded, isFalse);
      expect(await watermark(), isNull);
      expect(await db.query('daily_app_usage'), hasLength(1));
    });
  });

  group('client sanitization', () {
    test('drops NUL and unpaired surrogates, truncates deterministically', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay(
        '2026-09-17',
        queriedAtMs: 1000,
        appKey: 'com.example',
        appName: 'Bad\u0000Name\ud800 ${'x' * 300}',
      );

      await repository.syncNow();

      final name = backend.storedDays.single.apps.single['appName']! as String;
      expect(name.contains('\u0000'), isFalse);
      expect(name.codeUnits.any((unit) => unit >= 0xD800 && unit <= 0xDFFF),
          isFalse);
      expect(name.length, lessThanOrEqualTo(200));
      expect(name, startsWith('BadName'));
    });

    test('leaves out days the contract cannot accept', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      // Before FocusTrace existed, and beyond the server's UTC today + 1.
      await seedDay('2025-12-31', queriedAtMs: 1000);
      await seedDay('2027-01-01', queriedAtMs: 1100);
      await seedDay('2026-09-17', queriedAtMs: 1200);

      final result = await repository.syncNow();

      expect(result.uploadedDays, 1);
      expect(backend.storedDays.single.localDate, '2026-09-17');
      // The local record is untouched: filtering applies to the upload only.
      expect(await db.query('daily_app_usage'), hasLength(3));
    });

    test('caps a day at 500 apps, keeping the longest, in appKey order', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await db.insert('usage_snapshot_days', {
        'day': '2026-09-17',
        'start_ms': 0,
        'end_ms': 0,
        'timezone_id': 'Europe/London',
        'queried_at_ms': 1000,
        'covered_until_ms': 0,
        'status': 'reconciled',
      });
      for (var i = 0; i < 600; i++) {
        await db.insert('daily_app_usage', {
          'day': '2026-09-17',
          'app_key': 'com.app${i.toString().padLeft(3, '0')}',
          'app_name': 'App $i',
          'duration_seconds': i,
          'launch_count': 0,
        });
      }

      await repository.syncNow();

      final apps = backend.storedDays.single.apps;
      expect(apps, hasLength(500));
      // The 100 shortest were dropped, not the last 100 by key.
      expect(apps.first['appKey'], 'com.app100');
      expect(
        apps.map((app) => app['appKey'] as String).toList(),
        orderedEquals(
          (apps.map((app) => app['appKey'] as String).toList()..sort()),
        ),
      );
    });

    test('clamps an impossible duration instead of failing the day', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000, durationSeconds: 999999);

      await repository.syncNow();

      expect(backend.storedDays.single.apps.single['durationSeconds'], 90000);
    });
  });

  group('tokens', () {
    test('never leave a readable copy in the database', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      await repository.syncNow();

      final settings = await db.query('settings');
      final values = settings.map((row) => row['value'] as String).toList();
      expect(credentials.refreshToken, isNotNull);
      expect(values, isNot(contains(credentials.refreshToken)));
      for (final value in values) {
        expect(value.contains('token'), isFalse);
      }
    });

    test('an expired access token is refreshed once and the request replays',
        () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      final before = backend.refreshCount;
      backend.expireAccessTokens();

      final result = await repository.syncNow();

      expect(result.succeeded, isTrue);
      expect(backend.refreshCount, before + 1);
      expect(backend.storedDays, hasLength(1));
    });

    test('concurrent requests share a single refresh', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      final before = backend.refreshCount;
      backend.expireAccessTokens();

      await Future.wait([
        repository.readRemoteHistory(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 20),
        ),
        repository.readRemoteHistory(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 20),
        ),
        repository.readRemoteHistory(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 20),
        ),
      ]);

      // Racing the rotation would revoke the chain by replay detection.
      expect(backend.refreshCount, before + 1);
    });

    test('signing out forgets the session and leaves local data alone', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);

      await repository.signOut();

      expect(await repository.isSignedIn, isFalse);
      expect(credentials.refreshToken, isNull);
      expect((await repository.syncNow()).succeeded, isFalse);
      expect(await db.query('daily_app_usage'), hasLength(1));
    });
  });

  group('account deletion', () {
    const keys = [
      SyncSettingKeys.installationId,
      SyncSettingKeys.usageWatermarkMs,
      SyncSettingKeys.importedVersionMs,
      SyncSettingKeys.enabled,
      SyncSettingKeys.lastSuccessMs,
      SyncSettingKeys.accountEmail,
      'unrelated_local_setting',
    ];

    Future<Map<String, String?>> settings() async => {
      for (final key in keys) key: await local.readSetting(key),
    };

    late List<bool> schedules;
    late SyncRepositoryImpl subject;

    /// Signed in, opted in, two local days uploaded, an unrelated local setting.
    Future<void> syncedAccount() async {
      schedules = [];
      subject = repositoryFor(
        credentials,
        reconcileSchedule: (enabled) async => schedules.add(enabled),
      );
      await subject.signIn(email: 'a@example.com', password: 'pw');
      await subject.setSyncEnabled(true);
      await seedDay('2026-09-16', queriedAtMs: 1000);
      await seedDay('2026-09-17', queriedAtMs: 2000);
      await local.writeSetting('unrelated_local_setting', 'kept');
      final run = await subject.syncNow();
      expect(run.countOf(SyncDayOutcome.applied), 2);
      expect(await watermark(), 2000);
      schedules.clear();
    }

    test('success deletes the cloud account and resets only account state', () async {
      await syncedAccount();
      final before = await settings();

      await subject.deleteAccount(password: 'pw');

      expect(backend.deleteCount, 1);
      expect(backend.devices, isEmpty);
      expect(credentials.refreshToken, isNull);
      expect(await subject.isSignedIn, isFalse);
      final after = await settings();
      // Account-scoped: reset.
      expect(after[SyncSettingKeys.enabled], 'false');
      expect(after[SyncSettingKeys.accountEmail], '');
      expect(await subject.lastSuccessfulSyncAt(), isNull);
      expect(after[SyncSettingKeys.usageWatermarkMs], '0');
      // Installation, local-content and unrelated state: untouched.
      for (final key in [
        SyncSettingKeys.installationId,
        SyncSettingKeys.importedVersionMs,
        'unrelated_local_setting',
      ]) {
        expect(after[key], before[key], reason: key);
      }
      expect(await db.query('daily_app_usage'), hasLength(2));
      expect(await db.query('usage_snapshot_days'), hasLength(2));
      // Scheduling stopped before the request and stays stopped.
      expect(schedules, [false, false]);
      backend.requestPaths.clear();
      expect((await subject.syncNow()).succeeded, isFalse);
      expect(backend.requestPaths, isEmpty);
    });

    test('a wrong password changes nothing locally and keeps sync scheduled', () async {
      await syncedAccount();
      final before = await settings();

      await expectLater(
        subject.deleteAccount(password: 'wrong'),
        throwsA(isA<SyncAuthException>().having(
          (e) => e.failure, 'failure', SyncAuthFailure.invalidCredentials,
        )),
      );

      expect(await settings(), before);
      expect(credentials.refreshToken, isNotNull);
      expect(backend.deleteCount, 0);
      expect(schedules, [false, true]);
      expect((await subject.syncNow()).succeeded, isTrue);
    });

    test('an unreachable server keeps the session and only resets the watermark', () async {
      await syncedAccount();
      final before = await settings();
      await backend.stop();

      await expectLater(
        subject.deleteAccount(password: 'pw'),
        throwsA(isA<SyncAuthException>().having(
          (e) => e.failure, 'failure', SyncAuthFailure.offline,
        )),
      );

      final after = await settings();
      expect(after[SyncSettingKeys.usageWatermarkMs], '0',
          reason: 'the deletion may have committed with its response lost');
      expect({...after}..remove(SyncSettingKeys.usageWatermarkMs),
          {...before}..remove(SyncSettingKeys.usageWatermarkMs));
      expect(credentials.refreshToken, isNotNull);
      expect(schedules, [false, true]);
    });

    test('a rejected session is reported without clearing account state', () async {
      await syncedAccount();
      final fresh = repositoryFor(credentials);
      await credentials.writeRefreshToken('revoked-test-session');

      await expectLater(
        fresh.deleteAccount(password: 'pw'),
        throwsA(isA<SyncAuthException>().having(
          (e) => e.failure, 'failure', SyncAuthFailure.sessionExpired,
        )),
      );

      expect(credentials.refreshToken, isNull);
      expect(backend.deleteCount, 0);
      expect(await local.readSetting(SyncSettingKeys.accountEmail), 'a@example.com');
    });

    test('account B after deleting account A uploads the existing local history', () async {
      await syncedAccount();
      final installation = await subject.installationId();
      await subject.deleteAccount(password: 'pw');

      await subject.signIn(email: 'b@example.com', password: 'pw');
      await subject.setSyncEnabled(true);
      final run = await subject.syncNow();

      expect(run.succeeded, isTrue);
      expect(run.countOf(SyncDayOutcome.applied), 2,
          reason: 'B must not inherit A\'s upload watermark');
      expect(backend.storedDays, hasLength(2));
      expect(backend.devices.single.deviceId, installation);
      expect(await subject.installationId(), installation);
    });

    test('deletion queues on the shared gate behind running work', () async {
      await syncedAccount();
      final blocker = Completer<void>();
      final entered = Completer<void>();
      final holder = gate.run(() async {
        entered.complete();
        await blocker.future;
      });
      await entered.future;
      backend.requestPaths.clear();

      final deletion = subject.deleteAccount(password: 'pw');
      await Future<void>.delayed(Duration.zero);
      expect(backend.requestPaths, isEmpty);
      expect(schedules, isEmpty, reason: 'nothing runs before the gate is granted');

      blocker.complete();
      await holder;
      await deletion;
      expect(backend.deleteCount, 1);
    });

    test('a background run in flight finishes first and nothing syncs after deletion', () async {
      await syncedAccount();
      await seedDay('2026-09-18', queriedAtMs: 3000);
      backend.hold('/api/v1/sync/usage-days');
      final background = runBackgroundSync(repositoryFor(credentials));
      await backend.entered!.future;

      final deletion = subject.deleteAccount(password: 'pw');
      await Future<void>.delayed(Duration.zero);
      expect(backend.deleteCount, 0);
      backend.proceed!.complete();
      expect(await background, 'success');
      await deletion;
      expect(backend.deleteCount, 1);

      // Stale or repeated background callbacks: no credential, no consent.
      backend.requestPaths.clear();
      for (var i = 0; i < 2; i++) {
        expect(await runBackgroundSync(repositoryFor(credentials)), 'success');
      }
      expect(backend.requestPaths, isEmpty);
      expect(await subject.isSyncEnabled(), isFalse);
      expect(credentials.refreshToken, isNull);
      expect(schedules.last, isFalse);
    });
  });

  group('readRemoteHistory', () {
    test('returns the source device with every day', () async {
      await repository.createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      await repository.syncNow();

      final history = await repository.readRemoteHistory(
        from: DateTime.utc(2026, 9, 1),
        to: DateTime.utc(2026, 9, 20),
      );

      expect(history, hasLength(1));
      expect(history.single.deviceName, 'Test device');
      expect(history.single.deviceId, await repository.installationId());
      expect(history.single.localDate, '2026-09-17');
      expect(history.single.apps.single.appKey, 'com.example');
    });
  });

  /// The Android store against a stand-in for `SecureCredentialStore.kt`.
  ///
  /// [nativeStore] is the only thing that survives between the repositories
  /// below, exactly as the encrypted SharedPreferences entry is the only thing
  /// that survives a process death. Rebuilding the store, the API and the
  /// repository from it is a restart: every Dart object is new.
  group('credential persistence', () {
    const channel = MethodChannel('focustrace/sync');
    late Map<String, String> nativeStore;
    late bool keystoreUnavailable;

    setUp(() {
      nativeStore = <String, String>{};
      keystoreUnavailable = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (keystoreUnavailable) {
              throw PlatformException(code: 'KEYSTORE_UNAVAILABLE');
            }
            switch (call.method) {
              case 'readSyncCredential':
                return nativeStore['refresh_token'];
              case 'writeSyncCredential':
                nativeStore['refresh_token'] = call.arguments as String;
                return null;
              case 'clearSyncCredential':
                nativeStore.remove('refresh_token');
                return null;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    SyncRepositoryImpl restarted() =>
        repositoryFor(const SecureSyncCredentialStore());

    test('a token outlives the objects that wrote it', () async {
      await restarted().createAccount(email: 'a@example.com', password: 'pw');

      expect(nativeStore['refresh_token'], isNotNull);
      // A different store instance, reading what the process left behind.
      expect(
        await const SecureSyncCredentialStore().readRefreshToken(),
        nativeStore['refresh_token'],
      );
    });

    test('a restart is authenticated without signing in again', () async {
      await restarted().createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);

      final afterRestart = restarted();

      expect(await afterRestart.isSignedIn, isTrue);
      // Succeeding proves the restored token still buys an access token: the
      // restart re-authenticated for real, it did not just find a string.
      expect((await afterRestart.syncNow()).succeeded, isTrue);
      expect(backend.storedDays, hasLength(1));
    });

    test('the password is never persisted', () async {
      await restarted().createAccount(
        email: 'a@example.com',
        password: 'correct horse battery staple',
      );

      expect(nativeStore.values, isNot(contains(contains('horse'))));
      expect(nativeStore.keys, ['refresh_token']);
    });

    test('signing out deletes the persisted credential', () async {
      final repository = restarted();
      await repository.createAccount(email: 'a@example.com', password: 'pw');

      await repository.signOut();

      expect(nativeStore, isEmpty);
      expect(await restarted().isSignedIn, isFalse);
    });

    test('a revoked persisted credential fails closed', () async {
      await restarted().createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      // Rotated away, expired, or killed by the server's replay detection.
      nativeStore['refresh_token'] = 'revoked-token';

      final repository = restarted();
      final result = await repository.syncNow();

      expect(result.succeeded, isFalse);
      expect(backend.storedDays, isEmpty);
      // Dead, so it is gone rather than presented again on every run.
      expect(nativeStore, isEmpty);
      expect(await repository.isSignedIn, isFalse);
      expect(await restarted().isSignedIn, isFalse);
    });

    test('an unreadable keystore leaves the app unauthenticated', () async {
      await restarted().createAccount(email: 'a@example.com', password: 'pw');
      await seedDay('2026-09-17', queriedAtMs: 1000);
      keystoreUnavailable = true;

      final repository = restarted();

      expect(await repository.isSignedIn, isFalse);
      expect((await repository.syncNow()).succeeded, isFalse);
    });

    test('an unwritable keystore does not fail the sign-in', () async {
      keystoreUnavailable = true;

      // The session degrades to the process lifetime; it does not throw.
      await restarted().createAccount(email: 'a@example.com', password: 'pw');

      expect(nativeStore, isEmpty);
    });
  });
}

class _MemoryCredentialStore implements SyncCredentialStore {
  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String token) async => refreshToken = token;

  @override
  Future<void> clear() async => refreshToken = null;
}

class _StoredDay {
  _StoredDay(this.deviceId, this.localDate, this.version, this.apps);

  final String deviceId;
  final String localDate;
  int version;
  List<Map<String, Object?>> apps;
}

class _Device {
  _Device(this.deviceId, this.displayName);

  final String deviceId;
  String displayName;
}

/// A minimal stand-in for the Spring backend, answering real HTTP.
class _FakeBackend {
  _FakeBackend(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeBackend> start() async =>
      _FakeBackend(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  final List<String> requestPaths = [];
  final List<_Device> devices = [];
  final List<_StoredDay> storedDays = [];
  final Set<String> _liveAccessTokens = {};
  final Set<String> _liveRefreshTokens = {};

  int uploadCount = 0;
  int refreshCount = 0;
  int deleteCount = 0;

  /// The account's password, for D19's confirmation. The fake holds one account.
  String accountPassword = 'pw';
  int? nextUploadStatus;
  bool rejectEveryUpload = false;
  var _issued = 0;
  bool malformedLogin = false;
  bool malformedRefresh = false;
  String? heldPath;
  Completer<void>? entered;
  Completer<void>? proceed;

  void hold(String path) {
    heldPath = path;
    entered = Completer<void>();
    proceed = Completer<void>();
  }


  /// Makes every outstanding access token stale, as expiry would.
  void expireAccessTokens() => _liveAccessTokens.clear();

  Future<void> stop() => _server.close(force: true);

  Map<String, Object?> _issueSession() {
    final access = 'access-token-${_issued++}';
    final refresh = 'refresh-token-${_issued++}';
    _liveAccessTokens.add(access);
    _liveRefreshTokens.add(refresh);
    return {
      'accessToken': access,
      'expiresIn': 900,
      'refreshToken': refresh,
    };
  }

  bool _authorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    return header != null &&
        header.startsWith('Bearer ') &&
        _liveAccessTokens.contains(header.substring(7));
  }

  Future<void> _handle(HttpRequest request) async {
    requestPaths.add(request.uri.path);
    if (request.uri.path == heldPath) {
      heldPath = null;
      entered!.complete();
      await proceed!.future;
    }
    final raw = await utf8.decoder.bind(request).join();
    final body = raw.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(raw) as Map<String, Object?>;

    Future<void> reply(int status, [Object? json]) async {
      request.response.statusCode = status;
      if (json != null) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(json));
      }
      await request.response.close();
    }

    switch (request.uri.path) {
      case '/api/v1/auth/register':
        return reply(201, {'userId': 'user-1'});
      case '/api/v1/auth/login':
        if (malformedLogin) return reply(200, <String, Object?>{});
        return reply(200, _issueSession());
      case '/api/v1/auth/refresh':
        if (malformedRefresh) return reply(200, <String, Object?>{});
        refreshCount++;
        final presented = body['refreshToken'] as String?;
        if (presented == null || !_liveRefreshTokens.remove(presented)) {
          return reply(401);
        }
        return reply(200, _issueSession());
      case '/api/v1/auth/logout':
        if (!_authorized(request)) return reply(401);
        _liveRefreshTokens.remove(body['refreshToken']);
        return reply(204);
      case '/api/v1/account/delete':
        if (!_authorized(request)) return reply(401);
        if (body['password'] != accountPassword) return reply(403);
        // The cascade: the account, its sessions, devices and usage are gone.
        deleteCount++;
        devices.clear();
        storedDays.clear();
        _liveAccessTokens.clear();
        _liveRefreshTokens.clear();
        return reply(204);
      case '/api/v1/devices':
        if (!_authorized(request)) return reply(401);
        final deviceId = body['deviceId']! as String;
        final displayName = body['displayName']! as String;
        final existing = devices
            .where((device) => device.deviceId == deviceId)
            .firstOrNull;
        if (existing != null) {
          existing.displayName = displayName;
          return reply(200, {'deviceId': deviceId});
        }
        devices.add(_Device(deviceId, displayName));
        return reply(201, {'deviceId': deviceId});
      case '/api/v1/sync/usage-days':
        if (!_authorized(request)) return reply(401);
        uploadCount++;
        final forced = nextUploadStatus;
        nextUploadStatus = null;
        if (forced != null) return reply(forced);
        if (rejectEveryUpload) return reply(400, {'detail': 'rejected'});
        return reply(200, {'results': _applyUpload(body)});
      case '/api/v1/usage':
        if (!_authorized(request)) return reply(401);
        return reply(200, {
          'days': [
            for (final day in storedDays)
              {
                'deviceId': day.deviceId,
                'deviceName': devices
                    .firstWhere((device) => device.deviceId == day.deviceId)
                    .displayName,
                'localDate': day.localDate,
                'timezoneId': 'Europe/London',
                'snapshotVersion': day.version,
                'apps': day.apps,
              },
          ],
        });
      default:
        return reply(404);
    }
  }

  /// The guarded upsert of architecture 7.3, in miniature.
  List<Map<String, Object?>> _applyUpload(Map<String, Object?> body) {
    final deviceId = body['deviceId']! as String;
    final results = <Map<String, Object?>>[];
    for (final day in (body['days']! as List).cast<Map<String, Object?>>()) {
      final localDate = day['localDate']! as String;
      final version = (day['snapshotVersion']! as num).toInt();
      final apps = (day['apps']! as List).cast<Map<String, Object?>>();
      final stored = storedDays
          .where(
            (candidate) =>
                candidate.deviceId == deviceId &&
                candidate.localDate == localDate,
          )
          .firstOrNull;
      if (stored == null) {
        storedDays.add(_StoredDay(deviceId, localDate, version, apps));
        results.add({
          'localDate': localDate,
          'outcome': 'APPLIED',
          'storedVersion': version,
        });
      } else if (version > stored.version) {
        stored
          ..version = version
          ..apps = apps;
        results.add({
          'localDate': localDate,
          'outcome': 'APPLIED',
          'storedVersion': version,
        });
      } else if (version < stored.version) {
        results.add({
          'localDate': localDate,
          'outcome': 'STALE',
          'storedVersion': stored.version,
        });
      } else {
        final same = jsonEncode(stored.apps) == jsonEncode(apps);
        results.add({
          'localDate': localDate,
          'outcome': same ? 'DUPLICATE' : 'CONFLICT',
          'storedVersion': stored.version,
        });
      }
    }
    return results;
  }
}
