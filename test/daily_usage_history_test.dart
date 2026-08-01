import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
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
}
