import 'package:flutter/services.dart';

import '../../domain/models/app_usage_interval.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../performance/dashboard_performance.dart';

class ActiveWindowInfo {
  const ActiveWindowInfo({
    required this.processName,
    required this.windowTitle,
    required this.idleSeconds,
  });

  final String processName;
  final String windowTitle;
  final double idleSeconds;

  String get appName => processName;
}

abstract class PlatformUsageDataSource {
  Future<bool> hasUsageAccess();

  Future<void> openUsageAccessSettings();

  Future<bool> hasOverlayPermission();

  Future<void> openOverlaySettings();

  Future<bool> hasNotificationsPermission();

  Future<bool> requestNotificationsPermission();

  Future<void> syncRestrictions(String json);

  Future<List<AppUsageSummary>> getTodayUsageStats();

  Future<ActiveWindowInfo?> getActiveWindowInfo();

  /// Launchable installed apps (name, package, icon) with zero usage.
  /// Empty where unsupported.
  Future<List<AppUsageSummary>> getInstalledApps();
}

abstract interface class AppMetadataDataSource {
  /// Current metadata for the requested app keys. Missing/uninstalled apps are
  /// omitted.
  Future<List<AppUsageSummary>> getAppMetadata(Iterable<String> appKeys);
}

abstract interface class UsageIntervalDataSource {
  Future<List<AppUsageInterval>> getUsageIntervals(
    DateTime fromInclusive,
    DateTime toExclusive,
  );
}

