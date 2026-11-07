import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/view_models/restriction_insights.dart';

const _usage = MethodChannel('focustrace/usage');
const _screenTime = MethodChannel('focustrace/screen_time');

/// Records every call on a channel and answers from [answers].
class _Native {
  _Native(this.channel, this.answers) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final answer = answers[call.method];
          return answer is Function ? answer(call) : answer;
        });
  }

  final MethodChannel channel;
  final Map<String, Object?> answers;
  final calls = <MethodCall>[];

  List<Object?> argumentsOf(String method) => [
    for (final call in calls)
      if (call.method == method) call.arguments,
  ];

  void dispose() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

class _Settings extends Fake implements SettingsRepository {
  final rules = <RestrictionRule>[];

  @override
  Future<List<RestrictionRule>> restrictionRules() async => List.of(rules);

  @override
  Future<void> saveRestrictionRule(RestrictionRule rule) async {
    rules.removeWhere((r) => r.appKey == rule.appKey && r.type == rule.type);
    rules.add(rule);
  }

  @override
  Future<void> removeRestrictionRule(
    String appKey,
    RestrictionRuleType type,
  ) async => rules.removeWhere((r) => r.appKey == appKey && r.type == type);

  @override
  Future<List<BlockRoutine>> blockRoutines() async => const [];
}

class _Reports extends Fake implements ReportRepository {
  final events = <RestrictionEvent>[];

  @override
  Future<void> recordRestrictionEvent(RestrictionEvent event) async =>
      events.add(event);
}

