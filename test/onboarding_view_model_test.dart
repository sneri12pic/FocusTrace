import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

class _FakeSettingsRepository implements SettingsRepository {
  bool completed = false;
  final List<RestrictionRule> rules = <RestrictionRule>[];

  @override
  Future<List<BlockRoutine>> blockRoutines() async => const [];

  @override
  Future<void> saveBlockRoutine(BlockRoutine routine) async {}

  @override
  Future<void> removeBlockRoutine(String id) async {}

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
  Future<bool> onboardingCompleted() async => completed;

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
  Future<void> setOnboardingCompleted(bool completed) async {
    this.completed = completed;
  }

  @override
  Future<void> setTrackingIntervalSeconds(int seconds) async {}

  @override
  Future<int> trackingIntervalSeconds() async => 5;
}

void main() {
  test(
    'completeWithSoftBlocks saves daily limits and marks completed',
    () async {
      final repository = _FakeSettingsRepository();
      final viewModel = OnboardingViewModel(settingsRepository: repository);
      await viewModel.load();

      viewModel.toggleApp('com.example.social');
      viewModel.toggleApp('com.example.video');
      viewModel.updateLimitMinutes(45);
      await viewModel.completeWithSoftBlocks(const [
        AppUsageSummary(
          appName: 'Social',
          packageName: 'com.example.social',
          totalDurationSeconds: 3600,
          percentageOfTotal: 0.5,
        ),
        AppUsageSummary(
          appName: 'Video',
          packageName: 'com.example.video',
          totalDurationSeconds: 3600,
          percentageOfTotal: 0.5,
        ),
      ]);

      expect(viewModel.state.isCompleted, isTrue);
      expect(repository.completed, isTrue);
      expect(repository.rules, hasLength(2));
      expect(
        repository.rules.map((rule) => '${rule.appName}:${rule.limitMinutes}'),
        containsAll(['Social:45', 'Video:45']),
      );
    },
  );

  test('skip marks onboarding complete without rules', () async {
    final repository = _FakeSettingsRepository();
    final viewModel = OnboardingViewModel(settingsRepository: repository);

    await viewModel.skip();

    expect(viewModel.state.isCompleted, isTrue);
    expect(repository.completed, isTrue);
    expect(repository.rules, isEmpty);
  });
}
