import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

class _FakeSettingsRepository implements SettingsRepository {
  final List<RestrictionRule> rules = <RestrictionRule>[];
  final List<BlockRoutine> routines = <BlockRoutine>[];

  @override
  Future<List<BlockRoutine>> blockRoutines() async => List.of(routines);

  @override
  Future<void> saveBlockRoutine(BlockRoutine routine) async {
    routines.removeWhere((existing) => existing.id == routine.id);
    routines.add(routine);
  }

  @override
  Future<void> removeBlockRoutine(String id) async {
    routines.removeWhere((routine) => routine.id == id);
  }

  @override
  Future<void> addExcludedApp(String appKey) async {}

  @override
  Future<List<String>> excludedApps() async => const <String>[];

  @override
  Future<void> hideAppForToday(String appKey) async {}

  @override
  Future<Set<String>> hiddenAppsForToday() async => const <String>{};

  @override
  Future<int> idleTimeoutSeconds() async => 60;

  @override
  Future<bool> onboardingCompleted() async => true;

  @override
  Future<void> removeExcludedApp(String appKey) async {}

  @override
  Future<void> removeRestrictionRule(
    String appKey,
    RestrictionRuleType type,
  ) async {
    rules.removeWhere((rule) => rule.appKey == appKey && rule.type == type);
  }

  @override
  Future<List<RestrictionRule>> restrictionRules() async => List.of(rules);

  @override
  Future<void> saveRestrictionRule(RestrictionRule rule) async {
    rules.removeWhere(
      (existing) =>
          existing.appKey == rule.appKey && existing.type == rule.type,
    );
    rules.add(rule);
  }

  @override
  Future<void> setIdleTimeoutSeconds(int seconds) async {}

  @override
  Future<void> setOnboardingCompleted(bool completed) async {}

  @override
  Future<void> setTrackingIntervalSeconds(int seconds) async {}

  @override
  Future<int> trackingIntervalSeconds() async => 5;
}

class _FakePlatformDataSource implements PlatformUsageDataSource {
  final List<String> syncedPayloads = <String>[];
  bool overlayPermission = true;

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() async => null;

  @override
  Future<List<AppUsageSummary>> getInstalledApps() async =>
      const <AppUsageSummary>[];

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() async =>
      const <AppUsageSummary>[];

  @override
  Future<bool> hasOverlayPermission() async => overlayPermission;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> requestNotificationsPermission() async {}

  @override
  Future<void> syncRestrictions(String json) async {
    syncedPayloads.add(json);
  }
}

void main() {
  late _FakeSettingsRepository repository;
  late _FakePlatformDataSource dataSource;
  late RestrictionsViewModel viewModel;

  setUp(() {
    repository = _FakeSettingsRepository();
    dataSource = _FakePlatformDataSource();
    viewModel = RestrictionsViewModel(
      settingsRepository: repository,
      platformDataSource: dataSource,
      platform: UsagePlatform.android,
    );
  });

  test('load syncs stored rules', () async {
    repository.rules.add(
      RestrictionRule.dailyLimit(
        appKey: 'app',
        appName: 'App',
        limitMinutes: 30,
      ),
    );

    await viewModel.load();

    expect(viewModel.state.rules, hasLength(1));
    expect(decodeRules(dataSource.syncedPayloads.single), hasLength(1));
  });

  test('save upserts and syncs after mutation', () async {
    await viewModel.saveRule(
      RestrictionRule.dailyLimit(
        appKey: 'app',
        appName: 'App',
        limitMinutes: 30,
      ),
    );
    await viewModel.saveRule(
      RestrictionRule.dailyLimit(
        appKey: 'app',
        appName: 'App',
        limitMinutes: 45,
      ),
    );

    expect(viewModel.state.rules, hasLength(1));
    expect(viewModel.state.rules.single.limitMinutes, 45);
    expect(dataSource.syncedPayloads, hasLength(2));
  });

  test('delete syncs after mutation', () async {
    final rule = RestrictionRule.dailyLimit(
      appKey: 'app',
      appName: 'App',
      limitMinutes: 30,
    );
    await viewModel.saveRule(rule);
    await viewModel.deleteRule(rule.appKey, rule.type);

    expect(viewModel.state.rules, isEmpty);
    expect(decodeRules(dataSource.syncedPayloads.last), isEmpty);
  });

  test('overlay permission refresh syncs current rules', () async {
    await viewModel.saveRule(
      RestrictionRule.dailyLimit(
        appKey: 'app',
        appName: 'App',
        limitMinutes: 30,
      ),
    );
    dataSource.syncedPayloads.clear();
    dataSource.overlayPermission = false;

    await viewModel.refreshOverlayPermission();

    expect(viewModel.state.hasOverlayPermission, isFalse);
    expect(decodeRules(dataSource.syncedPayloads.single), hasLength(1));
  });

  test('routine mutations persist and sync only enabled app groups', () async {
    final routine = BlockRoutine(
      id: 'focus',
      name: 'Focus',
      apps: const [
        RoutineApp(appKey: 'social', appName: 'Social'),
        RoutineApp(appKey: 'video', appName: 'Video'),
      ],
    );

    await viewModel.saveRoutine(routine);

    expect(viewModel.state.routines, [routine]);
    expect(dataSource.syncedPayloads.last, contains('"routineBlocks"'));
    expect(dataSource.syncedPayloads.last, contains('"social"'));
    expect(dataSource.syncedPayloads.last, contains('"video"'));

    await viewModel.setRoutineEnabled(routine, false);

    expect(viewModel.state.routines.single.isEnabled, isFalse);
    expect(dataSource.syncedPayloads.last, isNot(contains('"social"')));

    await viewModel.deleteRoutine(routine.id);

    expect(viewModel.state.routines, isEmpty);
  });

  test('unblock now removes all currently blocking rules for an app', () async {
    final now = DateTime(2026, 7, 4, 22, 30);
    repository.rules.addAll([
      RestrictionRule.dailyLimit(
        appKey: 'app',
        appName: 'App',
        limitMinutes: 60,
      ),
      RestrictionRule.schedule(
        appKey: 'app',
        appName: 'App',
        startMinute: 22 * 60,
        endMinute: 7 * 60,
      ),
      RestrictionRule.blockNow(
        appKey: 'app',
        appName: 'App',
        until: now.subtract(const Duration(minutes: 1)),
      ),
      RestrictionRule.schedule(
        appKey: 'other',
        appName: 'Other',
        startMinute: 22 * 60,
        endMinute: 7 * 60,
      ),
    ]);

    await viewModel.unblockAppNow(
      appKey: 'app',
      usageSecondsToday: 60 * 60,
      now: now,
    );

    expect(
      viewModel.state.rules.map((rule) => '${rule.appKey}:${rule.type.name}'),
      ['app:blockNow', 'other:schedule'],
    );
    expect(
      decodeRules(
        dataSource.syncedPayloads.single,
      ).map((rule) => '${rule.appKey}:${rule.type.name}'),
      ['app:blockNow', 'other:schedule'],
    );
  });
}
