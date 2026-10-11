import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focustrace/src/presentation/view_models/app_categories_view_model.dart';

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

  test('category overrides survive restart, backup/import and reset', () async {
    const editor = AppUsageSummary(
      appName: 'Editor',
      processName: 'editor.exe',
      totalDurationSeconds: 300,
      percentageOfTotal: 1,
    );
    final model = AppCategoriesViewModel(SettingsRepositoryImpl(source));
    addTearDown(model.dispose);
    await model.load();
    expect(
      await model.save(editor.appKey, UsageCategory.entertainment),
      isTrue,
    );
    expect(
      resolveUsageCategory(editor, model.state.asData!.value),
      UsageCategory.entertainment,
    );
    expect(
      resolveUsageCategory(
        editor.copyWith(appName: 'Renamed'),
        model.state.asData!.value,
      ),
      UsageCategory.entertainment,
    );

    final documents = _MemoryBackupDocumentDataSource();
    var transfer = DataTransferRepositoryImpl(
      localDataSource: source,
      documentDataSource: documents,
    );
    expect(await transfer.exportData(), isTrue);
    final importedDocuments = _MemoryBackupDocumentDataSource(
      openedContents: documents.savedContents,
    );
    await source.close();
    source = SqfliteFocusTraceLocalDataSource(
      databaseName: 'source.db',
      databaseFactoryOverride: databaseFactoryFfi,
      applicationSupportDirectoryProvider: () async => tempDirectory,
    );
    final repository = SettingsRepositoryImpl(source);
    expect(await repository.appCategoryOverrides(), {
      editor.appKey: UsageCategory.entertainment,
    });
    await source.clearAllData();
    expect(await repository.appCategoryOverrides(), isEmpty);
    transfer = DataTransferRepositoryImpl(
      localDataSource: source,
      documentDataSource: importedDocuments,
    );
    expect(await transfer.importData(), isNotNull);
    final restored = AppCategoriesViewModel(repository);
    addTearDown(restored.dispose);
    await restored.load();
    expect(
      resolveUsageCategory(editor, restored.state.asData!.value),
      UsageCategory.entertainment,
    );
    expect(await restored.save(editor.appKey, null), isTrue);
    expect(await repository.appCategoryOverrides(), isEmpty);
    expect(
      resolveUsageCategory(editor, restored.state.asData!.value),
      UsageCategory.productivity,
    );
    expect(
      resolveUsageCategory(editor.copyWith(appName: 'Unknown app'), {}),
      UsageCategory.activity,
    );
  });

  test('invalid category settings safely fall back to automatic', () async {
    final repository = SettingsRepositoryImpl(source);
    for (final value in [
      'invalid json',
      '[]',
      '{"app": "unknown"}',
      '{"": "web", "app": 42, "valid": "web"}',
    ]) {
      await source.writeSetting('app_category_overrides', value);
      expect(
        await repository.appCategoryOverrides(),
        value.contains('valid') && value.startsWith('{')
            ? {'valid': UsageCategory.web}
            : isEmpty,
      );
    }
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

  test('carries no authentication credential or device identity', () async {
    await source.writeSetting('onboarding_completed', 'true');
    await source.writeSetting(SyncSettingKeys.installationId, 'device-uuid');
    await source.writeSetting(SyncSettingKeys.usageWatermarkMs, '1000');
    final documents = _MemoryBackupDocumentDataSource();
    final repository = DataTransferRepositoryImpl(
      localDataSource: source,
      documentDataSource: documents,
    );

    expect(await repository.exportData(), isTrue);

    final contents = documents.savedContents!;
    expect(contents, contains('onboarding_completed'));
    // Device-local sync state is stripped on the way out and refused on the
    // way in, so a restored backup never claims another installation's
    // identity or its upload watermark.
    expect(contents, isNot(contains('device-uuid')));
    expect(contents, isNot(contains(SyncSettingKeys.prefix)));
    // The refresh token is not in this database at all - it is in the Android
    // keystore, which no export path can read - so there is nothing to strip.
    expect(contents.toLowerCase(), isNot(contains('token')));
  });

  test('rejects another JSON format before touching the database', () async {
    final repository = DataTransferRepositoryImpl(
      localDataSource: source,
      documentDataSource: _MemoryBackupDocumentDataSource(
        openedContents: '{"format":"something-else","tables":{}}',
      ),
    );

    await expectLater(repository.importData(), throwsFormatException);
    expect((await source.exportPortableData()).values, everyElement(isEmpty));
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

  group('imported values are validated before anything is written', () {
    /// Every table, including recovery metadata and device-local settings.
    Future<Map<String, List<Map<String, Object?>>>> everything() async {
      await source.prepareUsageRecovery();
      final db = await databaseFactoryFfi.openDatabase(
        '${tempDirectory.path}/source.db',
        // Not the data source's own shared handle, which closing would end.
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        return {
          for (final table in [
            'usage_sessions',
            'settings',
            'daily_app_usage',
            'usage_intervals',
            'restriction_events',
            'usage_snapshot_days',
          ])
            table: await db.query(table, orderBy: 'rowid'),
        };
      } finally {
        await db.close();
      }
    }

    Map<String, Object?> usageRow([Map<String, Object?> changes = const {}]) =>
        {
          'day': '2026-08-17',
          'app_key': 'example.reader',
          'app_name': 'Reader',
          'package_name': 'example.reader',
          'process_name': null,
          'duration_seconds': 1200,
          'launch_count': 3,
          ...changes,
        };

    setUp(() async {
      await source.saveDailySummaries(DateTime(2026, 8, 18), const [
        AppUsageSummary(
          appName: 'Existing',
          packageName: 'example.existing',
          totalDurationSeconds: 300,
          percentageOfTotal: 1,
        ),
      ]);
      await source.writeSetting(SyncSettingKeys.importedVersionMs, '1000');
      await source.writeSetting(SyncSettingKeys.usageWatermarkMs, '2000');
      await source.writeSetting('usage_recovery_generation', 'generation-1');
      final db = await databaseFactoryFfi.openDatabase(
        '${tempDirectory.path}/source.db',
        // Not the data source's own shared handle, which closing would end.
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.insert('usage_snapshot_days', {
        'day': '2026-08-18',
        'start_ms': 0,
        'end_ms': 1,
        'timezone_id': 'UTC',
        'queried_at_ms': 1,
        'covered_until_ms': 1,
        'status': 'reconciled',
      });
      await db.close();
    });

    final invalid = <String, Map<String, List<Map<String, Object?>>>>{
      'a fractional integer after a valid row': {
        'daily_app_usage': [
          usageRow(),
          usageRow({'app_key': 'b', 'duration_seconds': 12.5}),
        ],
      },
      'an integral double': {
        'daily_app_usage': [
          usageRow({'launch_count': 3.0}),
        ],
      },
      'a numeric string in an integer column': {
        'daily_app_usage': [
          usageRow({'duration_seconds': '600'}),
        ],
      },
      'an impossible calendar date': {
        'daily_app_usage': [
          usageRow({'day': '2026-02-30'}),
        ],
      },
      'an unpadded date': {
        'daily_app_usage': [
          usageRow({'day': '2026-8-17'}),
        ],
      },
      'a date with a time': {
        'daily_app_usage': [
          usageRow({'day': '2026-08-17T00:00:00'}),
        ],
      },
      'null in a required column': {
        'daily_app_usage': [
          usageRow({'app_name': null}),
        ],
      },
      'null in a defaulted column': {
        'daily_app_usage': [
          usageRow({'launch_count': null}),
        ],
      },
      'a missing required column': {
        'usage_intervals': [
          {'id': 'i', 'app_key': 'a', 'app_name': 'A', 'started_at': 1},
        ],
      },
      'a number in a text column': {
        'restriction_events': [
          {
            'id': 'e',
            'app_key': 'a',
            'app_name': 'A',
            'event_type': 7,
            'occurred_at': 1,
          },
        ],
      },
      'a non-string setting key after a valid table': {
        'daily_app_usage': [usageRow()],
        'settings': [
          {'key': 1, 'value': 'x'},
        ],
      },
      'a string timestamp in a session': {
        'usage_sessions': [
          {
            'id': 's',
            'platform': 'windows',
            'app_name': 'Editor',
            'started_at': '1786953600000',
            'duration_seconds': 60,
            'created_at': 1786953600000,
          },
        ],
      },
    };

    for (final MapEntry(key: name, value: tables) in invalid.entries) {
      test('$name is rejected and nothing changes', () async {
        final before = await everything();

        await expectLater(
          source.importPortableData(tables),
          throwsFormatException,
        );

        expect(await everything(), before);
      });
    }

    test(
      'a valid backup round-trips with nullable and defaulted columns',
      () async {
        await source.insertSession(
          UsageSession(
            id: 'session-1',
            platform: UsagePlatform.windows,
            appName: 'Editor',
            processName: 'editor.exe',
            startedAt: DateTime.fromMillisecondsSinceEpoch(1786953600000),
            endedAt: null,
            durationSeconds: 60,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1786953600000),
          ),
        );
        await source.writeSetting('onboarding_completed', 'true');
        final documents = _MemoryBackupDocumentDataSource();
        expect(
          await DataTransferRepositoryImpl(
            localDataSource: source,
            documentDataSource: documents,
          ).exportData(),
          isTrue,
        );
        final exported = await source.exportPortableData();

        await source.clearAllData();
        final result = await DataTransferRepositoryImpl(
          localDataSource: source,
          documentDataSource: _MemoryBackupDocumentDataSource(
            openedContents: documents.savedContents,
          ),
        ).importData();

        expect(result?.importedRows, greaterThan(0));
        final reimported = await source.exportPortableData();
        for (final table in ['usage_sessions', 'daily_app_usage']) {
          expect(reimported[table], exported[table], reason: table);
        }
        expect(await source.readSetting('onboarding_completed'), 'true');
        // Device-local keys never travel; the import resets the watermark.
        expect(await source.readSetting(SyncSettingKeys.usageWatermarkMs), '0');
      },
    );

    test('a backup from before launch_count gets its default', () async {
      final row = usageRow()..remove('launch_count');

      expect(
        await source.importPortableData({
          'daily_app_usage': [row],
          'settings': [
            {'key': SyncSettingKeys.installationId, 'value': 'foreign'},
          ],
        }),
        1,
      );

      expect(
        (await source.getDailySummaries(
          DateTime(2026, 8, 17),
        )).single.launchCount,
        0,
      );
      expect(await source.readSetting(SyncSettingKeys.installationId), isNull);
    });
  });
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
