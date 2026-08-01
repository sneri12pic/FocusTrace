import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/platform_usage_data_source.dart';
import '../../domain/models/block_routine.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/settings_repository.dart';

class RestrictionsState {
  const RestrictionsState({
    required this.platform,
    this.rules = const <RestrictionRule>[],
    this.routines = const <BlockRoutine>[],
    this.hasOverlayPermission = true,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  factory RestrictionsState.initial(UsagePlatform platform) {
    return RestrictionsState(
      platform: platform,
      hasOverlayPermission: platform != UsagePlatform.android,
      isLoading: true,
    );
  }

  final UsagePlatform platform;
  final List<RestrictionRule> rules;
  final List<BlockRoutine> routines;
  final bool hasOverlayPermission;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  RestrictionsState copyWith({
    List<RestrictionRule>? rules,
    List<BlockRoutine>? routines,
    bool? hasOverlayPermission,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RestrictionsState(
      platform: platform,
      rules: rules ?? this.rules,
      routines: routines ?? this.routines,
      hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RestrictionsViewModel extends StateNotifier<RestrictionsState> {
  RestrictionsViewModel({
    required SettingsRepository settingsRepository,
    required PlatformUsageDataSource platformDataSource,
    required UsagePlatform platform,
  }) : _settingsRepository = settingsRepository,
       _platformDataSource = platformDataSource,
       super(RestrictionsState.initial(platform));

  final SettingsRepository _settingsRepository;
  final PlatformUsageDataSource _platformDataSource;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final (rules, routines) = await (
        _settingsRepository.restrictionRules(),
        _settingsRepository.blockRoutines(),
      ).wait;
      final hasOverlayPermission = await _platformDataSource
          .hasOverlayPermission();
      state = state.copyWith(
        rules: rules,
        routines: routines,
        hasOverlayPermission: hasOverlayPermission,
        isLoading: false,
      );
      await _sync(rules, routines);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> saveRule(RestrictionRule rule) {
    return _mutateRules(() => _settingsRepository.saveRestrictionRule(rule));
  }

  Future<void> deleteRule(String appKey, RestrictionRuleType type) {
    return _mutateRules(
      () => _settingsRepository.removeRestrictionRule(appKey, type),
    );
  }

  Future<void> unblockAppNow({
    required String appKey,
    required int usageSecondsToday,
    DateTime? now,
  }) {
    return _mutateRules(() async {
      final currentRules = await _settingsRepository.restrictionRules();
      final checkedAt = now ?? DateTime.now();
      final blockingRules = currentRules.where(
        (rule) =>
            rule.appKey == appKey &&
            rule.blocksAt(checkedAt, usageSecondsToday),
      );
      for (final rule in blockingRules) {
        await _settingsRepository.removeRestrictionRule(rule.appKey, rule.type);
      }
    });
  }

  /// Runs [mutation], then reloads rules, rechecks the overlay permission,
  /// and pushes the new configuration to the platform side.
  Future<void> _mutateRules(Future<void> Function() mutation) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await mutation();
      final rules = await _settingsRepository.restrictionRules();
      final hasOverlayPermission = await _platformDataSource
          .hasOverlayPermission();
      state = state.copyWith(
        rules: rules,
        hasOverlayPermission: hasOverlayPermission,
        isSaving: false,
      );
      await _sync(rules, state.routines);
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> openOverlaySettings() async {
    await _platformDataSource.openOverlaySettings();
  }

  Future<void> requestNotificationsPermission() async {
    await _platformDataSource.requestNotificationsPermission();
  }

  Future<void> refreshOverlayPermission() async {
    final hasOverlayPermission = await _platformDataSource
        .hasOverlayPermission();
    state = state.copyWith(hasOverlayPermission: hasOverlayPermission);
    await _sync(state.rules, state.routines);
  }

  Future<void> saveRoutine(BlockRoutine routine) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _settingsRepository.saveBlockRoutine(routine);
      final routines = await _settingsRepository.blockRoutines();
      state = state.copyWith(routines: routines, isSaving: false);
      await _sync(state.rules, routines);
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> setRoutineEnabled(BlockRoutine routine, bool isEnabled) {
    return saveRoutine(routine.copyWith(isEnabled: isEnabled));
  }

  Future<void> deleteRoutine(String id) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _settingsRepository.removeBlockRoutine(id);
      final routines = await _settingsRepository.blockRoutines();
      state = state.copyWith(routines: routines, isSaving: false);
      await _sync(state.rules, routines);
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> _sync(List<RestrictionRule> rules, List<BlockRoutine> routines) {
    return _platformDataSource.syncRestrictions(
      encodeRestrictionConfiguration(rules, routines),
    );
  }
}
