import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  testWidgets('dashboard renders usage summaries', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
          usageRepositoryProvider.overrideWithValue(_FakeUsageRepository()),
          reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
          platformDataSourceProvider.overrideWithValue(
            _FakePlatformDataSource(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository().._excludedApps.add('excluded.exe'),
          ),
          appLanguageRepositoryProvider.overrideWithValue(
            _FakeAppLanguageRepository(),
          ),
        ],
        child: const FocusTraceApp(),
      ),
    );

    // The bubble chart's pulsing background animates forever, so
    // pumpAndSettle would never settle; pump fixed frames instead. Each
    // async layer (language load, onboarding gate, usage data) needs a frame.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Usage Bubbles'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('editor.exe'), findsNothing);
    expect(find.text('Launches: 3'), findsOneWidget);
    expect(find.text('D +50%'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Editor, Productivity, daily limit almost reached'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
    expect(find.text('1h 15m'), findsWidgets);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    // The all-time top apps card now lives on the restrictions screen.
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('restrictions-scroll-view')),
      findsOneWidget,
    );
    expect(find.text('Most used of all time'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(UsageDetailsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-period-dropdown')), findsOneWidget);
    Navigator.of(tester.element(find.byType(UsageDetailsScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.longPress(find.text('Archive'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('restriction-editor-scroll-view')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('restriction-editor-scroll-view')),
      ),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.drag(
      find.byKey(const ValueKey('restrictions-scroll-view')),
      const Offset(0, -500),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Editor'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('settings-reports')), findsOneWidget);
    expect(find.text('Excluded App'), findsOneWidget);
    expect(find.text('excluded.exe'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-reports')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('reports-scroll-view')), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Habit formation'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ReportsScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.home));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(UsageBubble));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Productivity'), findsOneWidget);

    // Let the tooltip auto-dismiss so no timers are pending at test end.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Productivity'), findsNothing);

    await tester.ensureVisible(find.text('Editor'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Time tracked'), findsNothing);
    expect(find.byKey(const ValueKey('usage-period-dropdown')), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('7 days')).style?.fontWeight,
      FontWeight.w400,
    );
    expect(find.text('2h 5m'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('usage-period-dropdown')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2 weeks').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2 weeks'), findsOneWidget);
    expect(find.text('2h 5m'), findsOneWidget);

    expect(find.byKey(const ValueKey('usage-trend-line')), findsOneWidget);
    expect(find.text('#1 most used'), findsOneWidget);
    expect(find.text('50% more than yesterday'), findsOneWidget);
  });

  testWidgets('language picker applies and persists locale immediately', (
    tester,
  ) async {
    final languageRepository = _FakeAppLanguageRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
          usageRepositoryProvider.overrideWithValue(_FakeUsageRepository()),
          reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
          platformDataSourceProvider.overrideWithValue(
            _FakePlatformDataSource(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          appLanguageRepositoryProvider.overrideWithValue(languageRepository),
        ],
        child: const FocusTraceApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Route pushes and dialogs need one pump to mount plus one to animate.
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Language'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Español'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(languageRepository.language, AppLanguage.spanish);
    final settingsContext = tester.element(find.byType(SettingsScreen));
    expect(Localizations.localeOf(settingsContext).languageCode, 'es');
  });

  testWidgets('onboarding distinguishes settings access from runtime prompt', (
    tester,
  ) async {
    final usageRepository = _FakeUsageRepository(hasUsageAccessValue: false);
    final platformDataSource = _FakePlatformDataSource(
      overlayPermission: false,
      notificationsPermission: false,
      notificationRequestResult: true,
    );
    final settingsRepository = _FakeSettingsRepository()
      .._onboardingCompleted = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.android),
          usageRepositoryProvider.overrideWithValue(usageRepository),
          reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
          platformDataSourceProvider.overrideWithValue(platformDataSource),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          appLanguageRepositoryProvider.overrideWithValue(
            _FakeAppLanguageRepository(),
          ),
        ],
        child: const FocusTraceApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Open settings'), findsNWidgets(2));
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Allow'));
    await tester.pump();

    expect(find.text('Allow'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAppLanguageRepository implements AppLanguageRepository {
  AppLanguage language = AppLanguage.english;

  @override
  Future<AppLanguage> appLanguage() async => language;

  @override
  Future<void> setAppLanguage(AppLanguage language) async {
    this.language = language;
  }
}

class _FakeUsageRepository implements UsageRepository {
  _FakeUsageRepository({this.hasUsageAccessValue = true});

  final bool hasUsageAccessValue;

  @override
  Future<void> clearAllData() async {}

  @override
  Future<List<AppUsageSummary>> getTodaySummaries() async {
    return [
      const AppUsageSummary(
        appName: 'Editor',
        processName: 'editor.exe',
        totalDurationSeconds: 4500,
        percentageOfTotal: 1,
        launchCount: 3,
      ),
    ];
  }

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async =>
      const <AppUsageSummary>[];

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() async => const [
    AppUsageSummary(
      appName: 'Archive',
      processName: 'archive.exe',
      totalDurationSeconds: 7200,
      percentageOfTotal: 0.8,
      launchCount: 5,
    ),
    AppUsageSummary(
      appName: 'Excluded App',
      processName: 'excluded.exe',
      totalDurationSeconds: 1800,
      percentageOfTotal: 0.2,
      launchCount: 2,
    ),
  ];

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      DailyAppUsage(
        day: today,
        summary: const AppUsageSummary(
          appName: 'Editor',
          processName: 'editor.exe',
          totalDurationSeconds: 4500,
          percentageOfTotal: 0,
        ),
      ),
      DailyAppUsage(
        day: today.subtract(const Duration(days: 1)),
        summary: const AppUsageSummary(
          appName: 'Editor',
          processName: 'editor.exe',
          totalDurationSeconds: 3000,
          percentageOfTotal: 0,
        ),
      ),
    ];
  }

  @override
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  }) async => const <UsageSession>[];

  @override
  Future<bool> hasUsageAccess() async => hasUsageAccessValue;

  @override
  Future<void> insertSession(UsageSession session) async {}

  @override
  Future<void> openUsageAccessSettings() async {}
}

class _FakeReportRepository implements ReportRepository {
  @override
  Future<UsageReportSourceData> loadSourceData(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final startedAt = DateTime(now.year, now.month, now.day, 8);
    return UsageReportSourceData(
      dailyUsage: [
        DailyAppUsage(
          day: day,
          summary: const AppUsageSummary(
            appName: 'Reader',
            processName: 'reader.exe',
            totalDurationSeconds: 1800,
            percentageOfTotal: 1,
          ),
        ),
      ],
      intervals: [
        AppUsageInterval(
          id: 'reader:${startedAt.millisecondsSinceEpoch}',
          appKey: 'reader.exe',
          appName: 'Reader',
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 30)),
        ),
      ],
      restrictionEvents: const [],
    );
  }

  @override
  Future<void> recordRestrictionEvent(RestrictionEvent event) async {}
}

class _FakePlatformDataSource implements PlatformUsageDataSource {
  _FakePlatformDataSource({
    this.overlayPermission = true,
    this.notificationsPermission = true,
    this.notificationRequestResult = true,
  });

  final bool overlayPermission;
  final bool notificationsPermission;
  final bool notificationRequestResult;

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
      notificationRequestResult;

  @override
  Future<void> syncRestrictions(String json) async {}
}

class _FakeSettingsRepository implements SettingsRepository {
  int _trackingIntervalSeconds = 5;
  int _idleTimeoutSeconds = 60;
  final List<String> _excludedApps = [];
  final Set<String> _hiddenAppsToday = {};
  bool _onboardingCompleted = true;

  @override
  Future<List<BlockRoutine>> blockRoutines() async => const [];

  @override
  Future<void> saveBlockRoutine(BlockRoutine routine) async {}

  @override
  Future<void> removeBlockRoutine(String id) async {}

  @override
  Future<List<String>> excludedApps() async => List.of(_excludedApps);

  @override
  Future<void> addExcludedApp(String appKey) async {
    if (!_excludedApps.contains(appKey)) {
      _excludedApps.add(appKey);
    }
  }

  @override
  Future<void> removeExcludedApp(String appKey) async {
    _excludedApps.remove(appKey);
  }

  @override
  Future<Set<String>> hiddenAppsForToday() async => Set.of(_hiddenAppsToday);

  @override
  Future<void> hideAppForToday(String appKey) async {
    _hiddenAppsToday.add(appKey);
  }

  @override
  Future<bool> onboardingCompleted() async => _onboardingCompleted;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    _onboardingCompleted = completed;
  }

  @override
  Future<int> idleTimeoutSeconds() async => _idleTimeoutSeconds;

  @override
  Future<void> setIdleTimeoutSeconds(int seconds) async {
    _idleTimeoutSeconds = seconds;
  }

  @override
  Future<void> setTrackingIntervalSeconds(int seconds) async {
    _trackingIntervalSeconds = seconds;
  }

  @override
  Future<int> trackingIntervalSeconds() async => _trackingIntervalSeconds;

  @override
  Future<List<RestrictionRule>> restrictionRules() async => [
    RestrictionRule.dailyLimit(
      appKey: 'editor.exe',
      appName: 'Editor',
      limitMinutes: 80,
    ),
  ];

  @override
  Future<void> saveRestrictionRule(RestrictionRule rule) async {}

  @override
  Future<void> removeRestrictionRule(
    String appKey,
    RestrictionRuleType type,
  ) async {}
}
