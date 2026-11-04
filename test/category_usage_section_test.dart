import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/domain/models/usage_item.dart';
import 'package:focustrace/src/presentation/widgets/app_category_widgets.dart';
import 'package:focustrace/src/presentation/widgets/category_usage_section.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester, List<CategoryUsage> rows) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: CategoryUsageSection(
              rows: rows,
              expanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

  Color tint(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('category-usage-tint')),
    );
    final gradient = (box.decoration! as BoxDecoration).gradient!;
    return (gradient as LinearGradient).colors.first;
  }

  testWidgets('rows wear their category and the top one tints the section', (
    tester,
  ) async {
    await pumpSection(tester, const [
      CategoryUsage(
        category: UsageCategory.productivity,
        seconds: 600,
        share: 0.6,
      ),
      CategoryUsage(category: null, seconds: 400, share: 0.4),
    ]);

    expect(
      tint(tester),
      UsageCategory.productivity.color.withValues(alpha: 0.3),
    );
    expect(find.byIcon(UsageCategory.productivity.icon), findsOneWidget);
    expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    // The title names the top category; its dot is the only decorated circle.
    expect(find.text('Productivity'), findsNWidgets(2));
    final dot = tester.widget<DecoratedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(
      (dot.decoration as BoxDecoration).color,
      UsageCategory.productivity.color,
    );
    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(bars.first.color, UsageCategory.productivity.color);
    expect(bars.last.color, isNot(UsageCategory.productivity.color));
  });

  testWidgets('the tint follows a change of top category', (tester) async {
    await pumpSection(tester, const [
      CategoryUsage(category: UsageCategory.web, seconds: 1, share: 1),
    ]);
    expect(tint(tester), UsageCategory.web.color.withValues(alpha: 0.3));

    await pumpSection(tester, const [
      CategoryUsage(
        category: UsageCategory.communication,
        seconds: 1,
        share: 1,
      ),
    ]);
    expect(
      tint(tester),
      UsageCategory.communication.color.withValues(alpha: 0.3),
    );
  });
}
