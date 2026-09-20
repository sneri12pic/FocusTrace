import 'package:flutter/services.dart';

import 'focus_trace_sync_api.dart';

/// The Android implementation of [SyncCredentialStore].
///
/// The token is sealed by `SecureCredentialStore.kt` under an AndroidKeyStore
/// AES-GCM key, so nothing readable crosses this channel in either direction
/// except the token itself, and nothing readable is at rest. Access tokens are
/// deliberately absent: they are short-lived and stay in memory inside
/// [FocusTraceSyncApi].
///
/// Only constructed when [syncSupportedProvider] is true, which already
/// requires Android; on any other platform the channel would not answer.
class SecureSyncCredentialStore implements SyncCredentialStore {
  const SecureSyncCredentialStore({
    MethodChannel channel = const MethodChannel('focustrace/usage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  /// A platform failure is not distinguished from an absent credential: both
  /// mean this installation cannot present a refresh token, and the caller's
  /// only correct response to either is to treat the app as signed out.
  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _channel.invokeMethod<String>('readSyncCredential');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Swallows a platform failure so a keystore that will not write cannot turn
  /// a sign-in into an app error. The session then lives only as long as the
  /// process, which is exactly the behaviour that preceded this store.
  @override
  Future<void> writeRefreshToken(String token) async {
    try {
      await _channel.invokeMethod<void>('writeSyncCredential', token);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearSyncCredential');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
