import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/widgets/ios_usage_report_view.dart';

/// Its own file: the report's "texts sent for this locale" state is static.
void main() {
  testWidgets('report texts that failed to reach iOS are sent again', (
    tester,
  ) async {
    const screenTime = MethodChannel('focustrace/screen_time');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var calls = 0;
    messenger.setMockMethodCallHandler(screenTime, (call) async {
      if (call.method != 'setShieldStrings') return null;
      calls++;
      if (calls == 1) throw PlatformException(code: 'UNAVAILABLE');
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(screenTime, null));

    Widget app(bool showReport) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: showReport
                ? IosUsageReportView(
                    kind: IosUsageReportKind.hourly,
                    date: DateTime(2026, 11, 7),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(calls, 2, reason: 'the failed send is retried');

    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(calls, 2, reason: 'sent once per locale after it succeeded');
  });
}
