import 'package:flutter/services.dart';

/// Platform edge only: the repository supplies the authoritative opt-in value.
class AndroidSyncScheduler {
  const AndroidSyncScheduler();
  static const channel = MethodChannel('focustrace/sync');

  Future<void> reconcile(bool enabled) =>
      channel.invokeMethod<void>('scheduleSync', enabled);

  Future<String> deviceModel() async =>
      await channel.invokeMethod<String>('deviceModel') ?? 'Android device';
}
