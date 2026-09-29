import 'package:flutter/services.dart';

/// This installation's sync identity, in storage that no backup or device
/// transfer copies (backend architecture section 3).
///
/// The SQLite `settings` table also holds `sync_installation_id`, but Android
/// backs that database up and transfers it to new devices. Only a value found
/// in both places identifies this installation.
abstract interface class InstallationMarkerStore {
  Future<String?> read();

  Future<void> write(String installationId);
}

/// `SyncInstallationMarker.kt`, a SharedPreferences file excluded from Auto
/// Backup and device-to-device transfer.
///
/// Unlike the credential store, failures are not swallowed: treating an
/// unreadable marker as absent would replace a working identity, and an
/// unwritable one would mint a new identity on every attempt. The sync
/// operation fails instead, before anything is registered.
class AndroidInstallationMarkerStore implements InstallationMarkerStore {
  const AndroidInstallationMarkerStore({
    MethodChannel channel = const MethodChannel('focustrace/sync'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<String?> read() =>
      _channel.invokeMethod<String>('readInstallationMarker');

  @override
  Future<void> write(String installationId) =>
      _channel.invokeMethod<void>('writeInstallationMarker', installationId);
}
