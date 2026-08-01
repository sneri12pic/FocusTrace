import 'dart:convert';

import '../../domain/models/block_routine.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/focus_trace_local_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._localDataSource);

  static const _trackingIntervalSecondsKey = 'tracking_interval_seconds';
  static const _idleTimeoutSecondsKey = 'idle_timeout_seconds';
  static const _excludedAppsKey = 'excluded_apps';
  static const _hiddenAppsTodayKey = 'hidden_apps_today';
  static const _restrictionRulesKey = 'restriction_rules';
  static const _blockRoutinesKey = 'block_routines';
  static const _onboardingCompletedKey = 'onboarding_completed';

  final FocusTraceLocalDataSource _localDataSource;

  @override
  Future<int> trackingIntervalSeconds() async {
    final rawValue = await _localDataSource.readSetting(
      _trackingIntervalSecondsKey,
    );
    return _parsePositiveInt(rawValue) ?? 5;
  }

  @override
  Future<void> setTrackingIntervalSeconds(int seconds) {
    return _localDataSource.writeSetting(
      _trackingIntervalSecondsKey,
      seconds.clamp(1, 3600).toString(),
    );
  }

  @override
  Future<int> idleTimeoutSeconds() async {
    final rawValue = await _localDataSource.readSetting(_idleTimeoutSecondsKey);
    return _parsePositiveInt(rawValue) ?? 60;
  }

  @override
  Future<void> setIdleTimeoutSeconds(int seconds) {
    return _localDataSource.writeSetting(
      _idleTimeoutSecondsKey,
      seconds.clamp(5, 86400).toString(),
    );
  }

  @override
  Future<List<String>> excludedApps() async {
    final rawValue = await _localDataSource.readSetting(_excludedAppsKey);
    return _decodeStringList(rawValue);
  }

  @override
  Future<void> addExcludedApp(String appKey) async {
    final apps = await excludedApps();
    if (apps.contains(appKey)) {
      return;
    }
    await _localDataSource.writeSetting(
      _excludedAppsKey,
      jsonEncode([...apps, appKey]),
    );
  }

  @override
  Future<void> removeExcludedApp(String appKey) async {
    final apps = await excludedApps();
    await _localDataSource.writeSetting(
      _excludedAppsKey,
      jsonEncode(apps.where((app) => app != appKey).toList()),
    );
  }

  @override
  Future<Set<String>> hiddenAppsForToday() async {
    final rawValue = await _localDataSource.readSetting(_hiddenAppsTodayKey);
    if (rawValue == null) {
      return const <String>{};
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, Object?> ||
          decoded['date'] != _todayKey() ||
          decoded['apps'] is! List) {
        return const <String>{};
      }
      return (decoded['apps'] as List).whereType<String>().toSet();
    } on FormatException {
      return const <String>{};
    }
  }

  @override
  Future<void> hideAppForToday(String appKey) async {
    final hidden = await hiddenAppsForToday();
    await _localDataSource.writeSetting(
      _hiddenAppsTodayKey,
      jsonEncode({
        'date': _todayKey(),
        'apps': {...hidden, appKey}.toList(),
      }),
    );
  }

  @override
  Future<bool> onboardingCompleted() async {
    return await _localDataSource.readSetting(_onboardingCompletedKey) ==
        'true';
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) {
    return _localDataSource.writeSetting(
      _onboardingCompletedKey,
      completed.toString(),
    );
  }

  @override
  Future<List<RestrictionRule>> restrictionRules() async {
    final rules = decodeRules(
      await _localDataSource.readSetting(_restrictionRulesKey),
    );
    final pruned = pruneExpiredBlockNowRules(rules);
    if (pruned.length != rules.length) {
      await _writeRestrictionRules(pruned);
    }
    return pruned;
  }

  @override
  Future<void> saveRestrictionRule(RestrictionRule rule) async {
    final rules = await restrictionRules();
    final upserted = [
      for (final existing in rules)
        if (existing.appKey != rule.appKey || existing.type != rule.type)
          existing,
      rule,
    ];
    await _writeRestrictionRules(upserted);
  }

  @override
  Future<void> removeRestrictionRule(
    String appKey,
    RestrictionRuleType type,
  ) async {
    final rules = await restrictionRules();
    await _writeRestrictionRules(
      rules
          .where((rule) => rule.appKey != appKey || rule.type != type)
          .toList(),
    );
  }

  @override
  Future<List<BlockRoutine>> blockRoutines() async {
    return decodeBlockRoutines(
      await _localDataSource.readSetting(_blockRoutinesKey),
    );
  }

  @override
  Future<void> saveBlockRoutine(BlockRoutine routine) async {
    final routines = await blockRoutines();
    await _writeBlockRoutines([
      for (final existing in routines)
        if (existing.id != routine.id) existing,
      routine,
    ]);
  }

  @override
  Future<void> removeBlockRoutine(String id) async {
    final routines = await blockRoutines();
    await _writeBlockRoutines(
      routines.where((routine) => routine.id != id).toList(),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  List<String> _decodeStringList(String? rawValue) {
    if (rawValue == null) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return const <String>[];
      }
      return decoded.whereType<String>().toList();
    } on FormatException {
      return const <String>[];
    }
  }

  int? _parsePositiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  Future<void> _writeRestrictionRules(List<RestrictionRule> rules) {
    return _localDataSource.writeSetting(
      _restrictionRulesKey,
      encodeRules(rules),
    );
  }

  Future<void> _writeBlockRoutines(List<BlockRoutine> routines) {
    return _localDataSource.writeSetting(
      _blockRoutinesKey,
      encodeBlockRoutines(routines),
    );
  }
}
