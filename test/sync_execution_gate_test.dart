import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/src/data/datasources/sync_execution_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('focustrace/sync_execution');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'acquisition is awaited and a throw releases before another instance runs',
    () async {
      final calls = <MethodCall>[];
      final requested = Completer<void>();
      final acquired = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'acquire') {
          if (!requested.isCompleted) requested.complete();
          return acquired.future;
        }
        return null;
      });
      var entered = false;
      final operation = const AndroidSyncExecutionGate().run<void>(() async {
        entered = true;
        throw StateError('test failure');
      });
      final assertion = expectLater(operation, throwsStateError);
      await requested.future;
      expect(entered, isFalse);
      acquired.complete('lease-one');
      await assertion;
      expect(calls.map((call) => call.method), ['acquire', 'release']);
      expect(calls.last.arguments, 'lease-one');
      expect(await const AndroidSyncExecutionGate().run(() async => 7), 7);
      expect(calls.last.method, 'release');
    },
  );

  test('missing channel fails closed without executing work', () async {
    var entered = false;
    await expectLater(
      const AndroidSyncExecutionGate().run(() async {
        entered = true;
      }),
      throwsA(isA<MissingPluginException>()),
    );
    expect(entered, isFalse);
  });
}
