import 'package:flutter/services.dart';

import '../../domain/models/app_language.dart';

abstract class PlatformLocaleDataSource {
  Future<void> applyLanguage(AppLanguage language);
}

/// `setAppLocale` on `focustrace/usage`. Android stores the language for its
/// native texts and widget; iOS sets the app's `AppleLanguages` (system
/// pickers and sheets follow from the next launch) and the extensions'
/// language. Null means the device language.
class MethodChannelPlatformLocaleDataSource
    implements PlatformLocaleDataSource {
  MethodChannelPlatformLocaleDataSource({
    MethodChannel channel = const MethodChannel('focustrace/usage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> applyLanguage(AppLanguage language) {
    return _channel.invokeMethod<void>('setAppLocale', language.localeTag);
  }
}

class NoOpPlatformLocaleDataSource implements PlatformLocaleDataSource {
  const NoOpPlatformLocaleDataSource();

  @override
  Future<void> applyLanguage(AppLanguage language) async {}
}
