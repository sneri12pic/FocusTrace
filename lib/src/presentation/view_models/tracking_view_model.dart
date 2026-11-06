import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/platform_usage_data_source.dart';
import '../../domain/models/platform_capabilities.dart';
import '../../domain/models/tracking_status.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/usage_repository.dart';

class TrackingState {
  const TrackingState({
    required this.status,
    required this.intervalSeconds,
    required this.idleTimeoutSeconds,
    this.isBusy = false,
  });

  factory TrackingState.initial(UsagePlatform platform) {
    return TrackingState(
      status: TrackingStatus.idle(platform),
      intervalSeconds: 5,
      idleTimeoutSeconds: 60,
    );
  }

  final TrackingStatus status;
  final int intervalSeconds;
  final int idleTimeoutSeconds;
  final bool isBusy;

  TrackingState copyWith({
    TrackingStatus? status,
    int? intervalSeconds,
    int? idleTimeoutSeconds,
    bool? isBusy,
  }) {
    return TrackingState(
      status: status ?? this.status,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      idleTimeoutSeconds: idleTimeoutSeconds ?? this.idleTimeoutSeconds,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class TrackingViewModel extends StateNotifier<TrackingState> {
  TrackingViewModel({
    required UsagePlatform platform,
    required PlatformUsageDataSource platformDataSource,
    required UsageRepository usageRepository,
    required SettingsRepository settingsRepository,
    DateTime Function()? clock,
  }) : _platform = platform,
       _platformDataSource = platformDataSource,
       _usageRepository = usageRepository,
       _settingsRepository = settingsRepository,
       _clock = clock ?? DateTime.now,
       super(TrackingState.initial(platform));

  final UsagePlatform _platform;
  late final PlatformCapabilities _capabilities =
      PlatformCapabilities.forPlatform(_platform);
  final PlatformUsageDataSource _platformDataSource;
  final UsageRepository _usageRepository;
  final SettingsRepository _settingsRepository;
  final DateTime Function() _clock;

  Timer? _timer;
  DateTime? _lastSampleAt;

  Future<void> loadSettings() async {
    final interval = await _settingsRepository.trackingIntervalSeconds();
    final idleTimeout = await _settingsRepository.idleTimeoutSeconds();
    state = state.copyWith(
      intervalSeconds: interval,
      idleTimeoutSeconds: idleTimeout,
    );
  }

  Future<void> startTracking() async {
    if (!_capabilities.activeWindowTracking) {
      state = state.copyWith(
        status: TrackingStatus.error(
          platform: _platform,
          message: _platform == UsagePlatform.android
              ? 'Android usage is read from Usage Access and does not need manual tracking.'
              : 'Usage tracking is not supported on this platform yet.',
        ),
      );
      return;
    }

    await loadSettings();
    _timer?.cancel();
    _lastSampleAt = _clock();
    state = state.copyWith(
      status: TrackingStatus.active(_platform),
      isBusy: false,
    );

    await _sampleActiveWindow();
    _timer = Timer.periodic(
      Duration(seconds: state.intervalSeconds),
      (_) => _sampleActiveWindow(),
    );
  }

  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    await _sampleActiveWindow(force: true);
    _lastSampleAt = null;
    state = state.copyWith(
      status: TrackingStatus.idle(_platform),
      isBusy: false,
    );
  }

  Future<void> updateTrackingInterval(int seconds) async {
    final normalized = seconds.clamp(1, 3600);
    await _settingsRepository.setTrackingIntervalSeconds(normalized);
    state = state.copyWith(intervalSeconds: normalized);
    if (state.status.isTracking) {
      await startTracking();
    }
  }

  Future<void> updateIdleTimeout(int seconds) async {
    final normalized = seconds.clamp(5, 86400);
    await _settingsRepository.setIdleTimeoutSeconds(normalized);
    state = state.copyWith(idleTimeoutSeconds: normalized);
  }

  /// A single sample may never record more than this multiple of the
  /// sampling interval. When the timer stalls (system sleep/hibernate, a
  /// suspended process, or a streak of failed samples) the gap since the
  /// previous sample can span hours, and attributing it to whatever window
  /// happens to be in the foreground afterwards would fabricate huge
  /// sessions.
  static const int maxSampleGapMultiplier = 2;

  Future<void> _sampleActiveWindow({bool force = false}) async {
    if (!_capabilities.activeWindowTracking) {
      return;
    }

    final now = _clock();
    try {
      final previousSampleAt = _lastSampleAt;
      final currentInfo = await _platformDataSource.getActiveWindowInfo();

      if (previousSampleAt != null &&
          currentInfo != null &&
          (force || now.difference(previousSampleAt).inSeconds > 0) &&
          currentInfo.idleSeconds < state.idleTimeoutSeconds) {
        // Read fresh each sample so newly excluded apps stop recording
        // immediately, without cross-view-model coordination.
        final excludedApps = await _settingsRepository.excludedApps();
        final maxSampleSeconds = state.intervalSeconds * maxSampleGapMultiplier;
        final gapSeconds = now.difference(previousSampleAt).inSeconds;
        final durationSeconds = gapSeconds > maxSampleSeconds
            ? maxSampleSeconds
            : gapSeconds;
        if (durationSeconds > 0 &&
            !excludedApps.contains(currentInfo.processName) &&
            !excludedApps.contains(currentInfo.appName)) {
          // Keep startedAt consistent with the capped duration: aggregation
          // measures sessions by their timestamps, not durationSeconds.
          final startedAt = now.subtract(Duration(seconds: durationSeconds));
          await _usageRepository.insertSession(
            UsageSession(
              id: '${now.microsecondsSinceEpoch}-${currentInfo.processName}',
              platform: UsagePlatform.windows,
              appName: currentInfo.appName,
              processName: currentInfo.processName,
              windowTitle: currentInfo.windowTitle,
              startedAt: startedAt,
              endedAt: now,
              durationSeconds: durationSeconds,
              createdAt: now,
            ),
          );
        }
      }

      _lastSampleAt = now;
      state = state.copyWith(
        status: state.status.copyWith(lastUpdatedAt: now, clearError: true),
      );
    } catch (error) {
      // The periodic timer is still running, so a transient failure (busy
      // database, channel hiccup during lock/UAC, ...) must not flip
      // isTracking to false: TrackingStatus.error would wedge the UI in a
      // stopped state because the success path only clears the message.
      // Surface the error, keep tracking, and recover on the next sample.
      state = state.copyWith(
        status: state.status.copyWith(
          lastUpdatedAt: now,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
