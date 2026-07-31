import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'localization/app_localizations_x.dart';
import 'providers.dart';
import 'screens/onboarding_screen.dart';

class FocusTraceApp extends ConsumerWidget {
  const FocusTraceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLanguageState = ref.watch(appLanguageViewModelProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: appLanguageState.language.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Flutter falls back to supportedLocales.first, which is alphabetical
      // ('de'). Match the device's preferred languages in order, then English.
      localeListResolutionCallback: resolveLocale,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5BC0EB),
          brightness: Brightness.dark,
          surface: const Color(0xFF070A10),
        ),
        scaffoldBackgroundColor: const Color(0xFF070A10),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF070A10),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: appLanguageState.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const OnboardingGate(),
    );
  }
}
