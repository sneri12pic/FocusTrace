import 'package:flutter/services.dart';

/// Serializes a whole repository operation, never individual HTTP requests.
abstract interface class SyncExecutionGate {
  Future<T> run<T>(Future<T> Function() operation);
}

/// Every engine's channel reaches the same Android process-wide gate.
/// Missing native support fails closed; it must never run unprotected.
class AndroidSyncExecutionGate implements SyncExecutionGate {
  const AndroidSyncExecutionGate({
    MethodChannel channel = const MethodChannel('focustrace/sync_execution'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<T> run<T>(Future<T> Function() operation) async {
    final lease = await _channel.invokeMethod<String>('acquire');
    if (lease == null) {
      throw StateError('Sync coordination unavailable.');
    }
    try {
      return await operation();
    } finally {
      await _channel.invokeMethod<void>('release', lease);
    }
  }
}
