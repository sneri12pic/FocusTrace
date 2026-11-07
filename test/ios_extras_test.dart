import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/data/datasources/health_connect_channel.dart';
import 'package:focustrace/src/domain/models/health_connect.dart';
import 'package:focustrace/src/presentation/screens/health_connect_screen.dart';

import 'health_connect_test.dart' show FakeHealthConnectChannel;

/// Phase 5 of the iOS port: Apple Health workouts, backups with picked app
/// groups, and the app language, all through MethodChannels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  List<MethodCall> mock(String name, Object? Function(MethodCall) answer) {
    final channel = MethodChannel(name);
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  group('Apple Health through focustrace/health_connect', () {
    test('reads the iOS status and workout maps', () async {
      final calls = mock('test/health', (call) {
        switch (call.method) {
          case 'workouts':
            return [
              {
                'id': 'A1B2',
                'sourcePackage': 'com.hevyapp.hevy',
                'sourceName': 'Hevy',
                'exerciseType': 50,
                'category': 'strength',
                'startMillis': 1793995200000,
                'endMillis': 1793998800000,
              },
            ];
          default:
            return {
              'sdkStatus': 'available',
              'enabled': true,
              'autoImport': true,
              'readGranted': true,
              'backgroundGranted': true,
              'backgroundSupported': true,
              'lastSuccessMillis': 1793995200000,
              'lastAttemptMillis': 1793995200000,
              'lastOutcome': 'noNew',
              'lastImportedCount': 0,
              'workoutCount': 1,
              'store': 'appleHealth',
            };
        }
      });
      const channel = HealthConnectChannel(
        channel: MethodChannel('test/health'),
      );

      final status = await channel.setAutoImport(true);
      expect(status.availability, HealthConnectAvailability.available);
      expect(status.autoImportBlocked, isFalse);
      expect(status.accessRevoked, isFalse);
      expect(status.lastOutcome, HealthConnectOutcome.noNew);
      final workouts = await channel.workouts();
      expect(workouts.single.sourceName, 'Hevy');
      expect(workouts.single.category, WorkoutCategory.strength);
      expect(workouts.single.title, isNull);
      expect(workouts.single.duration, const Duration(hours: 1));
      expect(calls.map((c) => c.method), ['setAutoImport', 'workouts']);
      expect(calls.first.arguments, isTrue);
    });

    testWidgets('the screen names Apple Health on iOS', (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final channel = FakeHealthConnectChannel(
        current: const HealthConnectStatus(
          availability: HealthConnectAvailability.available,
          enabled: true,
          readGranted: true,
          backgroundGranted: true,
          backgroundSupported: true,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            platformCapabilitiesProvider.overrideWithValue(
              PlatformCapabilities.ios,
            ),
            healthConnectChannelProvider.overrideWithValue(channel),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HealthConnectScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apple Health'), findsOneWidget);
      expect(find.textContaining('Health Connect'), findsNothing);
      expect(find.text('Manage access in the Health app'), findsOneWidget);
      // Health never says whether reading was allowed: explain where to look.
      expect(find.textContaining('Sharing, Apps, FocusTrace'), findsOneWidget);
    });
  });

  group('backups on iOS', () {
    test('the document data source sends saveBackup and openBackup', () async {
      final calls = mock('test/transfer', (call) {
        return call.method == 'saveBackup' ? true : '{"format":"x"}';
      });
      final source = MethodChannelBackupDocumentDataSource(
        channel: const MethodChannel('test/transfer'),
      );

      expect(
        await source.saveJson(suggestedFileName: 'b.json', contents: '{}'),
        isTrue,
      );
      expect(await source.openJson(), '{"format":"x"}');
      expect(calls[0].arguments, {
        'suggestedFileName': 'b.json',
        'contents': '{}',
      });
      expect(calls[1].method, 'openBackup');
    });

    test('app groups travel inside the backup and come back', () async {
      final native = <String, String>{'abc-1': 'ZGF0YQ=='};
      final calls = mock('test/screen_time', (call) {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        switch (call.method) {
          case 'exportSelections':
            return {
              for (final id in args['ids']! as List)
                if (native.containsKey(id)) id: native[id],
            };
          case 'importSelections':
            final selections = Map<Object?, Object?>.from(
              args['selections']! as Map,
            );
            var added = 0;
            selections.forEach((id, data) {
              if (!native.containsKey(id)) {
                native[id! as String] = data! as String;
                added++;
              }
            });
            return added;
          case 'selectionSummary':
            final id = args['selectionId'];
            return native.containsKey(id)
                ? {'selectionId': id, 'appCount': 2}
                : null;
        }
        return null;
      });
      const screenTime = ScreenTimeChannel(
        channel: MethodChannel('test/screen_time'),
      );
      final local = _MemoryPortableData({
        'settings': [
          {
            'key': 'restriction_rules',
            'value': jsonEncode([
              {'appKey': 'ios-sel:abc-1', 'appName': 'Social'},
              {'appKey': 'ios-sel:gone-2', 'appName': 'Games'},
              {'appKey': 'com.example.app', 'appName': 'Android'},
            ]),
          },
        ],
      });
      final documents = _MemoryDocuments();
      final repository = DataTransferRepositoryImpl(
        localDataSource: local,
        documentDataSource: documents,
        appGroupSelections: screenTime,
      );

      expect(await repository.exportData(), isTrue);
      final backup = jsonDecode(documents.saved!) as Map<String, Object?>;
      expect(backup['formatVersion'], 1);
      expect(backup['iosSelections'], {'abc-1': 'ZGF0YQ=='});
      expect(
        calls.firstWhere((c) => c.method == 'exportSelections').arguments,
        {
          'ids': ['abc-1', 'gone-2'],
        },
      );

      // Another iPhone: nothing stored yet.
      native.clear();
      documents.opened = documents.saved;
      final result = await repository.importData();
      expect(native, {'abc-1': 'ZGF0YQ=='});
      expect(result!.missingAppGroups, 1, reason: 'gone-2 was never saved');
    });

    test('a backup with app groups still imports where they mean nothing', () {
      // Android (no Screen Time channel) ignores the extra key.
      final local = _MemoryPortableData({'settings': []});
      final documents = _MemoryDocuments()
        ..opened = jsonEncode({
          'format': DataTransferRepositoryImpl.formatName,
          'formatVersion': DataTransferRepositoryImpl.formatVersion,
          'tables': {
            'settings': [
              {'key': 'excluded_apps', 'value': '[]'},
            ],
          },
          'iosSelections': {'abc-1': 'ZGF0YQ=='},
        });
      final repository = DataTransferRepositoryImpl(
        localDataSource: local,
        documentDataSource: documents,
      );
      return expectLater(
        repository.importData().then((r) => r!.importedRows),
        completion(1),
      );
    });

    test('malformed app groups reject the backup before anything changes', () {
      final local = _MemoryPortableData({'settings': []});
      final documents = _MemoryDocuments()
        ..opened = jsonEncode({
          'format': DataTransferRepositoryImpl.formatName,
          'formatVersion': DataTransferRepositoryImpl.formatVersion,
          'tables': <String, Object?>{'settings': []},
          'iosSelections': {'../x': 1},
        });
      final repository = DataTransferRepositoryImpl(
        localDataSource: local,
        documentDataSource: documents,
        appGroupSelections: const ScreenTimeChannel(
          channel: MethodChannel('test/unused'),
        ),
      );
      expect(repository.importData(), throwsFormatException);
      expect(local.imports, 0);
    });

    test('referenced app groups are found in rules and routines', () {
      expect(
        DataTransferRepositoryImpl.referencedSelectionIds({
          'settings': [
            {'key': 'restriction_rules', 'value': '[{"appKey":"ios-sel:a"}]'},
            {
              'key': 'block_routines',
              'value': '[{"apps":[{"appKey":"ios-sel:b-2"}]}]',
            },
            {'key': 'excluded_apps', 'value': '["com.x"]'},
          ],
        }),
        {'a', 'b-2'},
      );
    });
  });

  test('iOS mirrors the app language through setAppLocale', () async {
    final calls = mock('test/locale', (_) => null);
    final source = MethodChannelPlatformLocaleDataSource(
      channel: const MethodChannel('test/locale'),
    );
    await source.applyLanguage(AppLanguage.japanese);
    await source.applyLanguage(AppLanguage.system);
    expect(calls.map((c) => c.arguments), ['ja', null]);
  });
}

class _MemoryPortableData implements PortableFocusTraceDataSource {
  _MemoryPortableData(this.tables);

  Map<String, List<Map<String, Object?>>> tables;
  int imports = 0;

  @override
  Future<Map<String, List<Map<String, Object?>>>> exportPortableData() async =>
      tables;

  @override
  Future<int> importPortableData(
    Map<String, List<Map<String, Object?>>> tables,
  ) async {
    imports++;
    this.tables = tables;
    return tables.values.fold<int>(0, (sum, rows) => sum + rows.length);
  }
}

class _MemoryDocuments implements BackupDocumentDataSource {
  String? saved;
  String? opened;

  @override
  Future<String?> openJson() async => opened;

  @override
  Future<bool> saveJson({
    required String suggestedFileName,
    required String contents,
  }) async {
    saved = contents;
    return true;
  }
}
