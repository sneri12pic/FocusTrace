import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late SqfliteFocusTraceLocalDataSource dataSource;

  setUp(() async {
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('focus_trace_test');
    dataSource = SqfliteFocusTraceLocalDataSource(
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await dataSource.close();
    await tempDir.delete(recursive: true);
  });

  test('daily summaries round-trip, latest snapshot wins', () async {
    final day = DateTime(2026, 7, 12, 15, 30);

    await dataSource.saveDailySummaries(day, const [
      AppUsageSummary(
        appName: 'YouTube',
        packageName: 'com.google.android.youtube',
        totalDurationSeconds: 600,
        percentageOfTotal: 1,
      ),
    ]);

    // A later fetch the same day replaces the snapshot with grown totals.
    await dataSource.saveDailySummaries(day, const [
      AppUsageSummary(
        appName: 'YouTube',
        packageName: 'com.google.android.youtube',
        totalDurationSeconds: 900,
        percentageOfTotal: 0.75,
        launchCount: 7,
      ),
      AppUsageSummary(
        appName: 'Chrome',
        packageName: 'com.android.chrome',
        totalDurationSeconds: 300,
        percentageOfTotal: 0.25,
      ),
    ]);

    final stored = await dataSource.getDailySummaries(DateTime(2026, 7, 12));
    expect(stored, hasLength(2));
    expect(stored.first.appName, 'YouTube');
    expect(stored.first.totalDurationSeconds, 900);
    expect(stored.first.launchCount, 7);
    expect(stored.last.appName, 'Chrome');

    // Other days stay untouched.
    expect(await dataSource.getDailySummaries(DateTime(2026, 7, 11)), isEmpty);
  });

  test('all-time summaries aggregate every stored day', () async {
    await dataSource.saveDailySummaries(DateTime(2026, 7, 11), const [
      AppUsageSummary(
        appName: 'Editor',
        processName: 'editor.exe',
        totalDurationSeconds: 600,
        percentageOfTotal: 0,
        launchCount: 2,
      ),
      AppUsageSummary(
        appName: 'Browser',
        processName: 'browser.exe',
        totalDurationSeconds: 400,
        percentageOfTotal: 0,
        launchCount: 1,
      ),
    ]);
    await dataSource.saveDailySummaries(DateTime(2026, 7, 12), const [
      AppUsageSummary(
        appName: 'Editor',
        processName: 'editor.exe',
        totalDurationSeconds: 900,
        percentageOfTotal: 0,
        launchCount: 3,
      ),
    ]);

    final allTime = await dataSource.getAllTimeSummaries();

    expect(allTime.map((summary) => summary.appName), ['Editor', 'Browser']);
    expect(allTime.first.totalDurationSeconds, 1500);
    expect(allTime.first.launchCount, 5);

    final history = await dataSource.getUsageHistory(
      DateTime(2026, 7, 12),
      DateTime(2026, 7, 13),
    );
    expect(history, hasLength(1));
    expect(history.single.day, DateTime(2026, 7, 12));
    expect(history.single.summary.totalDurationSeconds, 900);
  });

  test('opening an existing version 3 database preserves history', () async {
    final database = await _createDatabase(tempDir, version: 3);
    await database.insert('daily_app_usage', {
      'day': '2026-07-11',
      'app_key': 'com.zhiliaoapp.musically',
      'app_name': 'TikTok',
      'package_name': 'com.zhiliaoapp.musically',
      'process_name': null,
      'duration_seconds': 1800,
      'launch_count': 6,
    });
    await database.close();

    await dataSource.saveDailySummaries(DateTime(2026, 7, 12), const [
      AppUsageSummary(
        appName: 'TikTok',
        packageName: 'com.zhiliaoapp.musically',
        totalDurationSeconds: 900,
        percentageOfTotal: 1,
        launchCount: 3,
      ),
    ]);

    final previousDay = await dataSource.getDailySummaries(
      DateTime(2026, 7, 11),
    );
    expect(previousDay, hasLength(1));
    expect(previousDay.single.appKey, 'com.zhiliaoapp.musically');
    expect(previousDay.single.totalDurationSeconds, 1800);
    expect(previousDay.single.launchCount, 6);

    final migratedEvent = RestrictionEvent(
      id: 'v3-migration-event',
      appKey: 'com.zhiliaoapp.musically',
      appName: 'TikTok',
      type: RestrictionEventType.blocked,
      occurredAt: DateTime(2026, 7, 11, 10),
    );
    await dataSource.insertRestrictionEvent(migratedEvent);
    expect(
      await dataSource.getRestrictionEvents(
        DateTime(2026, 7, 11),
        DateTime(2026, 7, 12),
      ),
      hasLength(1),
    );
  });

  test('version 2 upgrade preserves history and adds launch count', () async {
    final database = await _createDatabase(tempDir, version: 2);
    await database.insert('daily_app_usage', {
      'day': '2026-07-11',
      'app_key': 'com.google.android.youtube',
      'app_name': 'YouTube',
      'package_name': 'com.google.android.youtube',
      'process_name': null,
      'duration_seconds': 2400,
    });
    await database.close();

    final previousDay = await dataSource.getDailySummaries(
      DateTime(2026, 7, 11),
    );

    expect(previousDay, hasLength(1));
    expect(previousDay.single.appKey, 'com.google.android.youtube');
    expect(previousDay.single.totalDurationSeconds, 2400);
    expect(previousDay.single.launchCount, 0);
  });

  test('report intervals and restriction events round-trip', () async {
    final startedAt = DateTime(2026, 7, 11, 8, 30);
    await dataSource.insertUsageIntervals([
      AppUsageInterval(
        id: 'reader:${startedAt.millisecondsSinceEpoch}',
        appKey: 'reader',
        appName: 'Reader',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 45)),
      ),
    ]);
    await dataSource.insertRestrictionEvent(
      RestrictionEvent(
        id: 'blocked-1',
        appKey: 'reader',
        appName: 'Reader',
        type: RestrictionEventType.blocked,
        occurredAt: DateTime(2026, 7, 11, 9, 30),
        reason: 'dailyLimit',
      ),
    );

    final intervals = await dataSource.getUsageIntervals(
      DateTime(2026, 7, 11),
      DateTime(2026, 7, 12),
    );
    final events = await dataSource.getRestrictionEvents(
      DateTime(2026, 7, 11),
      DateTime(2026, 7, 12),
    );

    expect(intervals.single.appName, 'Reader');
    expect(intervals.single.durationSeconds, 2700);
    expect(events.single.type, RestrictionEventType.blocked);
    expect(events.single.reason, 'dailyLimit');
  });
}

Future<Database> _createDatabase(Directory directory, {required int version}) {
  return databaseFactoryFfi.openDatabase(
    p.join(directory.path, 'focus_trace.db'),
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (database, _) async {
        await database.execute('''
CREATE TABLE daily_app_usage (
  day TEXT NOT NULL,
  app_key TEXT NOT NULL,
  app_name TEXT NOT NULL,
  package_name TEXT,
  process_name TEXT,
  duration_seconds INTEGER NOT NULL,
  ${version >= 3 ? 'launch_count INTEGER NOT NULL DEFAULT 0,' : ''}
  PRIMARY KEY (day, app_key)
)
''');
      },
    ),
  );
}
