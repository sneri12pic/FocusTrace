import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/src/domain/models/usage_item.dart';
import 'package:focustrace/src/presentation/widgets/bubble_chart.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';

void main() {
  test(
    'packBubbles resolves collisions and keeps the biggest at the center',
    () {
      const size = Size(800, 360);
      final radii = [
        72.0,
        60.0,
        55.0,
        48.0,
        40.0,
        34.0,
        30.0,
        28.0,
        26.0,
        26.0,
      ];
      final positions = packBubbles(radii, size);

      for (var i = 0; i < positions.length; i++) {
        for (var j = i + 1; j < positions.length; j++) {
          final distance = (positions[j] - positions[i]).distance;
          expect(
            distance,
            greaterThanOrEqualTo(radii[i] + radii[j] - 1),
            reason: 'bubbles $i and $j overlap',
          );
        }
      }

      final center = Offset(size.width / 2, size.height / 2 + 10);
      final distances = [for (final p in positions) (p - center).distance];
      expect(
        distances[0],
        equals(distances.reduce((a, b) => a < b ? a : b)),
        reason: 'biggest bubble should sit closest to the center',
      );
    },
  );

  testWidgets('packing runs once per items or size change', (tester) async {
    var layoutCount = 0;
    var items = [_item('a', 600), _item('b', 300)];

    Widget chart({UsageItem? selectedItem}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: BubbleChart(
              items: items,
              selectedItem: selectedItem,
              blockedItemIds: const {},
              nearLimitItemIds: const {},
              onItemSelected: (_) {},
              onSelectionDismissed: () {},
              onLayoutComputed: () => layoutCount++,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(chart());
    expect(layoutCount, 1);

    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(layoutCount, 1);

    await tester.pumpWidget(chart(selectedItem: items.first));
    expect(layoutCount, 1);

    items = [
      _item('a', 600, iconBytes: Uint8List.fromList(const [1, 2, 3])),
      _item('b', 300),
    ];
    await tester.pumpWidget(chart());
    expect(layoutCount, 1, reason: 'icon-only hydration must reuse the layout');

    items = [_item('a', 700), _item('b', 300)];
    await tester.pumpWidget(chart());
    expect(layoutCount, 2);

    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(layoutCount, 2);
  });
}

UsageItem _item(String id, int seconds, {Uint8List? iconBytes}) {
  return UsageItem(
    id: id,
    name: id,
    totalDurationSeconds: seconds,
    percentageOfTotal: 0.5,
    category: UsageCategory.activity,
    initials: id.toUpperCase(),
    iconBytes: iconBytes,
  );
}
