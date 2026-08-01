import 'package:flutter/services.dart';

import '../../domain/models/app_language.dart';

abstract class PlatformLocaleDataSource {
  Future<void> applyLanguage(AppLanguage language);
}

class AndroidPlatformLocaleDataSource implements PlatformLocaleDataSource {
  AndroidPlatformLocaleDataSource({
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
