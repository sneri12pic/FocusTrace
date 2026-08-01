import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/repositories/settings_repository.dart';

class OnboardingState {
  const OnboardingState({
    this.isLoading = true,
    this.isCompleted = false,
    this.selectedAppKeys = const <String>{},
    this.limitMinutes = 60,
    this.isSaving = false,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isCompleted;
  final Set<String> selectedAppKeys;
  final int limitMinutes;
  final bool isSaving;
  final String? errorMessage;

  OnboardingState copyWith({
    bool? isLoading,
    bool? isCompleted,
    Set<String>? selectedAppKeys,
    int? limitMinutes,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      selectedAppKeys: selectedAppKeys ?? this.selectedAppKeys,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class OnboardingViewModel extends StateNotifier<OnboardingState> {
  OnboardingViewModel({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository,
      super(const OnboardingState());

  final SettingsRepository _settingsRepository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      state = state.copyWith(
        isLoading: false,
        isCompleted: await _settingsRepository.onboardingCompleted(),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void toggleApp(String appKey) {
    final next = Set<String>.of(state.selectedAppKeys);
    if (!next.add(appKey)) {
      next.remove(appKey);
    }
    state = state.copyWith(selectedAppKeys: next, clearError: true);
  }

  void updateLimitMinutes(int minutes) {
    state = state.copyWith(limitMinutes: minutes.clamp(5, 480));
  }

  Future<void> completeWithSoftBlocks(List<AppUsageSummary> summaries) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final summariesByKey = {
        for (final summary in summaries) summary.appKey: summary,
      };
      for (final appKey in state.selectedAppKeys) {
        final summary = summariesByKey[appKey];
        await _settingsRepository.saveRestrictionRule(
          RestrictionRule.dailyLimit(
            appKey: appKey,
            appName: summary?.appName ?? appKey,
            limitMinutes: state.limitMinutes,
          ),
        );
      }
      await _settingsRepository.setOnboardingCompleted(true);
      state = state.copyWith(isSaving: false, isCompleted: true);
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> skip() async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _settingsRepository.setOnboardingCompleted(true);
      state = state.copyWith(isSaving: false, isCompleted: true);
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }
}
