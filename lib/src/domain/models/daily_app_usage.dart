import 'app_usage_summary.dart';

class DailyAppUsage {
  const DailyAppUsage({required this.day, required this.summary});

  final DateTime day;
  final AppUsageSummary summary;
}

class UsageTrend {
  const UsageTrend({
    this.day = UsageTrendChange.unavailable,
    this.week = UsageTrendChange.unavailable,
    this.month = UsageTrendChange.unavailable,
  });

  final UsageTrendChange day;
  final UsageTrendChange week;
  final UsageTrendChange month;

  bool get hasData =>
      day.state != UsageTrendState.unavailable ||
      week.state != UsageTrendState.unavailable ||
      month.state != UsageTrendState.unavailable;
}

enum UsageTrendState {
  /// The previous window is not fully covered by recorded history.
  unavailable,

  /// Both windows hold the same usage, including zero and zero.
  unchanged,

  /// Usage rose from no meaningful baseline, so a percentage would be noise.
  newUsage,

  /// A genuine percentage comparison; see [UsageTrendChange.percent].
  change,
}

/// One window-over-window comparison. D, W and M all go through [compare], so
/// the three badges cannot disagree about what counts as a valid baseline.
class UsageTrendChange {
  const UsageTrendChange._(this.state, [this.percent]);

  factory UsageTrendChange.compare({
    required int currentSeconds,
    required int previousSeconds,
    required bool previousWindowCovered,
  }) {
    if (!previousWindowCovered) {
      return unavailable;
    }
    if (currentSeconds == previousSeconds) {
      return const UsageTrendChange._(UsageTrendState.unchanged);
    }
    // A few seconds of accidental use in the previous window is not a
    // baseline: dividing by it is what produced "+1459129%". Decreases from a
    // tiny baseline stay percentages because they are bounded at -100%.
    if (previousSeconds < minimumBaselineSeconds &&
        currentSeconds > previousSeconds) {
      return const UsageTrendChange._(UsageTrendState.newUsage);
    }
    return UsageTrendChange._(
      UsageTrendState.change,
      (currentSeconds - previousSeconds) / previousSeconds * 100,
    );
  }

  static const unavailable = UsageTrendChange._(UsageTrendState.unavailable);
  static const minimumBaselineSeconds = 60;
  static const maxDisplayPercent = 999;

  final UsageTrendState state;

  /// Raw, unbounded change. Non-null only for [UsageTrendState.change].
  final double? percent;

  /// Rounded magnitude for display, bounded to [maxDisplayPercent] upward and
  /// 100 downward.
  int get displayMagnitude {
    final raw = percent ?? 0;
    return raw.abs().round().clamp(0, raw < 0 ? 100 : maxDisplayPercent);
  }

  bool get exceedsDisplayCap => (percent ?? 0) > maxDisplayPercent;
}
