import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/src/presentation/widgets/app_category_widgets.dart';

void main() {
  for (final historical in [false, true]) {
    testWidgets(
      'category filter and editor keep usage unchanged ($historical)',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = _FakeSettingsRepository();
        final usage = _FakeUsageRepository()
          ..serveHistory = historical
          ..extraSummaries = const [
            AppUsageSummary(
              appName: 'YouTube',
              packageName: 'youtube.app',
              totalDurationSeconds: 1500,
              percentageOfTotal: 0.25,
            ),
          ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
              usageRepositoryProvider.overrideWithValue(usage),
              reportRepositoryProvider.overrideWithValue(
                _FakeReportRepository(),
              ),
              platformDataSourceProvider.overrideWithValue(
                _FakePlatformDataSource(),
              ),
              settingsRepositoryProvider.overrideWithValue(settings),
              appLanguageRepositoryProvider.overrideWithValue(
                _FakeAppLanguageRepository(),
              ),
            ],
            child: const FocusTraceApp(),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DashboardScreen)),
        );
        if (historical) {
          await container
              .read(dashboardViewModelProvider.notifier)
              .previousDay();
          await tester.pump();
        }
        final before = container.read(dashboardViewModelProvider);
        expect(before.totalDurationSeconds, 6000);
        final originalPercentages = before.summaries
            .map((s) => s.percentageOfTotal)
            .toList();
        final originalRules = container
            .read(restrictionsViewModelProvider)
            .rules;
        final filter = find.byKey(
          const ValueKey('category-filter-entertainment'),
        );
        await tester.ensureVisible(filter);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(filter);
        await tester.pump();
        expect(find.byType(SummaryTile), findsOneWidget);
        expect(
          tester.widget<SummaryTile>(find.byType(SummaryTile)).summary.appName,
          'YouTube',
        );
        expect(
          tester.widget<BubbleChart>(find.byType(BubbleChart)).items,
          hasLength(2),
        );
        final dot = tester.widget<UsageCategoryLabel>(
          find.byType(UsageCategoryLabel),
        );
        expect(dot.category, UsageCategory.entertainment);
        expect(dot.category.color, const Color(0xFFFFD166));

        await tester.ensureVisible(find.text('YouTube'));
        await tester.tap(find.text('YouTube'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(UsageDetailsScreen), findsOneWidget);
        final tag = find.byKey(const ValueKey('app-category-tag'));
        expect(
          tester.widget<CategoryPill>(tag).category,
          UsageCategory.entertainment,
        );
        await tester.tap(tag);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final web = find.widgetWithText(RadioListTile<String>, 'Web');
        await tester.ensureVisible(web);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(web);
        final save = find.byKey(const ValueKey('save-app-category'));
        await tester.ensureVisible(save);
        await tester.pump();
        settings.failCategoryWrites = true;
        await tester.tap(save);
        await tester.pump();
        expect(
          find.text('Couldn’t save the category. Please try again.'),
          findsOneWidget,
        );
        expect(settings.categories, isEmpty);
        expect(
          tester.widget<CategoryPill>(tag).category,
          UsageCategory.entertainment,
        );
        settings.failCategoryWrites = false;
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(settings.categories, {'youtube.app': UsageCategory.web});
        expect(tester.widget<CategoryPill>(tag).category, UsageCategory.web);
        Navigator.of(tester.element(find.byType(UsageDetailsScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // The last entertainment app moved: the absent filter falls back to All.
        expect(
          find.byKey(const ValueKey('category-filter-entertainment')),
          findsNothing,
        );
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const ValueKey('category-filter-all')),
              )
              .selected,
          isTrue,
        );
        expect(find.byType(SummaryTile), findsNWidgets(2));
        expect(
          tester
              .widget<BubbleChart>(find.byType(BubbleChart))
              .items
              .singleWhere((item) => item.id == 'youtube.app')
              .category,
          UsageCategory.web,
        );
        final after = container.read(dashboardViewModelProvider);
        expect(after.totalDurationSeconds, before.totalDurationSeconds);
        expect(
          after.summaries.map((s) => s.percentageOfTotal).toList(),
          originalPercentages,
        );
        expect(
          container.read(restrictionsViewModelProvider).rules,
          originalRules,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final historical in [false, true]) {
    testWidgets(
      'returning to Android dashboard refreshes ${historical ? 'historical' : 'today'} usage without reopening',
      (tester) async {
        final usage = _FakeUsageRepository()..serveHistory = historical;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              usagePlatformProvider.overrideWithValue(UsagePlatform.android),
              usageRepositoryProvider.overrideWithValue(usage),
              reportRepositoryProvider.overrideWithValue(
                _FakeReportRepository(),
              ),
              platformDataSourceProvider.overrideWithValue(
                _FakePlatformDataSource(),
              ),
              settingsRepositoryProvider.overrideWithValue(
                _FakeSettingsRepository(),
              ),
              appLanguageRepositoryProvider.overrideWithValue(
                _FakeAppLanguageRepository(),
              ),
            ],
            child: const FocusTraceApp(),
          ),
        );
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(seconds: 1));
        }
        if (historical) {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(DashboardScreen)),
          );
          await container
              .read(dashboardViewModelProvider.notifier)
              .previousDay();
          await tester.pump();
        }
        expect(find.text('1h 15m'), findsWidgets);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        usage.todayDurationSeconds = 9000;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('2h 30m'), findsWidgets);
        expect(find.text('1h 15m'), findsNothing);
      },
    );
  }

  // (access, unavailable): an empty Android day in each distinct state.
  for (final (access, unavailable) in [
    (true, true),
    (false, true),
    (true, false),
  ]) {
    testWidgets('empty Android day, access=$access unavailable=$unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usagePlatformProvider.overrideWithValue(UsagePlatform.android),
            usageRepositoryProvider.overrideWithValue(
              _FakeUsageRepository(hasUsageAccessValue: access)
                ..emptyToday = true
                ..usageUnavailable = unavailable,
            ),
            reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
            platformDataSourceProvider.overrideWithValue(
              _FakePlatformDataSource(),
            ),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
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

      // Without access the permission card explains the empty day instead.
      final shown = access && unavailable;
      expect(
        find.text('Usage data is currently unavailable for this day.'),
        shown ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('No usage recorded for today.'),
        shown ? findsNothing : findsOneWidget,
      );
      // An unmeasured day has no duration to report.
      expect(
        find.textContaining('Tracked'),
        shown ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets('current list shows top apps until expanded', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Editor plus 12 more apps, already sorted by time like real summaries.
    final usage = _FakeUsageRepository()
      ..serveHistory = true
      ..extraSummaries = [
        for (var i = 0; i < 12; i++)
          AppUsageSummary(
            appName: 'App $i',
            processName: 'app$i.exe',
            totalDurationSeconds: 1200 - i * 60,
            percentageOfTotal: 0,
          ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
          usageRepositoryProvider.overrideWithValue(usage),
          reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
          platformDataSourceProvider.overrideWithValue(
            _FakePlatformDataSource(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          appLanguageRepositoryProvider.overrideWithValue(
            _FakeAppLanguageRepository(),
          ),
        ],
        child: const FocusTraceApp(),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    final toggle = find.byKey(const ValueKey('current-list-toggle'));
    Future<void> tapToggle() async {
      await tester.ensureVisible(toggle);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(toggle);
      await tester.pump();
    }

    expect(find.byType(SummaryTile, skipOffstage: false), findsNWidgets(10));
    expect(find.text('Show all (3 more)', skipOffstage: false), findsOneWidget);
    expect(find.text('App 8', skipOffstage: false), findsOneWidget);
    expect(find.text('App 9', skipOffstage: false), findsNothing);

    await tapToggle();
    expect(find.byType(SummaryTile, skipOffstage: false), findsNWidgets(13));
    expect(find.text('Show less', skipOffstage: false), findsOneWidget);

    // Live refreshes of the same day keep the list open.
    await container.read(dashboardViewModelProvider.notifier).refreshSilently();
    await tester.pump();
    expect(find.byType(SummaryTile, skipOffstage: false), findsNWidgets(13));

    await tapToggle();
    expect(find.byType(SummaryTile, skipOffstage: false), findsNWidgets(10));

    // Changing the filter collapses the list.
    await tapToggle();
    final all = find.byKey(const ValueKey('category-filter-all'));
    await tester.ensureVisible(all);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(all);
    await tester.pump();
    expect(find.byType(SummaryTile, skipOffstage: false), findsNWidgets(10));

    // So does changing the day.
    await tapToggle();
    await container.read(dashboardViewModelProvider.notifier).previousDay();
    await tester.pump();
    expect(find.byType(SummaryTile, skipOffstage: false), findsNWidgets(10));
    expect(find.text('Show all (3 more)', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current list has no toggle for ten apps or fewer', (
    tester,
  ) async {
    final usage = _FakeUsageRepository()
      ..extraSummaries = [
        for (var i = 0; i < 9; i++)
          AppUsageSummary(
            appName: 'App $i',
            processName: 'app$i.exe',
            totalDurationSeconds: 1200 - i * 60,
            percentageOfTotal: 0,
          ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
          usageRepositoryProvider.overrideWithValue(usage),
          reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
          platformDataSourceProvider.overrideWithValue(
            _FakePlatformDataSource(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          appLanguageRepositoryProvider.overrideWithValue(
            _FakeAppLanguageRepository(),
          ),
        ],
        child: const FocusTraceApp(),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(SummaryTile, skipOffstage: false), findsNWidgets(10));
    expect(
      find.byKey(const ValueKey('current-list-toggle'), skipOffstage: false),
      findsNothing,
    );
  });

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

    expect(
      find.descendant(
        of: find.byType(BubbleTooltip),
        matching: find.text('Productivity'),
      ),
      findsOneWidget,
    );

    // Let the tooltip auto-dismiss so no timers are pending at test end.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.descendant(
        of: find.byType(BubbleTooltip),
        matching: find.text('Productivity'),
      ),
      findsNothing,
    );

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

    // Chart selection travels through the real screen/ViewModel/provider flow
    // and is restored when a new details route is opened.
    await tester.ensureVisible(find.byKey(const ValueKey('usage-chart-pages')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('usage-chart-pages')),
      const Offset(-600, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The desktop-width page fling needs to finish before hit testing resumes.
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey('usage-area-chart')).hitTestable(),
      findsOneWidget,
    );
    Navigator.of(tester.element(find.byType(UsageDetailsScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Editor'));
    await tester.tap(find.text('Editor'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const ValueKey('usage-chart-pages')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('usage-area-chart')).hitTestable(),
      findsOneWidget,
    );
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

  group('settings', () {
    Future<_FakeUsageRepository> openSettings(
      WidgetTester tester, {
      _FakeUsageRepository? usage,
      _FakeSyncRepository? sync,
      _FakeDataTransferRepository? transfer,
      double textScale = 1,
      Size size = const Size(430, 1600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final usageRepository = usage ?? _FakeUsageRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
            usageRepositoryProvider.overrideWithValue(usageRepository),
            reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
            platformDataSourceProvider.overrideWithValue(
              _FakePlatformDataSource(),
            ),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            appLanguageRepositoryProvider.overrideWithValue(
              _FakeAppLanguageRepository(),
            ),
            syncSupportedProvider.overrideWithValue(sync != null),
            if (sync != null) syncRepositoryProvider.overrideWithValue(sync),
            dataTransferSupportedProvider.overrideWithValue(transfer != null),
            if (transfer != null)
              dataTransferRepositoryProvider.overrideWithValue(transfer),
          ],
          child: const FocusTraceApp(),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Scaled only here: this group checks Settings, not the dashboard.
      if (textScale != 1) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();
      }
      return usageRepository;
    }

    double top(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text)).dy;

    Future<void> tapRow(WidgetTester tester, String key) async {
      // The list builds lazily, so rows far down may not exist yet.
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    final clearSheet = find.byKey(const ValueKey('settings-clear-data-sheet'));
    final confirm = find.byKey(const ValueKey('settings-sheet-confirm'));

    testWidgets('a build without sync orders sections by intent', (
      tester,
    ) async {
      await openSettings(tester);

      expect(find.text('Account & sync'), findsNothing);
      expect(find.byKey(const ValueKey('settings-export-data')), findsNothing);
      expect(top(tester, 'General'), lessThan(top(tester, 'Activity & data')));
      expect(
        top(tester, 'Activity & data'),
        lessThan(top(tester, 'Data and privacy')),
      );
      expect(top(tester, 'Data and privacy'), lessThan(top(tester, 'Support')));
      final clear = tester.widget<ListTile>(
        find.byKey(const ValueKey('settings-clear-data')),
      );
      final error = Theme.of(
        tester.element(find.byType(SettingsScreen)),
      ).colorScheme.error;
      expect(clear.textColor, error);
      expect(clear.iconColor, error);
      // Without sync, the privacy text may say nothing is uploaded.
      expect(find.textContaining('never uploads'), findsOneWidget);
    });

    for (final signedIn in [false, true]) {
      testWidgets('a sync build puts the account before data '
          '(signed in: $signedIn)', (tester) async {
        await openSettings(
          tester,
          sync: _FakeSyncRepository()..signedIn = signedIn,
          transfer: _FakeDataTransferRepository(),
        );

        expect(
          top(tester, 'Activity & data'),
          lessThan(top(tester, 'Account & sync')),
        );
        expect(
          top(tester, 'Account & sync'),
          lessThan(top(tester, 'Data and privacy')),
        );
        expect(find.byKey(const ValueKey('settings-export-data')), findsOne);
        expect(
          find.byKey(const ValueKey('sync-more-button')),
          signedIn ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('sync-email-field')),
          signedIn ? findsNothing : findsOneWidget,
        );
        expect(find.textContaining('never uploads'), findsNothing);
        expect(find.textContaining('turn on cloud sync below'), findsNothing);
      });
    }

    testWidgets('cancelling Delete local data deletes nothing', (tester) async {
      final usage = await openSettings(tester);

      await tapRow(tester, 'settings-clear-data');
      expect(clearSheet, findsOneWidget);
      expect(find.textContaining('restrictions and block routines'), findsOne);
      expect(find.textContaining('language choice'), findsOneWidget);
      // No sync in this build, so no word about a cloud account.
      expect(find.textContaining('cloud account'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('settings-sheet-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(clearSheet, findsNothing);

      await tapRow(tester, 'settings-clear-data');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(clearSheet, findsNothing);
      expect(usage.clearCalls, 0);
    });

    testWidgets('Delete local data shows progress, cannot be dismissed, '
        'reports a failure and closes only on success', (tester) async {
      final usage = _FakeUsageRepository()
        ..clearHold = Completer<void>()
        ..clearFailure = StateError('disk');
      await openSettings(tester, usage: usage, sync: _FakeSyncRepository());

      await tapRow(tester, 'settings-clear-data');
      expect(find.textContaining('cloud account'), findsOneWidget);

      await tester.tap(confirm);
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(
        find.descendant(
          of: clearSheet,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(confirm, warnIfMissed: false);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      expect(clearSheet, findsOneWidget);

      usage.clearHold!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(usage.clearCalls, 1);
      expect(clearSheet, findsOneWidget, reason: 'stays open on failure');
      expect(find.byKey(const ValueKey('settings-sheet-error')), findsOne);
      expect(find.text('Local data deleted.'), findsNothing);

      usage
        ..clearHold = null
        ..clearFailure = null;
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(usage.clearCalls, 2);
      expect(clearSheet, findsNothing);
      expect(find.text('Local data deleted.'), findsOneWidget);
    });

    testWidgets('import asks first and explains what is replaced', (
      tester,
    ) async {
      final transfer = _FakeDataTransferRepository();
      await openSettings(tester, transfer: transfer);
      final sheet = find.byKey(const ValueKey('settings-import-sheet'));

      await tapRow(tester, 'settings-import-data');
      expect(sheet, findsOneWidget);
      expect(
        find.textContaining('Nothing on this device is deleted'),
        findsOne,
      );
      await tester.tap(find.byKey(const ValueKey('settings-sheet-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(transfer.importCalls, 0);

      await tapRow(tester, 'settings-import-data');
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sheet, findsNothing);
      expect(transfer.importCalls, 1);
    });

    testWidgets('the delete sheet fits a small phone at 200% text', (
      tester,
    ) async {
      await openSettings(
        tester,
        sync: _FakeSyncRepository(),
        textScale: 2,
        size: const Size(320, 640),
      );
      await tapRow(tester, 'settings-clear-data');
      await tester.ensureVisible(confirm);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(confirm.hitTestable(), findsOneWidget);
      expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
    });
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
  int todayDurationSeconds = 4500;
  bool serveHistory = false;
  bool usageUnavailable = false;
  bool emptyToday = false;
  List<AppUsageSummary> extraSummaries = const [];

  int clearCalls = 0;
  Object? clearFailure;
  Completer<void>? clearHold;

  @override
  Future<void> clearAllData() async {
    clearCalls++;
    await clearHold?.future;
    if (clearFailure != null) throw clearFailure!;
  }

  @override
  Future<List<AppUsageSummary>> getTodaySummaries() async {
    if (emptyToday) return const [];
    return [
      AppUsageSummary(
        appName: 'Editor',
        processName: 'editor.exe',
        totalDurationSeconds: todayDurationSeconds,
        percentageOfTotal: 1,
        launchCount: 3,
      ),
      ...extraSummaries,
    ];
  }

  @override
  Future<List<AppUsageSummary>> getCachedTodaySummaries(DateTime day) async =>
      const <AppUsageSummary>[];

  @override
  Future<bool> isUsageUnavailable(DateTime day) async => usageUnavailable;

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async =>
      serveHistory ? await getTodaySummaries() : const <AppUsageSummary>[];

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
  Map<String, UsageCategory> categories = {};
  bool failCategoryWrites = false;

  @override
  Future<Map<String, UsageCategory>> appCategoryOverrides() async =>
      Map.of(categories);

  @override
  Future<void> setAppCategoryOverrides(
    Map<String, UsageCategory> overrides,
  ) async {
    if (failCategoryWrites) throw StateError('disk full');
    categories = Map.of(overrides);
  }

  UsageDetailsChart chart = UsageDetailsChart.bars;

  @override
  Future<UsageDetailsChart> usageDetailsChart() async => chart;

  @override
  Future<void> setUsageDetailsChart(UsageDetailsChart value) async {
    chart = value;
  }

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

class _FakeSyncRepository implements SyncRepository {
  bool signedIn = false;

  @override
  Future<bool> get isSignedIn async => signedIn;

  @override
  Future<String?> accountEmail() async => signedIn ? 'a@example.com' : null;

  @override
  Future<bool> isSyncEnabled() async => false;

  @override
  Future<DateTime?> lastSuccessfulSyncAt() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDataTransferRepository implements DataTransferRepository {
  int importCalls = 0;

  @override
  Future<bool> exportData() async => false;

  // Null: the user closed the file picker, so nothing was imported.
  @override
  Future<DataImportResult?> importData() async {
    importCalls++;
    return null;
  }
}
