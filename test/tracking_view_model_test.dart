import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focustrace/focus_trace.dart';

class _FakeSettingsRepository implements SettingsRepository {
  int interval = 5;
  int idleTimeout = 60;

  @override
  Future<List<BlockRoutine>> blockRoutines() async => const [];

  @override
  Future<void> saveBlockRoutine(BlockRoutine routine) async {}

  @override
  Future<void> removeBlockRoutine(String id) async {}

  @override
  Future<int> trackingIntervalSeconds() async => interval;

  @override
  Future<void> setTrackingIntervalSeconds(int seconds) async {
    interval = seconds;
  }

  @override
  Future<int> idleTimeoutSeconds() async => idleTimeout;

  @override
  Future<void> setIdleTimeoutSeconds(int seconds) async {
    idleTimeout = seconds;
  }

  @override
  Future<List<String>> excludedApps() async => const <String>[];

  @override
  Future<void> addExcludedApp(String appKey) async {}

  @override
  Future<void> removeExcludedApp(String appKey) async {}

  @override
  Future<Set<String>> hiddenAppsForToday() async => const <String>{};

  @override
  Future<void> hideAppForToday(String appKey) async {}

  @override
  Future<bool> onboardingCompleted() async => true;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {}

  @override
  Future<List<RestrictionRule>> restrictionRules() async =>
      const <RestrictionRule>[];

  @override
  Future<void> saveRestrictionRule(RestrictionRule rule) async {}

  @override
  Future<void> removeRestrictionRule(
    String appKey,
    RestrictionRuleType type,
  ) async {}
}

class _FakeUsageRepository implements UsageRepository {
  final List<UsageSession> sessions = <UsageSession>[];
  Object? insertError;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<List<AppUsageSummary>> getTodaySummaries() async =>
      const <AppUsageSummary>[];

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async =>
      const <AppUsageSummary>[];

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() async =>
      const <AppUsageSummary>[];

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => const [];

  @override
  Future<void> insertSession(UsageSession session) async {
    final error = insertError;
    if (error != null) {
      throw error;
    }
    sessions.add(session);
  }

  @override
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  }) async => const <UsageSession>[];

  @override
  Future<void> clearAllData() async {
    sessions.clear();
  }
}

class _FakeWindowsDataSource implements PlatformUsageDataSource {
  ActiveWindowInfo? info = const ActiveWindowInfo(
    processName: 'code.exe',
    windowTitle: 'main.dart',
    idleSeconds: 0,
  );
  Object? error;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<bool> hasOverlayPermission() async => true;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<void> requestNotificationsPermission() async {}

  @override
  Future<void> syncRestrictions(String json) async {}

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() async =>
      const <AppUsageSummary>[];

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() async {
    final pending = error;
    if (pending != null) {
      throw pending;
    }
    return info;
  }

  @override
  Future<List<AppUsageSummary>> getInstalledApps() async =>
      const <AppUsageSummary>[];
}

void main() {
  late _FakeSettingsRepository settingsRepository;
  late _FakeUsageRepository usageRepository;
  late _FakeWindowsDataSource dataSource;

  setUp(() {
    settingsRepository = _FakeSettingsRepository();
    usageRepository = _FakeUsageRepository();
    dataSource = _FakeWindowsDataSource();
  });

  TrackingViewModel buildViewModel(DateTime Function() clock) {
    return TrackingViewModel(
      platform: UsagePlatform.windows,
      platformDataSource: dataSource,
      usageRepository: usageRepository,
      settingsRepository: settingsRepository,
      clock: clock,
    );
  }

  test('transient sampling error keeps tracking and recovers', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 4, 12);
      final viewModel = buildViewModel(() => now);

      unawaited(viewModel.startTracking());
      async.flushMicrotasks();
      expect(viewModel.state.status.isTracking, isTrue);

      // One failed sample (channel hiccup, busy database, ...) must not
      // flip the status to "not tracking" while the timer keeps running.
      dataSource.error = StateError('channel down');
      now = now.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));
      expect(viewModel.state.status.isTracking, isTrue);
      expect(viewModel.state.status.errorMessage, contains('channel down'));
      // The dashboard auto-refresh listens on lastUpdatedAt, so it must
      // keep advancing even for failed samples.
      expect(viewModel.state.status.lastUpdatedAt, now);

      // The next successful sample clears the error and records usage
      // again without the user pressing "Start Tracking".
      dataSource.error = null;
      now = now.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));
      expect(viewModel.state.status.isTracking, isTrue);
      expect(viewModel.state.status.errorMessage, isNull);
      expect(usageRepository.sessions, isNotEmpty);

      viewModel.dispose();
    });
  });

  test('a stalled timer gap is capped to a small multiple of the interval', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 4, 12);
      final viewModel = buildViewModel(() => now);

      unawaited(viewModel.startTracking());
      async.flushMicrotasks();

      // Simulate system sleep: the wall clock jumps three hours while the
      // periodic timer did not fire.
      now = now.add(const Duration(hours: 3));
      async.elapse(const Duration(seconds: 5));

      final session = usageRepository.sessions.single;
      expect(
        session.durationSeconds,
        settingsRepository.interval * TrackingViewModel.maxSampleGapMultiplier,
      );
      expect(
        session.endedAt!.difference(session.startedAt).inSeconds,
        session.durationSeconds,
      );

      viewModel.dispose();
    });
  });

  test('idle samples are skipped and tracking resumes after activity', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 4, 12);
      final viewModel = buildViewModel(() => now);

      unawaited(viewModel.startTracking());
      async.flushMicrotasks();

      // The user walks away: samples beyond the idle timeout are skipped.
      dataSource.info = const ActiveWindowInfo(
        processName: 'code.exe',
        windowTitle: 'main.dart',
        idleSeconds: 120,
      );
      now = now.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));
      expect(usageRepository.sessions, isEmpty);

      // The user returns: only the active interval since the last sample
      // is recorded, not the idle time.
      dataSource.info = const ActiveWindowInfo(
        processName: 'code.exe',
        windowTitle: 'main.dart',
        idleSeconds: 0,
      );
      now = now.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));
      expect(usageRepository.sessions.single.durationSeconds, 5);
      expect(viewModel.state.status.isTracking, isTrue);

      viewModel.dispose();
    });
  });
}
