import '../models/block_routine.dart';
import '../models/restriction_rule.dart';

abstract class SettingsRepository {
  Future<int> trackingIntervalSeconds();

  Future<void> setTrackingIntervalSeconds(int seconds);

  Future<int> idleTimeoutSeconds();

  Future<void> setIdleTimeoutSeconds(int seconds);

  /// Apps (by app key) permanently excluded from tracking and stats.
  Future<List<String>> excludedApps();

  Future<void> addExcludedApp(String appKey);

  Future<void> removeExcludedApp(String appKey);

  /// Apps (by app key) hidden from today's stats only. Resets each day.
  Future<Set<String>> hiddenAppsForToday();

  Future<void> hideAppForToday(String appKey);

  Future<bool> onboardingCompleted();

  Future<void> setOnboardingCompleted(bool completed);

  Future<List<RestrictionRule>> restrictionRules();

  Future<void> saveRestrictionRule(RestrictionRule rule);

  Future<void> removeRestrictionRule(String appKey, RestrictionRuleType type);

  Future<List<BlockRoutine>> blockRoutines();

  Future<void> saveBlockRoutine(BlockRoutine routine);

  Future<void> removeBlockRoutine(String id);
}
