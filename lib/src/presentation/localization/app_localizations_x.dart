import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/usage_item.dart';

/// Picks the first device language we ship, falling back to English.
/// ponytail: language-code match only; add script/country matching if we ever
/// ship two variants of one language (e.g. pt-BR next to pt-PT).
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) {
        return candidate;
      }
    }
  }
  return const Locale('en');
}

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppLanguageLocale on AppLanguage {
  Locale? get locale {
    return switch (this) {
      AppLanguage.system => null,
      AppLanguage.english => const Locale('en'),
      AppLanguage.spanish => const Locale('es'),
      AppLanguage.french => const Locale('fr'),
      AppLanguage.german => const Locale('de'),
      AppLanguage.portugueseBrazil => const Locale('pt', 'BR'),
      AppLanguage.japanese => const Locale('ja'),
      AppLanguage.ukrainian => const Locale('uk'),
    };
  }
}

extension AppLocalizationsFormatting on AppLocalizations {
  String compactDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 1) {
      return durationLessThanOneMinute;
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return durationMinutesShort(minutes);
    }
    if (minutes == 0) {
      return durationHoursShort(hours);
    }
    return durationHoursMinutesShort(hours, minutes);
  }

  String usageCategoryLabel(UsageCategory category) {
    return switch (category) {
      UsageCategory.entertainment => categoryEntertainment,
      UsageCategory.productivity => categoryProductivity,
      UsageCategory.web => categoryWeb,
      UsageCategory.communication => categoryCommunication,
      UsageCategory.system => categorySystem,
      UsageCategory.activity => categoryActivity,
    };
  }
}
