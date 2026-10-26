import 'package:flutter/services.dart';

import '../../domain/models/health_connect.dart';

/// `HealthConnectBridge.kt`. Settings live natively so the background worker
/// can recheck them without a Flutter engine; every call returns the full
/// current status.
class HealthConnectChannel {
  const HealthConnectChannel({
    MethodChannel channel = const MethodChannel('focustrace/health_connect'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<HealthConnectStatus> status() => _status('state');

  /// Requests the exercise read permission if needed; on only when granted.
  Future<HealthConnectStatus> enable() => _status('enable');

  /// Stops reads and cancels scheduled imports. Keeps imported workouts and
  /// does not revoke the system permission.
  Future<HealthConnectStatus> disable() => _status('disable');

  /// Turning on requests background read access where supported.
  Future<HealthConnectStatus> setAutoImport(bool enabled) =>
      _status('setAutoImport', enabled);

  Future<HealthConnectStatus> importNow() => _status('importNow');

  Future<HealthConnectStatus> clearImported() => _status('clearImported');

  Future<List<ImportedWorkout>> workouts() async {
    final rows = await _channel.invokeListMethod<Object?>('workouts') ?? [];
    return [
      for (final row in rows)
        ImportedWorkout.fromMap(row as Map<Object?, Object?>),
    ];
  }

  Future<void> openPermissionSettings() =>
      _channel.invokeMethod<void>('openPermissionSettings');

  Future<HealthConnectStatus> _status(String method, [Object? argument]) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      method,
      argument,
    );
    return HealthConnectStatus.fromMap(map ?? const {});
  }
}
