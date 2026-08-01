import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/src/presentation/widgets/bubble_chart.dart';

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
}
