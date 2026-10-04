import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/src/application/services/background_sync.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactorySqflitePlugin;
  const background = MethodChannel('focustrace/background_sync');
  const database = MethodChannel('com.tekartik.sqflite');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(background, null);
    messenger.setMockMethodCallHandler(database, null);
  });

  test(
    'entrypoint probes plugin then waits for READY authorization before completion',
    () async {
      final permission = Completer<bool>();
      final ready = Completer<void>();
      final events = <String>[];
      messenger.setMockMethodCallHandler(database, (call) async {
        expect(call.method, 'getDatabasesPath');
        events.add('plugin');
        return '/unused';
      });
      messenger.setMockMethodCallHandler(background, (call) async {
        events.add(call.method);
        if (call.method == 'ready') {
          ready.complete();
          return permission.future;
        }
        expect(call.method, 'complete');
        expect(call.arguments, 'success');
        return null;
      });
      final run = backgroundSyncEntrypoint();
      await ready.future;
      expect(events, ['plugin', 'ready']);
      permission.complete(true);
      await run;
      expect(events, ['plugin', 'ready', 'complete']);
    },
  );

  test('denied or failed readiness completes with failure', () async {
    messenger.setMockMethodCallHandler(database, (_) async => '/unused');
    for (final throws in [false, true]) {
      final outcomes = <Object?>[];
      messenger.setMockMethodCallHandler(background, (call) async {
        if (call.method == 'ready') {
          if (throws) throw PlatformException(code: 'CLOSED');
          return false;
        }
        outcomes.add(call.arguments);
        return null;
      });
      await backgroundSyncEntrypoint();
      expect(outcomes, ['failure']);
    }
  });
}