/// The rules in the last configuration iOS received.
List<Map<String, Object?>> _syncedRules(_Native native) {
  final json = native.argumentsOf('syncRestrictions').last as String;
  return [
    for (final rule in (jsonDecode(json) as Map)['rules'] as List)
      Map<String, Object?>.from(rule as Map),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IosUsageDataSource', () {
    late _Native native;
    tearDown(() => native.dispose());

    test('forwards the restriction methods to focustrace/usage', () async {
      native = _Native(_usage, {
        'readRestrictionConfiguration': '{"version":3,"rules":[]}',
        'requestRestrictionChange': 'cooldown',
        'hasNotificationsPermission': true,
      });
      final source = IosUsageDataSource();

      await source.syncRestrictions('{"rules":[]}');
      expect(native.argumentsOf('syncRestrictions'), ['{"rules":[]}']);
      expect(
        await source.readRestrictionConfiguration(),
        '{"version":3,"rules":[]}',
      );
      expect(
        await source.requestRestrictionChange('ios-sel:a', 'blockNow'),
        'cooldown',
      );
      expect(native.argumentsOf('requestRestrictionChange'), [
        {'appKey': 'ios-sel:a', 'type': 'blockNow'},
      ]);
      expect(await source.hasNotificationsPermission(), isTrue);
    });

    test('a missing guard answer is unavailable, as on Android', () async {
      native = _Native(_usage, {'requestRestrictionChange': null});
      expect(
        await IosUsageDataSource().requestRestrictionChange('k', 'schedule'),
        'unavailable',
      );
    });

    test('usage is empty and never asks the native side', () async {
      native = _Native(_usage, {});
      final source = IosUsageDataSource();
      expect(await source.hasUsageAccess(), isFalse);
      expect(await source.hasOverlayPermission(), isTrue);
      expect(await source.getTodayUsageStats(), isEmpty);
      expect(await source.getInstalledApps(), isEmpty);
      expect(await source.getActiveWindowInfo(), isNull);
      expect(native.calls, isEmpty);
      expect(source, isNot(isA<UsageHistoryRecoveryDataSource>()));
      expect(source, isNot(isA<AppMetadataDataSource>()));
    });

    test('a refused sync surfaces as the native error', () async {
      native = _Native(_usage, {
        'syncRestrictions': (MethodCall _) => throw PlatformException(
          code: 'RESTRICTION_LOCKED',
          message: 'locked',
        ),
      });
      expect(
        IosUsageDataSource().syncRestrictions('{}'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'RESTRICTION_LOCKED',
          ),
        ),
      );
    });

    test('takes recorded shield events and skips malformed rows', () async {
      native = _Native(_usage, {
        'takeRestrictionEvents': [
          {
            'id': 'e1',
            'appKey': 'ios-sel:a',
            'appName': 'Social',
            'type': 'blocked',
            'reason': 'schedule',
            'occurredAtMs': 1793995200000,
          },
          {'id': 'broken'},
        ],
      });
      final events = await IosUsageDataSource().takeRestrictionEvents();
      expect(events, hasLength(1));
      expect(events.single.appName, 'Social');
      expect(events.single.type, RestrictionEventType.blocked);
      expect(events.single.reason, 'schedule');
      expect(
        events.single.occurredAt,
        DateTime.fromMillisecondsSinceEpoch(1793995200000),
      );
    });
  });

  group('ScreenTimeChannel', () {
    late _Native native;
    tearDown(() => native.dispose());

    test('maps authorization and picker answers', () async {
      native = _Native(_screenTime, {
        'authorizationStatus': 'denied',
        'requestAuthorization': 'approved',
        'pickSelection': {
          'selectionId': 'abc',
          'appKey': 'ios-sel:abc',
          'appCount': 2,
          'categoryCount': 1,
          'webDomainCount': 0,
        },
      });
      const channel = ScreenTimeChannel();
      expect(
        await channel.authorizationStatus(),
        ScreenTimeAuthorizationStatus.denied,
      );
      expect(
        await channel.requestAuthorization(),
        ScreenTimeAuthorizationStatus.approved,
      );
      final selection = await channel.pickSelection(
        doneLabel: 'Done',
        cancelLabel: 'Cancel',
      );
      expect(selection?.appKey, 'ios-sel:abc');
      expect(selection?.appCount, 2);
      expect(selection?.categoryCount, 1);
      expect(native.argumentsOf('pickSelection'), [
        {'doneLabel': 'Done', 'cancelLabel': 'Cancel'},
      ]);
    });

    test('a cancelled picker is null', () async {
      native = _Native(_screenTime, {'pickSelection': null});
      expect(
        await const ScreenTimeChannel().pickSelection(
          selectionId: 'abc',
          doneLabel: 'Done',
          cancelLabel: 'Cancel',
        ),
        isNull,
      );
      expect(
        (native.argumentsOf('pickSelection').single as Map)['selectionId'],
        'abc',
      );
    });

    test('app keys of picker selections', () {
      expect(isIosSelectionKey('ios-sel:abc'), isTrue);
      expect(iosSelectionId('ios-sel:abc'), 'abc');
      expect(iosSelectionId('com.example.app'), isNull);
    });
  });

  group('restrictions on iOS', () {
    late _Native usage;
    tearDown(() => usage.dispose());

    test('the native guard decides, and shield events are imported', () async {
      usage = _Native(_usage, {
        'readRestrictionConfiguration': null,
        'requestRestrictionChange': 'hard',
        'hasNotificationsPermission': false,
        'takeRestrictionEvents': [
          {
            'id': 'e1',
            'appKey': 'ios-sel:a',
            'appName': 'Social',
            'type': 'blocked',
            'occurredAtMs': 1,
          },
        ],
      });
      final settings = _Settings()
        ..rules.add(
          RestrictionRule(
            appKey: 'ios-sel:a',
            appName: 'Social',
            type: RestrictionRuleType.blockNow,
            untilMs: DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
            difficulty: RestrictionDifficulty.hard,
          ),
        );
      final reports = _Reports();
      final viewModel = RestrictionsViewModel(
        settingsRepository: settings,
        platformDataSource: IosUsageDataSource(),
        platform: UsagePlatform.ios,
        reportRepository: reports,
      );
      await viewModel.load();
      expect(viewModel.state.errorMessage, isNull);
      expect(reports.events.single.appKey, 'ios-sel:a');
      expect(_syncedRules(usage).single['appKey'], 'ios-sel:a');

      await viewModel.deleteRule('ios-sel:a', RestrictionRuleType.blockNow);
      expect(viewModel.state.errorMessage, contains('restriction:hard'));
      expect(settings.rules, hasLength(1));
    });
  });

  testWidgets('iOS: pick apps natively, name them, then set a schedule', (
    tester,
  ) async {
    final usage = _Native(_usage, {
      'readRestrictionConfiguration': null,
      'hasNotificationsPermission': false,
      'takeRestrictionEvents': const [],
    });
    final screenTime = _Native(_screenTime, {
      'authorizationStatus': 'approved',
      'pickSelection': {
        'selectionId': 'abc',
        'appKey': 'ios-sel:abc',
        'appCount': 3,
        'categoryCount': 0,
        'webDomainCount': 0,
      },
    });
    addTearDown(usage.dispose);
    addTearDown(screenTime.dispose);
    final settings = _Settings();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.ios),
          restrictionsViewModelProvider.overrideWith(
            (ref) => RestrictionsViewModel(
              settingsRepository: settings,
              platformDataSource: IosUsageDataSource(),
              platform: UsagePlatform.ios,
            ),
          ),
          restrictionPeriodInsightsProvider.overrideWith(
            (ref, week) async =>
                const RestrictionInsights(apps: [], recordedDays: 0, hours: []),
          ),
          installedAppsProvider.overrideWith((ref) async => []),
          appScheduleUsageProvider.overrideWith(
            (ref, appKey) async => List.filled(96, 0),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Starts the status lookup, as the restrictions screen does.
                ref.watch(screenTimeAuthorizationProvider);
                return TextButton(
                  onPressed: () => createIosRestriction(context, ref),
                  child: const Text('Add'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(screenTime.argumentsOf('setShieldStrings'), hasLength(1));
    final strings =
        (screenTime.argumentsOf('setShieldStrings').single as Map)['strings']
            as Map;
    expect(strings['scheduleUntil'], 'Blocked by schedule until {time}');
    // Texts the monitor extension posts as notifications, pluralized here.
    expect(strings['limitWarningTitle'], '{name} limit almost reached');
    expect(
      strings['limitWarningBody.5'],
      'Blocking starts in about 5 minutes.',
    );
    expect(strings['limitWarningBody.1'], 'Blocking starts in about 1 minute.');
    expect(strings['routineShared'], '{name}: shared allowance reached');
    expect(strings['nudgeLeft.1'], '1 min left');
    expect(strings['nudgeOver.120'], '120 min over');
    expect(screenTime.argumentsOf('pickSelection'), [
      {'doneLabel': 'Done', 'cancelLabel': 'Cancel'},
    ]);

    // iOS does not say which apps were picked, so the user names them.
    expect(find.text('Name these apps'), findsOneWidget);
    expect(find.text('3 apps, categories or websites chosen'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('selection-name-field')),
      'Social',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selection-name-confirm')));
    await tester.pumpAndSettle();

    // Daily limits are DeviceActivity thresholds on iOS: offered first.
    expect(find.text('Daily limit'), findsOneWidget);
    expect(find.text('Set daily limit'), findsOneWidget);
    expect(find.text('Block now'), findsOneWidget);
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set schedule'));
    await tester.pumpAndSettle();

    final rule = settings.rules.single;
    expect(rule.appKey, 'ios-sel:abc');
    expect(rule.appName, 'Social');
    expect(rule.type, RestrictionRuleType.schedule);
    expect(_syncedRules(usage).single['appKey'], 'ios-sel:abc');
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS lists limits and routines without usage numbers', (
    tester,
  ) async {
    final usage = _Native(_usage, {
      'readRestrictionConfiguration': null,
      'hasNotificationsPermission': true,
      'takeRestrictionEvents': const [],
    });
    final screenTime = _Native(_screenTime, {
      'authorizationStatus': 'approved',
    });
    addTearDown(usage.dispose);
    addTearDown(screenTime.dispose);
    final repository = _AnyRepository(
      [
        const RestrictionRule(
          appKey: 'ios-sel:a',
          appName: 'Social',
          type: RestrictionRuleType.dailyLimit,
          limitMinutes: 90,
        ),
      ],
      [
        const BlockRoutine(
          id: 'r',
          name: 'Evening',
          dailyLimitMinutes: 60,
          isEnabled: true,
          apps: [RoutineApp(appKey: 'ios-sel:a', appName: 'Social')],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.ios),
          platformDataSourceProvider.overrideWithValue(IosUsageDataSource()),
          usageRepositoryProvider.overrideWithValue(repository),
          reportRepositoryProvider.overrideWithValue(repository),
          settingsRepositoryProvider.overrideWithValue(repository),
          restrictionsViewModelProvider.overrideWith(
            (ref) => RestrictionsViewModel(
              settingsRepository: repository,
              platformDataSource: IosUsageDataSource(),
              platform: UsagePlatform.ios,
            )..load(),
          ),
          restrictionPeriodInsightsProvider.overrideWith(
            (ref, week) async =>
                const RestrictionInsights(apps: [], recordedDays: 0, hours: []),
          ),
          installedAppsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const RestrictionsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Social'), findsWidgets);
    expect(find.text('1h 30m / day'), findsOneWidget);
    // No "used"/"left" numbers: iOS never gives them to Flutter.
    expect(find.textContaining('left today'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Evening'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('restrictions-scroll-view')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Shared daily limit · 1h'), findsOneWidget);
    expect(find.textContaining('used'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _AnyRepository extends Fake
    implements UsageRepository, ReportRepository, SettingsRepository {
  _AnyRepository(this.rules, this.routines);

  final List<RestrictionRule> rules;
  final List<BlockRoutine> routines;

  @override
  Future<List<RestrictionRule>> restrictionRules() async => List.of(rules);

  @override
  Future<List<BlockRoutine>> blockRoutines() async => List.of(routines);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('Summaries') || name.contains('Apps')) {
      return Future.value(<AppUsageSummary>[]);
    }
    if (name.contains('Overrides')) {
      return Future.value(<String, UsageCategory>{});
    }
    return Future<void>.value();
  }
}
