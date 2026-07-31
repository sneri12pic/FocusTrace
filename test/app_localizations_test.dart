import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/localization/app_localizations_x.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unsupported device languages resolve to English, not German', () {
    const supported = AppLocalizations.supportedLocales;

    expect(resolveLocale([const Locale('it')], supported), const Locale('en'));
    expect(resolveLocale(null, supported), const Locale('en'));
    expect(resolveLocale(const [], supported), const Locale('en'));
    // Device preference order wins over supportedLocales order.
    expect(
      resolveLocale(const [Locale('zh'), Locale('fr')], supported),
      const Locale('fr'),
    );
    expect(
      resolveLocale(const [Locale('pt', 'BR')], supported),
      const Locale('pt'),
    );
    expect(resolveLocale(const [Locale('de')], supported), const Locale('de'));
  });

  test(
    'every supported locale loads complete messages and placeholders',
    () async {
      expect(AppLocalizations.supportedLocales, hasLength(7));

      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.settingsTitle, isNotEmpty, reason: locale.toLanguageTag());
        expect(
          l10n.onboardingWelcomeTitle,
          isNotEmpty,
          reason: locale.toLanguageTag(),
        );
        expect(
          l10n.restrictionsBlockedUntil('10:30'),
          contains('10:30'),
          reason: locale.toLanguageTag(),
        );
        expect(
          l10n.excludeAppDialogTitle('Example'),
          contains('Example'),
          reason: locale.toLanguageTag(),
        );
        expect(l10n.secondsCount(1), isNot(contains('{')));
        expect(l10n.secondsCount(2), isNot(contains('{')));
      }
    },
  );
}
