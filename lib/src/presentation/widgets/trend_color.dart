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
