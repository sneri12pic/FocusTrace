import 'package:flutter/cupertino.dart' show CupertinoTimerPicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/widgets/preferred_limits_editor.dart';

void main() {
  final save = find.byKey(const ValueKey('preferred-save'));

  Future<List<int?>> openSheet(
    WidgetTester tester,
    int minutes, {
    double textScale = 1,
  }) async {
    final results = <int?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showPreferredMinutesSheet(
                  context,
                  title: 'Web',
                  minutes: minutes,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('keeps a time that is not on a 15 minute step', (tester) async {
    final results = await openSheet(tester, 47);
    expect(find.text('47m a day'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(results, [47]);
  });

  testWidgets('the wheels move one minute at a time', (tester) async {
    final results = await openSheet(tester, 47);
    await tester.drag(find.text('47'), const Offset(0, -32));
    await tester.pumpAndSettle();
    expect(find.text('48m a day'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(results, [48]);
  });

  testWidgets('a preset sets the time and moves the wheels', (tester) async {
    final results = await openSheet(tester, 47);
    await tester.tap(find.byKey(const ValueKey('preferred-preset-120')));
    await tester.pumpAndSettle();
    expect(find.text('2h a day'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
          .initialTimerDuration,
      const Duration(hours: 2),
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(results, [120]);
  });

  testWidgets('zero cannot be saved', (tester) async {
    await openSheet(tester, 1);
    await tester.drag(find.text('1').last, const Offset(0, 32));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('a stored time above the wheels is capped, and large text fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final results = await openSheet(tester, 5000, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(results, [24 * 60 - 1]);
  });
}
