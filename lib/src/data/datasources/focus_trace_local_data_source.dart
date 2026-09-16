import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/models/app_usage_interval.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/models/restriction_event.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/report_repository.dart';

abstract class FocusTraceLocalDataSource {
  Future<void> insertSession(UsageSession session);

  Future<void> insertSessions(List<UsageSession> sessions);

  Future<List<UsageSession>> getSessionsForDate(DateTime date);

  /// Replaces the stored per-app totals for [day] with [summaries].
  Future<void> saveDailySummaries(
    DateTime day,
    List<AppUsageSummary> summaries,
  );

  /// Stored per-app totals for [day], longest first. Icons are not persisted.
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day);

  /// Aggregated per-app totals across every stored daily snapshot.
  Future<List<AppUsageSummary>> getAllTimeSummaries();

  /// Stored per-app daily rows in the half-open date range.
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  );

  Future<void> insertUsageIntervals(List<AppUsageInterval> intervals) async {}

  Future<List<AppUsageInterval>> getUsageIntervals(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => const <AppUsageInterval>[];

  Future<void> insertRestrictionEvent(RestrictionEvent event) async {}

  Future<List<RestrictionEvent>> getRestrictionEvents(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => const <RestrictionEvent>[];

  Future<String?> readSetting(String key);

  Future<void> writeSetting(String key, String value);

  Future<void> clearAllData();
}

abstract class PortableFocusTraceDataSource {
  /// Returns a portable snapshot of every durable local table.
  Future<Map<String, List<Map<String, Object?>>>> exportPortableData();

  /// Merges a validated portable snapshot in one transaction.
  Future<int> importPortableData(
    Map<String, List<Map<String, Object?>>> tables,
  );
}

abstract interface class UsageReportSnapshotDataSource {
  Future<UsageReportSourceData> readReportSnapshot(
    DateTime from,
    DateTime to,
    DateTime intervalFrom,
  );
}

abstract interface class UsageRecoveryDatabase {
  /// Ensure Flutter-owned migrations finish before the native writer opens it.
  Future<void> prepareUsageRecovery();
}

class SqfliteFocusTraceLocalDataSource
    implements
        FocusTraceLocalDataSource,
        PortableFocusTraceDataSource,
        UsageRecoveryDatabase,
        UsageReportSnapshotDataSource {
  SqfliteFocusTraceLocalDataSource({
    this.databaseName = 'focus_trace.db',
    DatabaseFactory? databaseFactoryOverride,
    Future<Directory> Function()? applicationSupportDirectoryProvider,
  }) : _databaseFactoryOverride = databaseFactoryOverride,
       _applicationSupportDirectoryProvider =
           applicationSupportDirectoryProvider;

  final String databaseName;
  final DatabaseFactory? _databaseFactoryOverride;
  final Future<Directory> Function()? _applicationSupportDirectoryProvider;
  Database? _database;

  @override
  Future<void> prepareUsageRecovery() async {
    await _db;
  }

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final factory = await _databaseFactory;
    final path = await _databasePath();

    final opened = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError(
            'Database v$oldVersion cannot be opened by schema v$newVersion.',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createDailyUsageTable(db);
          } else if (oldVersion < 3) {
            await db.execute('''
ALTER TABLE daily_app_usage
ADD COLUMN launch_count INTEGER NOT NULL DEFAULT 0
''');
          }
          if (oldVersion < 4) {
            await _createReportTables(db);
          }
          if (oldVersion < 5) {
            await _createUsageSnapshotTable(db);
            // Older binaries can lower user_version without removing v5 tables.
            // Their writes invalidate any coverage evidence left behind.
            await db.delete('usage_snapshot_days');
          }
        },
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE usage_sessions (
  id TEXT PRIMARY KEY,
  platform TEXT NOT NULL,
  app_name TEXT NOT NULL,
  package_name TEXT,
  process_name TEXT,
  window_title TEXT,
  started_at INTEGER NOT NULL,
  ended_at INTEGER,
  duration_seconds INTEGER NOT NULL,
  category TEXT,
  created_at INTEGER NOT NULL
)
''');
          await db.execute('''
CREATE INDEX idx_usage_sessions_started_at
ON usage_sessions(started_at)
''');
          await db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
          await _createDailyUsageTable(db);
          await _createReportTables(db);
          await _createUsageSnapshotTable(db);
        },
      ),
    );

    _database = opened;
    return opened;
  }

  /// Closes the underlying database (used by tests to release the file).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _createDailyUsageTable(Database db) {
    return db.execute('''
CREATE TABLE daily_app_usage (
  day TEXT NOT NULL,
  app_key TEXT NOT NULL,
  app_name TEXT NOT NULL,
  package_name TEXT,
  process_name TEXT,
  duration_seconds INTEGER NOT NULL,
  launch_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, app_key)
)
''');
  }

  Future<void> _createReportTables(Database db) async {
    await db.execute('''
