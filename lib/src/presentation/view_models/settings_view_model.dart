import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/usage_repository.dart';

class SettingsState {
  const SettingsState({
    required this.trackingIntervalSeconds,
    required this.idleTimeoutSeconds,
    this.excludedApps = const <String>[],
    this.excludedAppNames = const <String, String>{},
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  factory SettingsState.initial() {
    return const SettingsState(
      trackingIntervalSeconds: 5,
      idleTimeoutSeconds: 60,
      isLoading: true,
    );
  }

  final int trackingIntervalSeconds;
  final int idleTimeoutSeconds;
  final List<String> excludedApps;
  final Map<String, String> excludedAppNames;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  SettingsState copyWith({
    int? trackingIntervalSeconds,
    int? idleTimeoutSeconds,
    List<String>? excludedApps,
    Map<String, String>? excludedAppNames,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      trackingIntervalSeconds:
          trackingIntervalSeconds ?? this.trackingIntervalSeconds,
      idleTimeoutSeconds: idleTimeoutSeconds ?? this.idleTimeoutSeconds,
      excludedApps: excludedApps ?? this.excludedApps,
      excludedAppNames: excludedAppNames ?? this.excludedAppNames,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SettingsViewModel extends StateNotifier<SettingsState> {
  SettingsViewModel({
    required SettingsRepository settingsRepository,
    required UsageRepository usageRepository,
  }) : _settingsRepository = settingsRepository,
       _usageRepository = usageRepository,
       super(SettingsState.initial());

  final SettingsRepository _settingsRepository;
  final UsageRepository _usageRepository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final interval = await _settingsRepository.trackingIntervalSeconds();
      final idleTimeout = await _settingsRepository.idleTimeoutSeconds();
      final excludedApps = await _settingsRepository.excludedApps();
      final excludedAppNames = await _loadExcludedAppNames(excludedApps);
      state = state.copyWith(
        trackingIntervalSeconds: interval,
        idleTimeoutSeconds: idleTimeout,
        excludedApps: excludedApps,
        excludedAppNames: excludedAppNames,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> updateTrackingInterval(int seconds) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final normalized = seconds.clamp(1, 3600);
      await _settingsRepository.setTrackingIntervalSeconds(normalized);
      state = state.copyWith(
        trackingIntervalSeconds: normalized,
        isSaving: false,
      );
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> updateIdleTimeout(int seconds) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final normalized = seconds.clamp(5, 86400);
      await _settingsRepository.setIdleTimeoutSeconds(normalized);
      state = state.copyWith(idleTimeoutSeconds: normalized, isSaving: false);
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> removeExcludedApp(String appKey) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _settingsRepository.removeExcludedApp(appKey);
      final excludedApps = await _settingsRepository.excludedApps();
      final excludedAppNames = Map<String, String>.of(state.excludedAppNames)
        ..remove(appKey);
      state = state.copyWith(
        excludedApps: excludedApps,
        excludedAppNames: excludedAppNames,
        isSaving: false,
      );
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> clearLocalData() async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _usageRepository.clearAllData();
      await _settingsRepository.setTrackingIntervalSeconds(5);
      await _settingsRepository.setIdleTimeoutSeconds(60);
      state = state.copyWith(
        trackingIntervalSeconds: 5,
        idleTimeoutSeconds: 60,
        excludedApps: const <String>[],
        excludedAppNames: const <String, String>{},
        isSaving: false,
      );
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<Map<String, String>> _loadExcludedAppNames(
    List<String> excludedApps,
  ) async {
    if (excludedApps.isEmpty) {
      return const <String, String>{};
    }
    try {
      final excludedKeys = excludedApps.toSet();
      final summaries = await _usageRepository.getAllTimeSummaries();
      return {
        for (final summary in summaries)
          if (excludedKeys.contains(summary.appKey))
            summary.appKey: summary.appName,
      };
    } catch (_) {
      return const <String, String>{};
    }
  }
}
