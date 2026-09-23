import 'dart:async';
import 'package:focustrace/src/data/datasources/sync_execution_gate.dart';

/// Test-only stand-in; Android's native singleton is the production primitive.
class TestSyncExecutionGate implements SyncExecutionGate {
  Future<void> _tail = Future<void>.value();
  void Function()? onRequested;

  @override
  Future<T> run<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    onRequested?.call();
    await previous;
    try {
      return await operation();
    } finally {
      released.complete();
    }
  }
}
