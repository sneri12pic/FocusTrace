import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/history-recovery');
  late Directory directory;
  late SqfliteFocusTraceLocalDataSource local;
  late AndroidUsageDataSource platform;
  late UsageRepositoryImpl usage;
  late Database db;
  final day = DateTime(2026, 9, 7);
  final nextDay = DateTime(2026, 9, 8);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('history_recovery');
    local = SqfliteFocusTraceLocalDataSource(
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => directory,
    );
    await local.prepareUsageRecovery();
    db = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'focus_trace.db'),
    );
    platform = AndroidUsageDataSource(channel: channel);
    usage = UsageRepositoryImpl(
      platform: UsagePlatform.android,
      localDataSource: local,
      platformDataSource: platform,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await local.close();
    await directory.delete(recursive: true);
  });

  Future<void> seed(int seconds) => local.saveDailySummaries(day, [
    AppUsageSummary(
      appName: 'Instagram',
      packageName: 'instagram',
      totalDurationSeconds: seconds,
      percentageOfTotal: 1,
    ),
  ]);

  Future<void> markManaged() => db
      .insert('usage_snapshot_days', {
        'day': '2026-09-07',
        'start_ms': day.millisecondsSinceEpoch,
        'end_ms': nextDay.millisecondsSinceEpoch,
        'timezone_id': 'UTC',
        'queried_at_ms': nextDay.millisecondsSinceEpoch + 1200000,
        'covered_until_ms': nextDay.millisecondsSinceEpoch,
        'status': 'reconciled',
      })
      .then((_) {});

  for (final path in ['daily', 'history', 'all-time', 'report']) {
    test(
      '$path awaits native recovery before reading persisted history',
      () async {
        await seed(2400);
        var recoveries = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'recoverUsageHistory') {
                recoveries++;
                // This mock verifies orchestration only. Native aggregation and SQL
                // transactions are exercised by UsageHistoryRecoveryTest.
                expect(await db.getVersion(), 5);
                final args = Map<Object?, Object?>.from(call.arguments as Map);
                expect(args['fromMs'], isA<int>());
                expect(args['toMs'], isA<int>());
                await seed(2940);
                await markManaged();
                return null;
              }
              if (call.method == 'getAppMetadata') return <Object?>[];
              fail('Unexpected channel call: ${call.method}');
            });

        switch (path) {
          case 'daily':
            expect(
              (await usage.getDailySummaries(day)).single.totalDurationSeconds,
              2940,
            );
          case 'history':
            expect(
              (await usage.getUsageHistory(
                day,
                nextDay,
              )).single.summary.totalDurationSeconds,
              2940,
            );
          case 'all-time':
            expect(
              (await usage.getAllTimeSummaries()).single.totalDurationSeconds,
              2940,
            );
          case 'report':
            final reports = ReportRepositoryImpl(
              usageRepository: usage,
              localDataSource: local,
              platformDataSource: platform,
            );
            expect(
              (await reports.loadSourceData(
                day,
                nextDay,
              )).dailyUsage.single.summary.totalDurationSeconds,
              2940,
            );
        }
        expect(recoveries, 1);
      },
    );
  }

  test('failed native recovery returns the existing history', () async {
    await seed(2400);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'recoverUsageHistory') {
            throw PlatformException(code: 'USAGE_RECOVERY_FAILED');
          }
          if (call.method == 'getAppMetadata') return <Object?>[];
          fail('Unexpected channel call: ${call.method}');
        });
    expect(
      (await usage.getDailySummaries(day)).single.totalDurationSeconds,
      2400,
    );
  });

  test(
    'Android live response is not saved again with a Flutter date',
    () async {
      await seed(2940);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'hasUsageAccess') return true;
            if (call.method == 'getTodayUsageStats') {
              return [
                {
                  'packageName': 'instagram',
                  'appName': 'Instagram',
                  'totalTimeInForegroundMs': 2400000,
                },
              ];
            }
            fail('Unexpected channel call: ${call.method}');
          });
      expect(
        (await usage.getTodaySummaries()).single.totalDurationSeconds,
        2400,
      );
      final rows = await db.query('daily_app_usage');
      expect(rows, hasLength(1));
      expect(rows.single['day'], '2026-09-07');
      expect(rows.single['duration_seconds'], 2940);
    },
  );

  test(
    'v4 migration preserves totals and intervals without inventing finalization',
    () async {
      await seed(2400);
      await db.insert('usage_intervals', {
        'id': 'saved',
        'app_key': 'instagram',
        'app_name': 'Instagram',
        'started_at': day.millisecondsSinceEpoch,
        'ended_at': day.millisecondsSinceEpoch + 2400000,
      });
      await db.execute('DROP TABLE usage_snapshot_days');
      await db.setVersion(4);
      await local.close();
      await local.prepareUsageRecovery();
      db = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'focus_trace.db'),
      );
      expect(await db.getVersion(), 5);
      expect(
        (await local.getDailySummaries(day)).single.totalDurationSeconds,
        2400,
      );
      expect(await local.getUsageIntervals(day, nextDay), hasLength(1));
      expect(await db.query('usage_snapshot_days'), isEmpty);
    },
  );

  test(
    'delayed Dart totals and interval writes cannot alter native managed days',
    () async {
      await seed(2940);
      await markManaged();
      await seed(2400);
      await local.insertUsageIntervals([
        AppUsageInterval(
          id: 'stale',
          appKey: 'instagram',
          appName: 'Instagram',
          startedAt: day,
          endedAt: day.add(const Duration(minutes: 40)),
        ),
      ]);
      expect(
        (await local.getDailySummaries(day)).single.totalDurationSeconds,
        2940,
      );
      expect(await db.query('usage_intervals'), isEmpty);
    },
  );

  test(
    'backup import invalidates device evidence and clear removes it',
    () async {
      await seed(2400);
      await markManaged();
      final backup = await local.exportPortableData();
      expect(backup.containsKey('usage_snapshot_days'), isFalse);
      await local.importPortableData(backup);
      final importGeneration = await local.readSetting(
        'usage_recovery_generation',
      );
      expect(importGeneration, isNotEmpty);
      expect(
        (await local.exportPortableData())['settings']!.where(
          (row) => row['key'] == 'usage_recovery_generation',
        ),
        isEmpty,
      );
      expect(await db.query('usage_snapshot_days'), isEmpty);
      expect(
        (await local.getDailySummaries(day)).single.totalDurationSeconds,
        2400,
      );
      await markManaged();
      await local.clearAllData();
      expect(
        await local.readSetting('usage_recovery_generation'),
        isNot(importGeneration),
      );
      expect(await db.query('usage_snapshot_days'), isEmpty);
      expect(await db.query('daily_app_usage'), isEmpty);
    },
  );
  test('fresh and upgraded v5 schemas match exactly', () async {
    final fresh = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    await db.execute('DROP TABLE usage_snapshot_days');
    await db.setVersion(4);
    await local.close();
    await local.prepareUsageRecovery();
    db = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'focus_trace.db'),
    );
    expect(
      await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
      ),
      fresh,
    );
  });

  test(
    'failed v5 migration rolls back version and preserves v4 usage',
    () async {
      await seed(2400);
      await db.execute('DROP TABLE usage_snapshot_days');
      await db.execute(
        'CREATE VIEW usage_snapshot_days AS SELECT day FROM daily_app_usage',
      );
      await db.setVersion(4);
      await local.close();
      await expectLater(
        local.prepareUsageRecovery(),
        throwsA(isA<DatabaseException>()),
      );
      db = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'focus_trace.db'),
      );
      expect(await db.getVersion(), 4);
      expect(
        (await db.query('daily_app_usage')).single['duration_seconds'],
        2400,
      );
      await db.close();
    },
  );

  test(
    'legacy downgrade keeps data and v5 reopening invalidates old evidence',
    () async {
      await seed(2400);
      await markManaged();
      await local.close();
      db = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'focus_trace.db'),
        options: OpenDatabaseOptions(version: 4),
      );
      expect(await db.getVersion(), 4);
      expect(await db.query('usage_snapshot_days'), hasLength(1));
      await db.close();
      await local.prepareUsageRecovery();
      db = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'focus_trace.db'),
      );
      expect(await db.getVersion(), 5);
      expect(
        (await db.query('daily_app_usage')).single['duration_seconds'],
        2400,
      );
      expect(await db.query('usage_snapshot_days'), isEmpty);
    },
  );

  test(
    'this build refuses a newer database without changing its version or data',
    () async {
      await seed(2400);
      await db.setVersion(6);
      await local.close();
      await expectLater(local.prepareUsageRecovery(), throwsStateError);
      db = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'focus_trace.db'),
      );
      expect(await db.getVersion(), 6);
      expect(
        (await db.query('daily_app_usage')).single['duration_seconds'],
        2400,
      );
      await db.close();
    },
  );

  test('report snapshot uses consistent totals and interval data', () async {
    await seed(2400);
    await local.insertUsageIntervals([
      AppUsageInterval(
        id: 'one',
        appKey: 'instagram',
        appName: 'Instagram',
        startedAt: day,
        endedAt: day.add(const Duration(minutes: 40)),
      ),
    ]);
    final report = await local.readReportSnapshot(day, nextDay, day);
    expect(report.dailyUsage.single.summary.totalDurationSeconds, 2400);
    expect(report.intervals.single.durationSeconds, 2400);
  });
}
