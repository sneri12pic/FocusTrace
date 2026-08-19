import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDirectory;
  late SqfliteFocusTraceLocalDataSource source;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'focustrace-transfer-test-',
    );
    source = SqfliteFocusTraceLocalDataSource(
      databaseName: 'source.db',
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => tempDirectory,
    );
  });

  tearDown(() async {
    await source.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'exports a versioned portable backup through the document picker',
    () async {
      await source.saveDailySummaries(DateTime(2026, 8, 18), const [
        AppUsageSummary(
          appName: 'Reader',
          packageName: 'example.reader',
          totalDurationSeconds: 900,
          percentageOfTotal: 1,
          launchCount: 4,
        ),
      ]);
      await source.writeSetting('onboarding_completed', 'true');
      final documents = _MemoryBackupDocumentDataSource();
      final repository = DataTransferRepositoryImpl(
        localDataSource: source,
        documentDataSource: documents,
        clock: () => DateTime.utc(2026, 8, 19, 12, 30),
      );

      expect(await repository.exportData(), isTrue);

      final decoded =
          jsonDecode(documents.savedContents!) as Map<String, Object?>;
      expect(decoded['format'], DataTransferRepositoryImpl.formatName);
      expect(decoded['formatVersion'], 1);
      expect(decoded['databaseSchemaVersion'], 4);
      expect(documents.savedName, contains('2026-08-19T12-30'));
      final tables = decoded['tables'] as Map<String, Object?>;
      expect(tables['daily_app_usage'], hasLength(1));
      expect(tables['settings'], hasLength(1));
    },
  );

  test(
    'imports all tables transactionally and merges matching records',
    () async {
      await source.saveDailySummaries(DateTime(2026, 8, 18), const [
        AppUsageSummary(
          appName: 'Existing',
          packageName: 'example.existing',
          totalDurationSeconds: 300,
          percentageOfTotal: 1,
        ),
      ]);
      final documents = _MemoryBackupDocumentDataSource(
        openedContents: jsonEncode({
          'format': DataTransferRepositoryImpl.formatName,
          'formatVersion': 1,
          'databaseSchemaVersion': 4,
          'exportedAt': '2026-08-19T12:30:00.000Z',
          'tables': {
            'usage_sessions': <Object?>[],
            'settings': [
              {'key': 'onboarding_completed', 'value': 'true'},
            ],
            'daily_app_usage': [
              {
                'day': '2026-08-17',
                'app_key': 'example.reader',
                'app_name': 'Reader',
                'package_name': 'example.reader',
                'process_name': null,
                'duration_seconds': 1200,
                'launch_count': 3,
              },
            ],
            'usage_intervals': [
              {
                'id': 'example.reader:1',
                'app_key': 'example.reader',
                'app_name': 'Reader',
                'started_at': 1786953600000,
                'ended_at': 1786954800000,
              },
            ],
            'restriction_events': [
              {
                'id': 'blocked-1',
                'app_key': 'example.reader',
                'app_name': 'Reader',
                'event_type': 'blocked',
                'reason': 'dailyLimit',
                'occurred_at': 1786954800000,
              },
            ],
          },
        }),
      );
      final repository = DataTransferRepositoryImpl(
        localDataSource: source,
        documentDataSource: documents,
      );

      final result = await repository.importData();

      expect(result?.importedRows, 4);
      expect(await source.readSetting('onboarding_completed'), 'true');
      expect(
        (await source.getDailySummaries(DateTime(2026, 8, 17))).single.appName,
        'Reader',
      );
      expect(
        (await source.getDailySummaries(DateTime(2026, 8, 18))).single.appName,
        'Existing',
        reason: 'import must not clear unrelated destination data',
      );
      expect(
        await source.getUsageIntervals(
          DateTime.fromMillisecondsSinceEpoch(1786950000000),
          DateTime.fromMillisecondsSinceEpoch(1786960000000),
        ),
        hasLength(1),
      );
      expect(
        await source.getRestrictionEvents(
          DateTime.fromMillisecondsSinceEpoch(1786950000000),
          DateTime.fromMillisecondsSinceEpoch(1786960000000),
        ),
        hasLength(1),
      );
    },
  );

  test('rejects another JSON format before touching the database', () async {
    final repository = DataTransferRepositoryImpl(
      localDataSource: source,
      documentDataSource: _MemoryBackupDocumentDataSource(
        openedContents: '{"format":"something-else","tables":{}}',
      ),
    );

    await expectLater(repository.importData(), throwsFormatException);
    expect(
      (await source.exportPortableData()).values,
      everyElement(isEmpty),
    );
  });

  test(
    'invalid table rolls back rows inserted earlier in the import',
    () async {
      await expectLater(
        source.importPortableData({
          'settings': [
            {'key': 'temporary', 'value': 'should-roll-back'},
          ],
          'not_a_table': [
            {'id': 'bad'},
          ],
        }),
        throwsFormatException,
      );

      expect(await source.readSetting('temporary'), isNull);
    },
  );
}

class _MemoryBackupDocumentDataSource implements BackupDocumentDataSource {
  _MemoryBackupDocumentDataSource({this.openedContents});

  final String? openedContents;
  String? savedName;
  String? savedContents;

  @override
  Future<String?> openJson() async => openedContents;

  @override
  Future<bool> saveJson({
    required String suggestedFileName,
    required String contents,
  }) async {
    savedName = suggestedFileName;
    savedContents = contents;
    return true;
  }
}
