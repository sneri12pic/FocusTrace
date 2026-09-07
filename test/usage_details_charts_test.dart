import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/presentation/widgets/usage_details_charts.dart';

void main() {
  for (final period in UsageDetailsPeriod.values) {
    testWidgets(
      'swipes between charts and updates both dots for ${period.name}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = UsageDetailsChart.bars;
        await tester.pumpWidget(
          _host(period: period, onChanged: (chart) => selected = chart),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('usage-bar-chart')).hitTestable(),
          findsOneWidget,
        );
        _expectDots(tester, UsageDetailsChart.bars);

        await tester.drag(
          find.byKey(const ValueKey('usage-chart-pages')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
        expect(selected, UsageDetailsChart.area);
        expect(
          find.byKey(const ValueKey('usage-area-chart')).hitTestable(),
          findsOneWidget,
        );
        _expectDots(tester, UsageDetailsChart.area);

        await tester.tap(find.byKey(const ValueKey('usage-chart-dot-bars')));
        await tester.pumpAndSettle();
        expect(selected, UsageDetailsChart.bars);
        expect(find.byKey(const ValueKey('usage-trend-line')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('restores the area page immediately and renders zero usage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(initial: UsageDetailsChart.area, empty: true),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('usage-area-chart')).hitTestable(),
      findsOneWidget,
    );
    _expectDots(tester, UsageDetailsChart.area);
    await tester.drag(
      find.byKey(const ValueKey('usage-chart-pages')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('usage-bar-chart')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _expectDots(WidgetTester tester, UsageDetailsChart selected) {
  final colors = <Color>[];
  for (final chart in UsageDetailsChart.values) {
    final dot = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey('usage-chart-dot-${chart.name}')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    colors.add((dot.decoration! as BoxDecoration).color!);
  }
  expect(colors[selected.index].a, 1);
  expect(colors[1 - selected.index].a, closeTo(0.3, 0.01));
}

Widget _host({
  UsageDetailsPeriod period = UsageDetailsPeriod.sevenDays,
  UsageDetailsChart initial = UsageDetailsChart.bars,
  bool empty = false,
  ValueChanged<UsageDetailsChart>? onChanged,
}) {
  var selected = initial;
  final count = switch (period) {
    UsageDetailsPeriod.sevenDays => 7,
    UsageDetailsPeriod.twoWeeks => 14,
    UsageDetailsPeriod.month => 30,
    UsageDetailsPeriod.year => 12,
  };
  final points = [
    for (var i = 0; i < count; i++)
      DailyUsagePoint(
        day: period == UsageDetailsPeriod.year
            ? DateTime(2026, i + 1)
            : DateTime(2026, 8, i + 1),
        durationSeconds: empty
            ? 0
            : [600, 3000, 1200, 4200, 1800, 0, 900][i % 7],
      ),
  ];
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: UsageDetailsCharts(
            points: points,
            period: period,
            chart: selected,
            onChartChanged: (chart) {
              setState(() => selected = chart);
              onChanged?.call(chart);
            },
          ),
        ),
      ),
    ),
  );
}
