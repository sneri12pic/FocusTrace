import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('routine editor uses rounded fields and saves shared limit', (
    tester,
  ) async {
    BlockRoutine? saved;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                saved = await showRoutineEditor(
                  context,
                  apps: const [
                    AppUsageSummary(
                      appName: 'Social',
                      packageName: 'com.example.social',
                      totalDurationSeconds: 0,
                      percentageOfTotal: 0,
                    ),
                  ],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(2));
    for (final field in fields) {
      final border = field.decoration?.border! as OutlineInputBorder;
      expect(border.borderRadius.topLeft.x, 28);
    }

    await tester.enterText(find.byType(TextField).first, 'Focus');
    await tester.tap(find.text('Social'));
    await tester.tap(find.text('Daily shared limit'));
    await tester.pump();
    expect(find.text('3h'), findsWidgets);

    await tester.tap(find.text('Save routine'));
    await tester.pumpAndSettle();

    expect(saved?.name, 'Focus');
    expect(saved?.apps.single.appKey, 'com.example.social');
    expect(saved?.dailyLimitMinutes, 180);
    expect(saved?.isEnabled, isTrue);
  });
}
