import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sync repository behaviour against a real HTTP server on localhost.
///
/// The server below is a stand-in for the Spring backend, not a mock object:
/// requests are encoded, sent, parsed and answered for real, so the client's
/// JSON, status handling and token lifecycle are all exercised. The contract it
/// enforces is the one in backend architecture 7.3 and 9.1-9.3. The end-to-end
/// proof against the actual backend lives in `sync_end_to_end_test.dart`.
void main() {
  late Directory directory;
  late SqfliteFocusTraceLocalDataSource local;
  late Database db;
  late _FakeBackend backend;

  setUp(() async {
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
  }) => SyncRepositoryImpl(
    api: FocusTraceSyncApi(
      baseUrl: backend.baseUrl,
      credentials: credentials,
      timeout: const Duration(seconds: 5),
    ),
    localDataSource: local,
    usageDataSource: local,
    deviceName: deviceName,
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
  int? nextUploadStatus;
  bool rejectEveryUpload = false;
  var _issued = 0;

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
        return reply(200, _issueSession());
      case '/api/v1/auth/refresh':
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
