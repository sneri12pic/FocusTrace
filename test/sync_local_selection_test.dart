import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Upload selection, the versionless-day version policy, and the device-local
/// settings boundary (backend architecture 7.2 and 8.2). Real SQLite, no HTTP.
void main() {
  late Directory directory;
  late SqfliteFocusTraceLocalDataSource local;
  late Database db;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('sync_selection');
    local = SqfliteFocusTraceLocalDataSource(
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => directory,
    );
    await local.prepareUsageRecovery();
    db = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'focus_trace.db'),
    );
  });

  tearDown(() async {
    await db.close();
    await local.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  Future<void> insertApp(
    String day,
    String appKey, {
    int durationSeconds = 60,
    int launchCount = 1,
    String? appName,
  }) => db.insert('daily_app_usage', {
    'day': day,
    'app_key': appKey,
    'app_name': appName ?? 'Name $appKey',
    'duration_seconds': durationSeconds,
    'launch_count': launchCount,
  });

  Future<void> insertSnapshot(
    String day, {
    required int queriedAtMs,
    String status = 'reconciled',
    String timezoneId = 'Europe/London',
  }) => db.insert('usage_snapshot_days', {
    'day': day,
    'start_ms': 0,
    'end_ms': 0,
    'timezone_id': timezoneId,
    'queried_at_ms': queriedAtMs,
    'covered_until_ms': 0,
    'status': status,
  });

  group('readSyncUsageDays', () {
    test('offers only days whose version exceeds the watermark', () async {
      await insertSnapshot('2026-09-01', queriedAtMs: 100);
      await insertApp('2026-09-01', 'com.old');
      await insertSnapshot('2026-09-02', queriedAtMs: 300);
      await insertApp('2026-09-02', 'com.new');

      final days = await local.readSyncUsageDays(
        watermarkMs: 200,
        importedVersionMs: 1,
      );

      expect(days.map((day) => day.localDate), ['2026-09-02']);
      expect(days.single.snapshotVersion, 300);
      expect(days.single.timezoneId, 'Europe/London');
      expect(days.single.sourceStatus, 'reconciled');
      expect(days.single.apps.single.appKey, 'com.new');
    });

    test('never offers an unavailable day', () async {
      await insertSnapshot('2026-09-03', queriedAtMs: 900, status: 'unavailable');
      await insertApp('2026-09-03', 'com.hidden');

      expect(
        await local.readSyncUsageDays(watermarkMs: 0, importedVersionMs: 1),
        isEmpty,
      );
    });

    test('offers a measured day that recorded no foreground usage', () async {
      await insertSnapshot('2026-09-04', queriedAtMs: 500, status: 'partial');

      final days = await local.readSyncUsageDays(
        watermarkMs: 0,
        importedVersionMs: 1,
      );

      expect(days.single.localDate, '2026-09-04');
      expect(days.single.apps, isEmpty);
      expect(days.single.sourceStatus, 'partial');
    });

    test('versionless days carry the imported stamp and UTC', () async {
      await insertApp('2026-08-20', 'com.legacy');
      await insertSnapshot('2026-09-05', queriedAtMs: 700);
      await insertApp('2026-09-05', 'com.measured');

      final days = await local.readSyncUsageDays(
        watermarkMs: 0,
        importedVersionMs: 1758000000000,
      );

      final legacy = days.firstWhere((day) => day.localDate == '2026-08-20');
      expect(legacy.snapshotVersion, 1758000000000);
      expect(legacy.sourceStatus, 'imported');
      // usage_snapshot_days is not portable, so an imported or pre-v5 day
      // genuinely has no recorded zone.
      expect(legacy.timezoneId, 'UTC');
      expect(days.map((day) => day.localDate), ['2026-08-20', '2026-09-05']);
    });

    test('a versionless day at or below the watermark is not re-offered', () async {
      await insertApp('2026-08-21', 'com.legacy');

      expect(
        await local.readSyncUsageDays(
          watermarkMs: 5000,
          importedVersionMs: 5000,
        ),
        isEmpty,
      );
      expect(
        await local.readSyncUsageDays(
          watermarkMs: 5000,
          importedVersionMs: 5001,
        ),
        hasLength(1),
      );
    });

    test('app rows stay with their own day', () async {
      await insertSnapshot('2026-09-06', queriedAtMs: 10);
      await insertApp('2026-09-06', 'com.a');
      await insertApp('2026-09-06', 'com.b');
      await insertSnapshot('2026-09-07', queriedAtMs: 20);
      await insertApp('2026-09-07', 'com.c');
      // Outside the selection but inside the date range of the app query.
      await insertSnapshot('2026-09-08', queriedAtMs: 5);
      await insertApp('2026-09-08', 'com.never');

      final days = await local.readSyncUsageDays(
        watermarkMs: 9,
        importedVersionMs: 1,
      );

      expect(days.map((day) => day.localDate), ['2026-09-06', '2026-09-07']);
      expect(days.first.apps.map((app) => app.appKey), ['com.a', 'com.b']);
      expect(days.last.apps.map((app) => app.appKey), ['com.c']);
    });
  });

  group('device-local settings', () {
    test('sync keys are never exported', () async {
      await local.writeSetting(SyncSettingKeys.installationId, 'install-uuid');
      await local.writeSetting(SyncSettingKeys.usageWatermarkMs, '4242');
      await local.writeSetting('tracking_interval_seconds', '30');

      final exported = await local.exportPortableData();
      final keys = exported['settings']!
          .map((row) => row['key'] as String)
          .toList();

      expect(keys, contains('tracking_interval_seconds'));
      expect(keys, isNot(contains(SyncSettingKeys.installationId)));
      expect(keys, isNot(contains(SyncSettingKeys.usageWatermarkMs)));
      expect(keys, isNot(contains('usage_recovery_generation')));
    });

    test('an imported backup cannot clone another installation id', () async {
      await local.writeSetting(SyncSettingKeys.installationId, 'mine');

      await local.importPortableData({
        'settings': [
          {'key': SyncSettingKeys.installationId, 'value': 'theirs'},
          {'key': 'tracking_interval_seconds', 'value': '45'},
        ],
      });

      expect(await local.readSetting(SyncSettingKeys.installationId), 'mine');
      expect(await local.readSetting('tracking_interval_seconds'), '45');
    });

    test('import advances the stamp and resets the watermark', () async {
      await local.writeSetting(SyncSettingKeys.usageWatermarkMs, '999999');
      await local.writeSetting(SyncSettingKeys.importedVersionMs, '1');
      final before = DateTime.now().millisecondsSinceEpoch;

      await local.importPortableData({
        'daily_app_usage': [
          {
            'day': '2026-07-01',
            'app_key': 'com.imported',
            'app_name': 'Imported',
            'duration_seconds': 120,
            'launch_count': 3,
          },
        ],
      });

      expect(await local.readSetting(SyncSettingKeys.usageWatermarkMs), '0');
      final stamp = int.parse(
        (await local.readSetting(SyncSettingKeys.importedVersionMs))!,
      );
      expect(stamp, greaterThanOrEqualTo(before));

      // The imported day must now be offered, under the new stamp. Without the
      // reset it would sit below the old watermark and never be sent again.
      final days = await local.readSyncUsageDays(
        watermarkMs: 0,
        importedVersionMs: stamp,
      );
      expect(days.single.localDate, '2026-07-01');
      expect(days.single.snapshotVersion, stamp);
      expect(days.single.sourceStatus, 'imported');
    });

    test('import rotates the recovery generation and drops snapshot rows', () async {
      await insertSnapshot('2026-09-09', queriedAtMs: 10);
      await local.writeSetting('usage_recovery_generation', 'before');

      await local.importPortableData(const {});

      expect(await db.query('usage_snapshot_days'), isEmpty);
      expect(
        await local.readSetting('usage_recovery_generation'),
        isNot('before'),
      );
    });
  });
}
