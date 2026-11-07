import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/view_models/restriction_insights.dart';

class _Settings extends Fake implements SettingsRepository {
  @override
  Future<List<RestrictionRule>> restrictionRules() async => const [];

  @override
  Future<List<BlockRoutine>> blockRoutines() async => const [];
}

/// A delegate with nothing of its own: adding it makes Localizations load
/// again for the same locale, which notifies its dependents.
class _ExtraDelegate extends LocalizationsDelegate<_ExtraDelegate> {
  const _ExtraDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<_ExtraDelegate> load(Locale locale) async => this;

  @override
  bool shouldReload(_ExtraDelegate old) => false;
}

/// The screen shows a progress indicator while loading, which never settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('restrictions screen sends block screen texts again after a '
      'failed send', (tester) async {
    const usage = MethodChannel('focustrace/usage');
    const screenTime = MethodChannel('focustrace/screen_time');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var sends = 0;
    messenger.setMockMethodCallHandler(usage, (call) async {
      return switch (call.method) {
        'hasNotificationsPermission' => false,
        'takeRestrictionEvents' => const [],
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(screenTime, (call) async {
      switch (call.method) {
        case 'authorizationStatus':
          return 'approved';
        case 'setShieldStrings':
          sends++;
          if (sends == 1) throw PlatformException(code: 'UNAVAILABLE');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(usage, null);
      messenger.setMockMethodCallHandler(screenTime, null);
    });

    Widget app({bool extra = false}) => ProviderScope(
      overrides: [
        usagePlatformProvider.overrideWithValue(UsagePlatform.ios),
        restrictionsViewModelProvider.overrideWith(
          (ref) => RestrictionsViewModel(
            settingsRepository: _Settings(),
            platformDataSource: IosUsageDataSource(),
            platform: UsagePlatform.ios,
          ),
        ),
        restrictionPeriodInsightsProvider.overrideWith(
          (ref, week) async =>
              const RestrictionInsights(apps: [], recordedDays: 0, hours: []),
        ),
        installedAppsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          if (extra) const _ExtraDelegate(),
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const RestrictionsScreen(),
      ),
    );

    await tester.pumpWidget(app());
    await settle(tester);
    expect(sends, 1);

    await tester.pumpWidget(app(extra: true));
    await settle(tester);
    expect(sends, 2, reason: 'the failed send is tried again');

    await tester.pumpWidget(app());
    await settle(tester);
    expect(sends, 2, reason: 'a stored locale is not sent again');
  });
}