class AndroidUsageDataSource
    implements
        PlatformUsageDataSource,
        AppMetadataDataSource,
        UsageIntervalDataSource {
  AndroidUsageDataSource({
    MethodChannel channel = const MethodChannel('focustrace/usage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> hasUsageAccess() async {
    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  @override
  Future<void> openUsageAccessSettings() {
    return _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  @override
  Future<bool> hasOverlayPermission() async {
    return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  @override
  Future<void> openOverlaySettings() {
    return _channel.invokeMethod<void>('openOverlaySettings');
  }

  @override
  Future<bool> hasNotificationsPermission() async {
    return await _channel.invokeMethod<bool>('hasNotificationsPermission') ??
        false;
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    return await _channel.invokeMethod<bool>(
          'requestNotificationsPermission',
        ) ??
        false;
  }

  @override
  Future<void> syncRestrictions(String json) {
    return _channel.invokeMethod<void>('syncRestrictions', json);
  }

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() async {
    final hasAccess = await hasUsageAccess();
    if (!hasAccess) {
      throw PlatformException(
        code: 'USAGE_ACCESS_REQUIRED',
        message: 'Usage Access required to read app usage.',
      );
    }

    DashboardPerformance.livePlatformCallStarted();
    final rows = await _channel.invokeListMethod<Object?>(
      'getTodayUsageStats',
      {'benchmarkRunId': DashboardPerformance.currentPlatformFetchRunId},
    );
    final summaries = (rows ?? const <Object?>[])
        .whereType<Map>()
        .map((row) => _summaryFromAndroidMap(Map<String, Object?>.from(row)))
        .toList();

    DashboardPerformance.liveUsageAvailable();

    return summaries;
  }

  @override
  Future<List<AppUsageSummary>> getAppMetadata(Iterable<String> appKeys) async {
    final requestedKeys = appKeys.toSet().toList(growable: false);
    if (requestedKeys.isEmpty) {
      return const <AppUsageSummary>[];
    }
    final rows = await _channel
        .invokeListMethod<Object?>('getAppMetadata', <String, Object?>{
          'packageNames': requestedKeys,
          'benchmarkRunId': DashboardPerformance.currentPlatformFetchRunId,
        });
    return (rows ?? const <Object?>[])
        .whereType<Map>()
        .map((row) => _summaryFromAndroidMap(Map<String, Object?>.from(row)))
        .toList();
  }

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() async {
    throw UnsupportedError(
      'Active window tracking is not available on Android.',
    );
  }

  @override
  Future<List<AppUsageSummary>> getInstalledApps() async {
    final rows = await _channel.invokeListMethod<Object?>('getInstalledApps');
    return (rows ?? const <Object?>[])
        .whereType<Map>()
        .map((row) => _summaryFromAndroidMap(Map<String, Object?>.from(row)))
        .toList();
  }

  @override
  Future<List<AppUsageInterval>> getUsageIntervals(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    if (!await hasUsageAccess()) {
      return const <AppUsageInterval>[];
    }
    final rows = await _channel.invokeListMethod<Object?>('getUsageIntervals', {
      'fromMs': fromInclusive.millisecondsSinceEpoch,
      'toMs': toExclusive.millisecondsSinceEpoch,
    });
    return (rows ?? const <Object?>[])
        .whereType<Map>()
        .map((raw) {
          final row = Map<String, Object?>.from(raw);
          final appKey = row['appKey'] as String;
          final startedAtMs = (row['startedAtMs'] as num).toInt();
          return AppUsageInterval(
            id: row['id'] as String? ?? '$appKey:$startedAtMs',
            appKey: appKey,
            appName: row['appName'] as String? ?? appKey,
            startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
            endedAt: DateTime.fromMillisecondsSinceEpoch(
              (row['endedAtMs'] as num).toInt(),
            ),
          );
        })
        .where((interval) => interval.durationSeconds > 0)
        .toList();
  }

  // Each channel fetch delivers fresh byte arrays; Flutter's image cache is
  // keyed by object identity, so new bytes force a full PNG re-decode of every
  // icon. Icons rarely change — reuse the first-seen bytes per package.
  final _iconBytesByPackage = <String, _CachedAndroidIcon>{};

  AppUsageSummary _summaryFromAndroidMap(Map<String, Object?> row) {
    final durationMs = (row['totalTimeInForegroundMs'] as num?)?.toInt() ?? 0;
    final lastUsedMs = (row['lastTimeUsedMs'] as num?)?.toInt();
    final packageName = row['packageName'] as String?;
    final appName = row['appName'] as String? ?? packageName ?? '';

    var iconBytes = row['iconBytes'] as Uint8List?;
    final freshIconBytes = iconBytes;
    if (freshIconBytes != null && packageName != null) {
      final metadataVersion = (row['metadataVersion'] as num?)?.toInt();
      final cached = _iconBytesByPackage[packageName];
      if (cached == null ||
          (metadataVersion != null &&
              cached.metadataVersion != metadataVersion)) {
        final replacement = _CachedAndroidIcon(
          bytes: freshIconBytes,
          metadataVersion: metadataVersion,
        );
        _iconBytesByPackage[packageName] = replacement;
        iconBytes = replacement.bytes;
      } else {
        iconBytes = cached.bytes;
      }
    }

    return AppUsageSummary(
      appName: appName,
      packageName: packageName,
      totalDurationSeconds: Duration(milliseconds: durationMs).inSeconds,
      percentageOfTotal: 0,
      launchCount: (row['launchCount'] as num?)?.toInt() ?? 0,
      lastUsedAt: lastUsedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastUsedMs),
      iconBytes: iconBytes,
    );
  }
}

class _CachedAndroidIcon {
  const _CachedAndroidIcon({required this.bytes, this.metadataVersion});

  final Uint8List bytes;
  final int? metadataVersion;
}

class WindowsUsageDataSource implements PlatformUsageDataSource {
  WindowsUsageDataSource({
    MethodChannel channel = const MethodChannel('focustrace/windows_usage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<bool> hasOverlayPermission() async => true;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<bool> hasNotificationsPermission() async => true;

  @override
  Future<bool> requestNotificationsPermission() async => true;

  @override
  Future<void> syncRestrictions(String json) async {}

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() {
    throw UnsupportedError(
      'Windows summaries are calculated from locally tracked sessions.',
    );
  }

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() async {
    final row = await _channel.invokeMapMethod<String, Object?>(
      'getActiveWindowInfo',
    );
    if (row == null || row['hasWindow'] != true) {
      return null;
    }
    return ActiveWindowInfo(
      processName: row['processName'] as String? ?? '',
      windowTitle: row['windowTitle'] as String? ?? '',
      idleSeconds: (row['idleSeconds'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<List<AppUsageSummary>> getInstalledApps() async => const [];
}

class UnsupportedPlatformUsageDataSource implements PlatformUsageDataSource {
  const UnsupportedPlatformUsageDataSource();

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<void> openUsageAccessSettings() {
    throw UnsupportedError('Usage permissions are not available.');
  }

  @override
  Future<bool> hasOverlayPermission() async => false;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<bool> hasNotificationsPermission() async => true;

  @override
  Future<bool> requestNotificationsPermission() async => true;

  @override
  Future<void> syncRestrictions(String json) async {}

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() {
    throw UnsupportedError('Usage tracking is not supported on this platform.');
  }

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() {
    throw UnsupportedError('Active window tracking is not supported.');
  }

  @override
  Future<List<AppUsageSummary>> getInstalledApps() async => const [];
}
