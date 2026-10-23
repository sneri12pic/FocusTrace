import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

class _FakeSettingsRepository implements SettingsRepository {
  Map<String, UsageCategory> categories = {};

  @override
  Future<Map<String, UsageCategory>> appCategoryOverrides() async =>
      Map.of(categories);

  @override
  Future<void> setAppCategoryOverrides(
    Map<String, UsageCategory> overrides,
  ) async {
    categories = Map.of(overrides);
  }

  UsageDetailsChart chart = UsageDetailsChart.bars;

  @override
  Future<UsageDetailsChart> usageDetailsChart() async => chart;

  @override
  Future<void> setUsageDetailsChart(UsageDetailsChart value) async {
    chart = value;
  }

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
  bool notificationsPermission = true;

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
  Future<bool> hasNotificationsPermission() async => notificationsPermission;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<bool> requestNotificationsPermission() async =>
      notificationsPermission;

  @override
  Future<void> syncRestrictions(String json) async {
    syncedPayloads.add(json);
  }
}

class _FakeReportRepository implements ReportRepository {
  final events = <RestrictionEvent>[];

  @override
  Future<UsageReportSourceData> loadSourceData(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => const UsageReportSourceData(
    dailyUsage: [],
    intervals: [],
    restrictionEvents: [],
  );

  @override
  Future<void> recordRestrictionEvent(RestrictionEvent event) async {
    events.add(event);
  }
}

void main() {
  difficultyTests();
  late _FakeSettingsRepository repository;
  late _FakePlatformDataSource dataSource;
  late _FakeReportRepository reportRepository;
  late RestrictionsViewModel viewModel;

  setUp(() {
    repository = _FakeSettingsRepository();
    dataSource = _FakePlatformDataSource();
    reportRepository = _FakeReportRepository();
    viewModel = RestrictionsViewModel(
      settingsRepository: repository,
      platformDataSource: dataSource,
      platform: UsagePlatform.android,
      reportRepository: reportRepository,
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

  test('notification permission result updates state', () async {
    dataSource.notificationsPermission = false;
    await viewModel.load();
    expect(viewModel.state.hasNotificationsPermission, isFalse);

    dataSource.notificationsPermission = true;
    await viewModel.requestNotificationsPermission();

    expect(viewModel.state.hasNotificationsPermission, isTrue);
  });

  test('routine mutations persist and sync only enabled app groups', () async {
    final routine = BlockRoutine(
      id: 'focus',
      name: 'Focus',
      dailyLimitMinutes: 60,
      isEnabled: true,
      apps: const [
        RoutineApp(appKey: 'social', appName: 'Social'),
        RoutineApp(appKey: 'video', appName: 'Video'),
      ],
    );

    await viewModel.saveRoutine(routine);

    expect(viewModel.state.routines, [routine]);
    expect(dataSource.syncedPayloads.last, contains('"routines"'));
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
    expect(reportRepository.events, hasLength(1));
    expect(reportRepository.events.single.type, RestrictionEventType.unblocked);
    expect(reportRepository.events.single.occurredAt, now);
  });
}

class _GuardPlatform extends _FakePlatformDataSource
    implements RestrictionChangeDataSource {
  String status = 'allowed';
  String? accepted;
  bool rejectSync = false;
  @override
  Future<String?> readRestrictionConfiguration() async => accepted;
  @override
  Future<String> requestRestrictionChange(String key, String type) async =>
      status;
  @override
  Future<void> syncRestrictions(String json) async {
    if (rejectSync) throw StateError('restriction:hard');
    await super.syncRestrictions(json);
    accepted = json;
  }
}

void difficultyTests() {
  test(
    'native denial protects edit, type change, delete and unblock',
    () async {
      final settings = _FakeSettingsRepository();
      final platform = _GuardPlatform();
      final original = RestrictionRule.blockNow(
        appKey: 'a',
        appName: 'A',
        until: DateTime.now().add(const Duration(hours: 1)),
      ).copyWith(difficulty: RestrictionDifficulty.hard);
      settings.rules.add(original);
      final vm = RestrictionsViewModel(
        settingsRepository: settings,
        platformDataSource: platform,
        platform: UsagePlatform.android,
      );
      await vm.load();
      platform.status = 'hard';
      await vm.saveRule(
        RestrictionRule.dailyLimit(appKey: 'a', appName: 'A', limitMinutes: 1),
        replacing: original,
      );
      expect(settings.rules.single, original);
      await vm.deleteRule('a', RestrictionRuleType.blockNow);
      expect(settings.rules.single, original);
      await vm.unblockAppNow(appKey: 'a', usageSecondsToday: 0);
      expect(settings.rules.single, original);
      expect(vm.state.errorMessage, contains('restriction:hard'));
      expect(platform.syncedPayloads, hasLength(1));
      vm.dispose();
    },
  );

  test(
    'cooldown leaves rule intact until subsequent approved action',
    () async {
      final settings = _FakeSettingsRepository();
      final platform = _GuardPlatform();
      final rule = RestrictionRule.blockNow(
        appKey: 'a',
        appName: 'A',
        until: DateTime.now().add(const Duration(hours: 1)),
      ).copyWith(difficulty: RestrictionDifficulty.moderate);
      settings.rules.add(rule);
      final vm = RestrictionsViewModel(
        settingsRepository: settings,
        platformDataSource: platform,
        platform: UsagePlatform.android,
      );
      await vm.load();
      platform.status = 'cooldown';
      await vm.deleteRule('a', RestrictionRuleType.blockNow);
      expect(settings.rules.single, rule);
      platform.status = 'allowed';
      await vm.deleteRule('a', RestrictionRuleType.blockNow);
      expect(settings.rules, isEmpty);
      expect(vm.state.rules, isEmpty);
      vm.dispose();
    },
  );

  test(
    'accepted native config recovers local mirror and type edits replace',
    () async {
      final settings = _FakeSettingsRepository();
      final platform = _GuardPlatform();
      final original = RestrictionRule.dailyLimit(
        appKey: 'a',
        appName: 'A',
        limitMinutes: 30,
      );
      platform.accepted = encodeRestrictionConfiguration([original], []);
      platform.rejectSync = true;
      final vm = RestrictionsViewModel(
        settingsRepository: settings,
        platformDataSource: platform,
        platform: UsagePlatform.android,
      );
      await vm.load();
      expect(settings.rules.single.type, RestrictionRuleType.dailyLimit);
      platform.rejectSync = false;
      await vm.saveRule(
        RestrictionRule.schedule(
          appKey: 'a',
          appName: 'A',
          startMinute: 540,
          endMinute: 1020,
        ),
        replacing: original,
      );
      expect(settings.rules, hasLength(1));
      expect(settings.rules.single.type, RestrictionRuleType.schedule);
      vm.dispose();
    },
  );
}
