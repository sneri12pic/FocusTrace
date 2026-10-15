import 'package:flutter/material.dart';

/// Red for usage increases, green for decreases, muted for flat/unknown.
Color trendColor(
  ThemeData theme, {
  required bool isFlat,
  required bool isIncrease,
}) {
  if (isFlat) {
    return theme.colorScheme.onSurfaceVariant;
  }
  if (isIncrease) {
    return theme.colorScheme.error;
  }
  return theme.brightness == Brightness.dark
      ? const Color(0xFF80D89D)
      : const Color(0xFF19703A);
}

/// Calendar legend buckets: <30m, 30m-1h, 1h-2h, 2h-3h, >3h.
int usageHeatBucket(int seconds) {
  const upperBounds = [30 * 60, 60 * 60, 2 * 60 * 60, 3 * 60 * 60];
  for (var bucket = 0; bucket < upperBounds.length; bucket++) {
    if (seconds < upperBounds[bucket]) return bucket;
  }
  return upperBounds.length;
}

const usageHeatBucketCount = 5;

/// Dark to bright red per bucket, or green for apps where more use is good.
///
/// The trend colours are pastel in the dark scheme, so the scale keeps their
/// hue and raises saturation to reach a clearly bright top bucket.
Color usageHeatColor(ThemeData theme, int bucket, {required bool isGood}) {
  final trend = HSLColor.fromColor(
    trendColor(theme, isFlat: false, isIncrease: !isGood),
  );
  final vivid = trend.withSaturation(isGood ? 0.6 : 0.78).withLightness(0.5);
  return Color.lerp(
    theme.colorScheme.surfaceContainerHigh,
    vivid.toColor(),
    0.28 + 0.72 * bucket / (usageHeatBucketCount - 1),
  )!;
}
