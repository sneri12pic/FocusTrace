import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/screens/routine_details_screen.dart';
import 'package:focustrace/src/presentation/widgets/routine_app_picker.dart';

class _Settings implements SettingsRepository {
  final routines = <BlockRoutine>[];
  final rules = <RestrictionRule>[];
  Map<String, UsageCategory> categories = {};

  @override
  Future<List<BlockRoutine>> blockRoutines() async => List.of(routines);
  @override
  Future<void> saveBlockRoutine(BlockRoutine routine) async {
    routines.removeWhere((r) => r.id == routine.id);
    routines.add(routine);
  }

  @override
  Future<void> removeBlockRoutine(String id) async =>
      routines.removeWhere((r) => r.id == id);
  @override
  Future<List<RestrictionRule>> restrictionRules() async => List.of(rules);
  @override
  Future<Map<String, UsageCategory>> appCategoryOverrides() async =>
      Map.of(categories);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Platform implements PlatformUsageDataSource {
  final synced = <String>[];
  @override
  Future<bool> hasOverlayPermission() async => true;
  @override
  Future<bool> hasNotificationsPermission() async => true;
  @override
  Future<void> syncRestrictions(String json) async => synced.add(json);
  @override
  Future<List<AppUsageSummary>> getInstalledApps() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

AppUsageSummary app(String name, [int seconds = 0]) => AppUsageSummary(
  appName: name,
  packageName: 'p.${name.toLowerCase()}',
  totalDurationSeconds: seconds,
  percentageOfTotal: 0,
);

Widget harness(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: home,
      ),
    );

void main() {
  test('most-used app first, the rest alphabetical, each once', () {
    final ordered = orderRoutineCandidates([
      app('Zoom', 60),
      app('banking', 0),
      app('Chess', 900),
      app('alarm', 30),
      app('Chess', 10),
      const AppUsageSummary(
        appName: 'FocusTrace',
        packageName: 'com.stepandemianenko.focustrace.dev',
        totalDurationSeconds: 9999,
        percentageOfTotal: 0,
      ),
    ]);
    expect(ordered.map((a) => a.appName), [
      'Chess',
      'alarm',
      'banking',
      'Zoom',
    ]);
  });

  testWidgets('picker selects categories, shows partial state and keeps '
      'selection across filters and search', (tester) async {
    var selected = <String>{};
    // YouTube and TikTok resolve to Entertainment automatically.
    final apps = [app('YouTube', 50), app('TikTok', 500), app('Notes')];
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RoutineAppPicker(
              apps: apps,
              selected: selected,
              onChanged: (keys) => setState(() => selected = keys),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Most-used first.
    expect(
      tester.getTopLeft(find.text('TikTok')).dy,
      lessThan(tester.getTopLeft(find.text('Notes')).dy),
    );

    await tester.tap(find.text('Entertainment'));
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsNothing);
    await tester.tap(find.text('Select all in Entertainment'));
    await tester.pumpAndSettle();
    expect(selected, {'p.youtube', 'p.tiktok'});

    // Deselecting one leaves the category partially selected.
    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();
    expect(selected, {'p.tiktok'});
    expect(
      tester.getSemantics(find.bySemanticsLabel('Select all in Entertainment')),
      matchesSemantics(
        label: 'Select all in Entertainment',
        isButton: true,
        hasCheckedState: true,
        isCheckStateMixed: true,
        hasTapAction: true,
      ),
    );

    // Switching category and searching keep what was chosen.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(selected, {'p.tiktok', 'p.notes'});
  });

  testWidgets('a blank name gets a warm prompt that is never saved', (
    tester,
  ) async {
    BlockRoutine? saved;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => saved = await showRoutineEditor(
                context,
                apps: [app('Chess')],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Add routine name'), findsNothing);
    await tester.tap(find.text('Chess'));
    await tester.pumpAndSettle();
    expect(find.text('Add routine name'), findsOneWidget);
    // Cannot save under the prompt.
    await tester.tap(find.text('Save routine'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.enterText(find.byType(TextField).first, 'Evening');
    await tester.pumpAndSettle();
    expect(find.text('Add routine name'), findsNothing);
    await tester.tap(find.text('Save routine'));
    await tester.pumpAndSettle();
    expect(saved?.name, 'Evening');
  });

  for (final choice in ['Keep routine', 'Delete routine', 'dismiss']) {
    testWidgets('removing the last app: $choice', (tester) async {
      final settings = _Settings()
        ..routines.add(
          const BlockRoutine(
            id: 'r',
            name: 'Study time',
            dailyLimitMinutes: 60,
            isEnabled: true,
            apps: [RoutineApp(appKey: 'p.chess', appName: 'Chess')],
          ),
        );
      final platform = _Platform();
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutineDetailsScreen(
                      routineId: 'r',
                      appCandidates: [],
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
          overrides: [
            restrictionsViewModelProvider.overrideWith((ref) {
              final vm = RestrictionsViewModel(
                settingsRepository: settings,
                platformDataSource: platform,
                platform: UsagePlatform.android,
              );
              vm.load();
              return vm;
            }),
            installedAppsProvider.overrideWith((ref) async => []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove app'));
      await tester.pumpAndSettle();
      expect(
        find.text('This routine has no apps left. Delete the routine?'),
        findsOneWidget,
      );
      if (choice == 'dismiss') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text(choice));
      }
      await tester.pumpAndSettle();
      if (choice == 'Delete routine') {
        expect(settings.routines, isEmpty);
        expect(find.text('Open'), findsOneWidget);
      } else {
        final kept = settings.routines.single;
        expect(kept.apps, isEmpty);
        expect(kept.isEnabled, isFalse);
        expect(find.textContaining('No apps in this routine yet'), findsOne);
        // The kept, empty routine still decodes after a restart.
        expect(decodeBlockRoutines(encodeBlockRoutines([kept])).single.id, 'r');
        // Not sent to the blocker while empty.
        expect(platform.synced.last, contains('"routines":[]'));
      }
    });
  }

  testWidgets('every active reason for an app is listed', (tester) async {
    late List<String> reasons;
    final now = DateTime(2026, 10, 23, 15);
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) {
            reasons = appBlockReasons(
              context,
              now: now,
              appKey: 'a',
              usageByAppKey: {'a': 40 * 60},
              rules: [
                RestrictionRule.dailyLimit(
                  appKey: 'a',
                  appName: 'A',
                  limitMinutes: 30,
                ),
                RestrictionRule.schedule(
                  appKey: 'a',
                  appName: 'A',
                  startMinute: 14 * 60,
                  endMinute: 16 * 60,
                ),
              ],
              routines: const [
                BlockRoutine(
                  id: '1',
                  name: 'Study time',
                  dailyLimitMinutes: 30,
                  isEnabled: true,
                  apps: [RoutineApp(appKey: 'a', appName: 'A')],
                ),
                BlockRoutine(
                  id: '2',
                  name: 'Evening',
                  dailyLimitMinutes: 600,
                  isEnabled: true,
                  apps: [
                    RoutineApp(appKey: 'a', appName: 'A', limitMinutes: 20),
                  ],
                ),
                // Paused routines never block.
                BlockRoutine(
                  id: '3',
                  name: 'Paused',
                  dailyLimitMinutes: 1,
                  apps: [RoutineApp(appKey: 'a', appName: 'A')],
                ),
              ],
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(reasons, [
      'Daily app limit reached',
      'Blocked by schedule until 4:00 PM',
      'Study time: shared allowance reached',
      'Evening: app limit reached',
    ]);
  });
}
