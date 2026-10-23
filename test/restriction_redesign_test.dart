import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focustrace/src/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/domain/models/app_usage_interval.dart';
import 'package:focustrace/src/domain/models/app_usage_summary.dart';
import 'package:focustrace/src/domain/models/daily_app_usage.dart';
import 'package:focustrace/src/domain/models/restriction_rule.dart';
import 'package:focustrace/src/domain/repositories/report_repository.dart';
import 'package:focustrace/src/presentation/screens/restriction_editor_sheet.dart';
import 'package:focustrace/src/presentation/view_models/restriction_insights.dart';

void main() {
  test('legacy JSON keeps easy difficulty and all weekdays', () {
    final rule = RestrictionRule.fromJson({
      'appKey': 'a',
      'appName': 'A',
      'type': 'schedule',
      'startMinute': 1260,
      'endMinute': 420,
    })!;
    expect(rule.difficulty, RestrictionDifficulty.easy);
    expect(rule.weekdays, [1, 2, 3, 4, 5, 6, 7]);
    final hard = rule.copyWith(
      difficulty: RestrictionDifficulty.hard,
      weekdays: [5],
    );
    final decoded = decodeRules(encodeRules([hard])).single;
    expect(decoded.difficulty, RestrictionDifficulty.hard);
    expect(decoded.blocksAt(DateTime(2026, 10, 16, 6), 0), false);
    expect(decoded.blocksAt(DateTime(2026, 10, 16, 21), 0), true);
    expect(decoded.blocksAt(DateTime(2026, 10, 17, 6, 59), 0), true);
    expect(decoded.blocksAt(DateTime(2026, 10, 17, 7), 0), false);
    expect(decoded.blocksAt(DateTime(2026, 10, 17, 21), 0), false);
  });

  test('averages exclude missing days, hourly bars use actual intervals', () {
    final source = UsageReportSourceData(
      dailyUsage: [
        DailyAppUsage(
          day: DateTime(2026, 10, 12),
          summary: const AppUsageSummary(
            appName: 'A',
            packageName: 'a',
            totalDurationSeconds: 3600,
            percentageOfTotal: 100,
          ),
        ),
        DailyAppUsage(
          day: DateTime(2026, 10, 14),
          summary: const AppUsageSummary(
            appName: 'B',
            packageName: 'b',
            totalDurationSeconds: 600,
            percentageOfTotal: 100,
          ),
        ),
      ],
      intervals: [
        AppUsageInterval(
          id: '1',
          appKey: 'a',
          appName: 'A',
          startedAt: DateTime(2026, 10, 12, 21, 30),
          endedAt: DateTime(2026, 10, 12, 22, 30),
        ),
      ],
      restrictionEvents: [],
    );
    final result = RestrictionInsights.fromSource(
      source,
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 16),
      average: true,
    );
    expect(result.recordedDays, 2);
    expect(result.apps.first.totalDurationSeconds, 1800);
    expect(result.hours[21], 1800);
    expect(result.hours[22], 1800);
    expect(result.hours.reduce((a, b) => a + b), 3600);
    expect(result.suggestedApp?.appKey, 'a');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('dark editor is usable at 360px and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      RestrictionRule? saved;
      await tester.pumpWidget(
        testScope(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF070A10),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF5BC0EB),
                brightness: Brightness.dark,
                surface: const Color(0xFF070A10),
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await showRestrictionEditor(
                      context,
                      appKey: 'sample',
                      appName: 'Sample app',
                      averageSeconds: 7800,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Set daily limit'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Set daily limit'));
      await tester.pumpAndSettle();
      expect(saved?.limitMinutes, 90);
      expect(saved?.difficulty, RestrictionDifficulty.easy);
      expect(tester.takeException(), isNull);
      if (scale == 1) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Block now'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('restriction-duration')));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.first, '0');
        await tester.enterText(fields.last, '0');
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.last, '25');
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start block'));
        await tester.pumpAndSettle();
        expect(saved?.type, RestrictionRuleType.blockNow);
        expect(
          saved!.untilMs! - DateTime.now().millisecondsSinceEpoch,
          closeTo(25 * 60000, 3000),
        );
      }
    });
  }

  testWidgets(
    'Hard activation requires confirmation; schedule preserves weekdays',
    (tester) async {
      RestrictionRule? saved;
      await tester.pumpWidget(
        testScope(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await showRestrictionEditor(
                      context,
                      appKey: 'a',
                      appName: 'A',
                      initial:
                          RestrictionRule.schedule(
                            appKey: 'a',
                            appName: 'A',
                            startMinute: 1260,
                            endMinute: 420,
                          ).copyWith(
                            weekdays: [5],
                            difficulty: RestrictionDifficulty.hard,
                          ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set schedule'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(saved?.difficulty, RestrictionDifficulty.hard);
      expect(saved?.weekdays, [5]);
      expect(saved?.endMinute, 420);
    },
  );

  testWidgets('editing explains the chosen difficulty, presets set the limit, '
      'and the action saves changes', (tester) async {
    RestrictionRule? saved;
    await tester.pumpWidget(
      testScope(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showRestrictionEditor(
                    context,
                    appKey: 'a',
                    appName: 'A',
                    existing: RestrictionRule.dailyLimit(
                      appKey: 'a',
                      appName: 'A',
                      limitMinutes: 90,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Set daily limit'), findsNothing);
    expect(find.textContaining('asks for confirmation'), findsOneWidget);
    await tester.tap(find.text('Moderate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('five-minute wait'), findsOneWidget);
    expect(find.textContaining('asks for confirmation'), findsNothing);
    await tester.tap(find.text('30m'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    // Changing an existing rule still asks first.
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(saved?.limitMinutes, 30);
    expect(saved?.difficulty, RestrictionDifficulty.moderate);
  });
}

Widget testScope(Widget child) => ProviderScope(
  overrides: [
    restrictionPeriodInsightsProvider.overrideWith(
      (ref, week) async =>
          const RestrictionInsights(apps: [], recordedDays: 0, hours: []),
    ),
    installedAppsProvider.overrideWith((ref) async => []),
  ],
  child: child,
);