CREATE TABLE usage_intervals (
  id TEXT PRIMARY KEY,
  app_key TEXT NOT NULL,
  app_name TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NOT NULL
)
''');
    await db.execute('''
CREATE INDEX idx_usage_intervals_started_at
ON usage_intervals(started_at)
''');
    await db.execute('''
CREATE TABLE restriction_events (
  id TEXT PRIMARY KEY,
  app_key TEXT NOT NULL,
  app_name TEXT NOT NULL,
  event_type TEXT NOT NULL,
  reason TEXT,
  occurred_at INTEGER NOT NULL
)
''');
    await db.execute('''
CREATE INDEX idx_restriction_events_occurred_at
ON restriction_events(occurred_at)
''');
  }

  // Device-local query evidence is deliberately not portable. Imported/legacy
  // days have no metadata and must be reconciled before being considered final.
  Future<void> _createUsageSnapshotTable(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS usage_snapshot_days (
  day TEXT PRIMARY KEY,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  timezone_id TEXT NOT NULL,
  queried_at_ms INTEGER NOT NULL,
  covered_until_ms INTEGER NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('partial', 'unavailable', 'reconciled'))
)
''');

  Future<DatabaseFactory> get _databaseFactory async {
    final override = _databaseFactoryOverride;
    if (override != null) {
      return override;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }

    return databaseFactory;
  }

  Future<String> _databasePath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final provider =
          _applicationSupportDirectoryProvider ??
          getApplicationSupportDirectory;
      final directory = await provider();
      await directory.create(recursive: true);
      return p.join(directory.path, databaseName);
    }

    return p.join(await getDatabasesPath(), databaseName);
  }

  @override
  Future<void> insertSession(UsageSession session) async {
    final db = await _db;
    await db.insert(
      'usage_sessions',
      _sessionToRow(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertSessions(List<UsageSession> sessions) async {
    if (sessions.isEmpty) {
      return;
    }

    final db = await _db;
    await db.transaction((txn) async {
      for (final session in sessions) {
        await txn.insert(
          'usage_sessions',
          _sessionToRow(session),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<UsageSession>> getSessionsForDate(DateTime date) async {
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    final db = await _db;
    final rows = await db.query(
      'usage_sessions',
      where: 'started_at < ? AND (ended_at IS NULL OR ended_at > ?)',
      whereArgs: [to.millisecondsSinceEpoch, from.millisecondsSinceEpoch],
      orderBy: 'started_at ASC',
    );
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Future<void> saveDailySummaries(
    DateTime day,
    List<AppUsageSummary> summaries,
  ) async {
    final db = await _db;
    final dayKey = _dayKey(day);
    await db.transaction((txn) async {
      // Android owns paired totals/interval snapshots. Never let a delayed
      // legacy Dart save overwrite a day already managed by the native writer.
      final managed = await txn.query(
        'usage_snapshot_days',
        columns: ['day'],
        where: 'day = ?',
        whereArgs: [dayKey],
      );
      if (managed.isNotEmpty) return;
      await txn.delete(
        'daily_app_usage',
        where: 'day = ?',
        whereArgs: [dayKey],
      );
      for (final summary in summaries) {
        await txn.insert('daily_app_usage', {
          'day': dayKey,
          'app_key': summary.appKey,
          'app_name': summary.appName,
          'package_name': summary.packageName,
          'process_name': summary.processName,
          'duration_seconds': summary.totalDurationSeconds,
          'launch_count': summary.launchCount,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async {
    final db = await _db;
    final rows = await db.query(
      'daily_app_usage',
      where: 'day = ?',
      whereArgs: [_dayKey(day)],
      orderBy: 'duration_seconds DESC',
    );
    return rows
        .map(
          (row) => AppUsageSummary(
            appName: row['app_name'] as String,
            packageName: row['package_name'] as String?,
            processName: row['process_name'] as String?,
            totalDurationSeconds: row['duration_seconds'] as int,
            percentageOfTotal: 0,
            launchCount: row['launch_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() async {
    final db = await _db;
    final rows = await db.rawQuery('''
SELECT
  app_key,
  MAX(app_name) AS app_name,
  MAX(package_name) AS package_name,
  MAX(process_name) AS process_name,
  SUM(duration_seconds) AS duration_seconds,
  SUM(launch_count) AS launch_count
FROM daily_app_usage
GROUP BY app_key
ORDER BY duration_seconds DESC, app_name COLLATE NOCASE ASC
''');
    return rows
        .map(
          (row) => AppUsageSummary(
            appName: row['app_name'] as String,
            packageName: row['package_name'] as String?,
            processName: row['process_name'] as String?,
            totalDurationSeconds: row['duration_seconds'] as int,
            percentageOfTotal: 0,
            launchCount: row['launch_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => _getUsageHistory(await _db, fromInclusive, toExclusive);

  Future<List<DailyAppUsage>> _getUsageHistory(
    DatabaseExecutor db,
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    final rows = await db.query(
      'daily_app_usage',
      where: 'day >= ? AND day < ?',
      whereArgs: [_dayKey(fromInclusive), _dayKey(toExclusive)],
      orderBy: 'day ASC, duration_seconds DESC',
    );
    return rows
        .map(
          (row) => DailyAppUsage(
            day: DateTime.parse(row['day'] as String),
            summary: AppUsageSummary(
              appName: row['app_name'] as String,
              packageName: row['package_name'] as String?,
              processName: row['process_name'] as String?,
              totalDurationSeconds: row['duration_seconds'] as int,
              percentageOfTotal: 0,
              launchCount: row['launch_count'] as int? ?? 0,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<void> insertUsageIntervals(List<AppUsageInterval> intervals) async {
    if (intervals.isEmpty) {
      return;
    }
    final db = await _db;
    await db.transaction((txn) async {
      for (final interval in intervals) {
        final managed = await txn.rawQuery(
          '''
SELECT day FROM usage_snapshot_days
WHERE start_ms < ? AND end_ms > ? LIMIT 1
''',
          [
            interval.endedAt.millisecondsSinceEpoch,
            interval.startedAt.millisecondsSinceEpoch,
          ],
        );
        if (managed.isNotEmpty) continue;
        await txn.insert('usage_intervals', {
          'id': interval.id,
          'app_key': interval.appKey,
          'app_name': interval.appName,
          'started_at': interval.startedAt.millisecondsSinceEpoch,
          'ended_at': interval.endedAt.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<List<AppUsageInterval>> getUsageIntervals(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => _getUsageIntervals(await _db, fromInclusive, toExclusive);

  Future<List<AppUsageInterval>> _getUsageIntervals(
    DatabaseExecutor db,
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    final fromMs = fromInclusive.millisecondsSinceEpoch;
    final toMs = toExclusive.millisecondsSinceEpoch;
    final intervalRows = await db.query(
      'usage_intervals',
      where: 'started_at < ? AND ended_at > ?',
      whereArgs: [toMs, fromMs],
      orderBy: 'started_at ASC',
    );
    final sessionRows = await db.query(
      'usage_sessions',
      where: 'started_at < ? AND (ended_at IS NULL OR ended_at > ?)',
      whereArgs: [toMs, fromMs],
      orderBy: 'started_at ASC',
    );
    final intervals = <AppUsageInterval>[
      for (final row in intervalRows)
        AppUsageInterval(
          id: row['id'] as String,
          appKey: row['app_key'] as String,
          appName: row['app_name'] as String,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            row['started_at'] as int,
          ),
          endedAt: DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
        ),
      for (final row in sessionRows)
        AppUsageInterval(
          id: 'session:${row['id'] as String}',
          appKey:
              row['package_name'] as String? ??
              row['process_name'] as String? ??
              row['app_name'] as String,
          appName: row['app_name'] as String,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            row['started_at'] as int,
          ),
          endedAt: row['ended_at'] == null
              ? DateTime.fromMillisecondsSinceEpoch(
                  row['started_at'] as int,
                ).add(Duration(seconds: row['duration_seconds'] as int))
              : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
        ),
    ]..sort((first, second) => first.startedAt.compareTo(second.startedAt));
    return intervals;
  }

  @override
  Future<void> insertRestrictionEvent(RestrictionEvent event) async {
    final db = await _db;
    await db.insert('restriction_events', {
      'id': event.id,
      'app_key': event.appKey,
      'app_name': event.appName,
      'event_type': event.type.wireName,
      'reason': event.reason,
      'occurred_at': event.occurredAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<RestrictionEvent>> getRestrictionEvents(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => _getRestrictionEvents(await _db, fromInclusive, toExclusive);

  Future<List<RestrictionEvent>> _getRestrictionEvents(
    DatabaseExecutor db,
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    final rows = await db.query(
      'restriction_events',
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: [
        fromInclusive.millisecondsSinceEpoch,
        toExclusive.millisecondsSinceEpoch,
      ],
      orderBy: 'occurred_at DESC',
    );
    return rows
        .map(
          (row) => RestrictionEvent(
            id: row['id'] as String,
            appKey: row['app_key'] as String,
            appName: row['app_name'] as String,
            type: RestrictionEventType.fromWireName(
              row['event_type'] as String?,
            ),
            reason: row['reason'] as String?,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(
              row['occurred_at'] as int,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<UsageReportSourceData> readReportSnapshot(
    DateTime from,
    DateTime to,
    DateTime intervalFrom,
  ) async {
    final db = await _db;
    // Read all report inputs from one SQLite snapshot while native writers may
    // reconcile a day. Never combine old daily totals with newly saved intervals.
    return db.transaction(
      (txn) async => UsageReportSourceData(
        dailyUsage: await _getUsageHistory(txn, from, to),
        intervals: await _getUsageIntervals(txn, intervalFrom, to),
        restrictionEvents: await _getRestrictionEvents(txn, from, to),
      ),
    );
  }

  String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Future<String?> readSetting(String key) async {
    final db = await _db;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  @override
  Future<void> writeSetting(String key, String value) async {
    final db = await _db;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, List<Map<String, Object?>>>> exportPortableData() async {
    final db = await _db;
    return db.transaction((txn) async {
      final result = <String, List<Map<String, Object?>>>{};
      for (final table in _portableTableColumns.keys) {
        result[table] = await txn.query(
          table,
          where: table == 'settings' ? 'key != ?' : null,
          whereArgs: table == 'settings' ? ['usage_recovery_generation'] : null,
        );
      }
      return result;
    });
  }

  @override
  Future<int> importPortableData(
    Map<String, List<Map<String, Object?>>> tables,
  ) async {
    final db = await _db;
    return db.transaction((txn) async {
      var importedRows = 0;
      for (final entry in tables.entries) {
        final allowedColumns = _portableTableColumns[entry.key];
        if (allowedColumns == null) {
          throw FormatException('Unsupported backup table: ${entry.key}');
        }
        for (final row in entry.value) {
          if (row.keys.any((column) => !allowedColumns.contains(column))) {
            throw FormatException(
              'Backup contains unsupported columns for ${entry.key}.',
            );
          }
          await txn.insert(
            entry.key,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRows++;
        }
      }
      await _invalidateUsageRecovery(txn);
      return importedRows;
    });
  }

  @override
  Future<void> clearAllData() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('usage_sessions');
      await txn.delete('settings');
      await txn.delete('daily_app_usage');
      await txn.delete('usage_intervals');
      await txn.delete('restriction_events');
      await _invalidateUsageRecovery(txn);
    });
  }

  Future<void> _invalidateUsageRecovery(DatabaseExecutor txn) async {
    // Backups contain data, not OS coverage evidence. Rotating a device-local
    // token also rejects native queries started before this import or clear.
    await txn.delete('usage_snapshot_days');
    await txn.execute('''
INSERT OR REPLACE INTO settings (key, value)
VALUES ('usage_recovery_generation', lower(hex(randomblob(16))))
''');
  }

  Map<String, Object?> _sessionToRow(UsageSession session) {
    return {
      'id': session.id,
      'platform': session.platform.name,
      'app_name': session.appName,
      'package_name': session.packageName,
      'process_name': session.processName,
      'window_title': session.windowTitle,
      'started_at': session.startedAt.millisecondsSinceEpoch,
      'ended_at': session.endedAt?.millisecondsSinceEpoch,
      'duration_seconds': session.durationSeconds,
      'category': session.category,
      'created_at': session.createdAt.millisecondsSinceEpoch,
    };
  }

  UsageSession _sessionFromRow(Map<String, Object?> row) {
    return UsageSession(
      id: row['id'] as String,
      platform: UsagePlatform.fromName(row['platform'] as String?),
      appName: row['app_name'] as String,
      packageName: row['package_name'] as String?,
      processName: row['process_name'] as String?,
      windowTitle: row['window_title'] as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
      durationSeconds: row['duration_seconds'] as int,
      category: row['category'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }

  static const _portableTableColumns = <String, Set<String>>{
    'usage_sessions': {
      'id',
      'platform',
      'app_name',
      'package_name',
      'process_name',
      'window_title',
      'started_at',
      'ended_at',
      'duration_seconds',
      'category',
      'created_at',
    },
    'settings': {'key', 'value'},
    'daily_app_usage': {
      'day',
      'app_key',
      'app_name',
      'package_name',
      'process_name',
      'duration_seconds',
      'launch_count',
    },
    'usage_intervals': {'id', 'app_key', 'app_name', 'started_at', 'ended_at'},
    'restriction_events': {
      'id',
      'app_key',
      'app_name',
      'event_type',
      'reason',
      'occurred_at',
    },
  };
}
