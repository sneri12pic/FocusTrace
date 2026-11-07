import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focustrace/focus_trace.dart';

Map<String, bool> _fields(PlatformCapabilities c) => {
  'usageNumbersInFlutter': c.usageNumbersInFlutter,
  'usageAccessPermission': c.usageAccessPermission,
  'overlayPermission': c.overlayPermission,
  'notificationsPermission': c.notificationsPermission,
  'screenTimeAuthorization': c.screenTimeAuthorization,
  'installedAppList': c.installedAppList,
  'nativeAppPicker': c.nativeAppPicker,
  'appBlocking': c.appBlocking,
  'dailyLimits': c.dailyLimits,
  'activeWindowTracking': c.activeWindowTracking,
  'osHistoryImport': c.osHistoryImport,
  'dataTransfer': c.dataTransfer,
  'workoutsImport': c.workoutsImport,
  'cloudSync': c.cloudSync,
  'platformLocale': c.platformLocale,
};

Set<String> _enabled(UsagePlatform platform) => {
  for (final entry in _fields(
    PlatformCapabilities.forPlatform(platform),
  ).entries)
    if (entry.value) entry.key,
};

void main() {
  test('Android keeps every capability the app has shipped with', () {
    expect(_enabled(UsagePlatform.android), {
      'usageNumbersInFlutter',
      'usageAccessPermission',
      'overlayPermission',
      'notificationsPermission',
      'installedAppList',
      'appBlocking',
      'dailyLimits',
      'osHistoryImport',
      'dataTransfer',
      'workoutsImport',
      'cloudSync',
      'platformLocale',
    });
  });

  test('Windows tracks the active window and needs no permissions', () {
    expect(_enabled(UsagePlatform.windows), {
      'usageNumbersInFlutter',
      'dailyLimits',
      'activeWindowTracking',
    });
  });

  test('iOS describes Screen Time: no numbers or app list in Flutter', () {
    expect(_enabled(UsagePlatform.ios), {
      'notificationsPermission',
      'screenTimeAuthorization',
      'nativeAppPicker',
      'appBlocking',
      'dailyLimits',
    });
  });

  test('other platforms have no capabilities', () {
    for (final platform in [
      UsagePlatform.macos,
      UsagePlatform.linux,
      UsagePlatform.unsupported,
    ]) {
      expect(_enabled(platform), isEmpty, reason: platform.name);
    }
  });

  test('provider follows the usage platform', () {
    final container = ProviderContainer(
      overrides: [usagePlatformProvider.overrideWithValue(UsagePlatform.ios)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(platformCapabilitiesProvider),
      same(PlatformCapabilities.ios),
    );
    expect(
      container.read(platformDataSourceProvider),
      isA<IosUsageDataSource>(),
    );
  });
}
