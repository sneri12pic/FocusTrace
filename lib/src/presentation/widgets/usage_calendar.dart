import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/models/app_usage_interval.dart';
import '../../domain/models/daily_app_usage.dart';
import '../localization/app_localizations_x.dart';
import '../view_models/app_usage_calendar_view_model.dart';
import 'trend_color.dart';

/// Month totals with their change from the month before.
class UsageMonthStats extends StatelessWidget {
  const UsageMonthStats({required this.state, required this.isGood, super.key});

  final AppUsageCalendarState state;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = state.monthTotal;
    final previous = state.previousSameSpan;
    final longest = state.longestInterval;
    // Today's share, while the shown month is the current one.
    final today = state.today;
    final todayUsage =
        state.month.year == today.year && state.month.month == today.month
        ? state.dayUsage(today)
        : null;
    // Figures that include Android's aggregated history read "≈".
    final approx = state.isMonthApproximate ? '≈' : '';
    UsageTrendChange change(int current, int before) =>
        UsageTrendChange.compare(
          currentSeconds: current,
          previousSeconds: before,
          previousWindowCovered: state.hasPreviousMonth,
        );
    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
    // Embedded in the summary card, so no surface of its own.
    return KeyedSubtree(
      key: const ValueKey('usage-month-stats'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
        // Equal-height tiles keep the change rows on one line across metrics.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatTile(
                icon: Icons.schedule_rounded,
                value:
                    approx +
                    l10n.compactDuration(
                      Duration(seconds: total.durationSeconds),
                    ),
                label: l10n.usageCalendarTotalThisMonth,
                today: todayUsage == null || todayUsage.durationSeconds == 0
                    ? null
                    : '+${l10n.compactDuration(Duration(seconds: todayUsage.durationSeconds))}',
                footer: _monthChange(
                  context,
                  change(total.durationSeconds, previous.durationSeconds),
                ),
              ),
              divider,
              _StatTile(
                icon: Icons.bar_chart_rounded,
                value:
                    approx +
                    l10n.compactDuration(
                      Duration(seconds: state.averagePerDaySeconds),
                    ),
                label: l10n.usageCalendarAveragePerDay,
                footer: _monthChange(
                  context,
                  change(
                    state.averagePerDaySeconds,
                    state.previousAveragePerDaySeconds,
                  ),
                ),
              ),
              divider,
              _StatTile(
                icon: Icons.smartphone_rounded,
                value: '${total.launchCount}',
                label: l10n.usageCalendarAppOpens,
                today: todayUsage == null || todayUsage.launchCount == 0
                    ? null
                    : '+${todayUsage.launchCount}',
                footer: _monthChange(
                  context,
                  change(total.launchCount, previous.launchCount),
                ),
              ),
              divider,
              _StatTile(
                icon: Icons.timer_outlined,
                value: longest == null
                    ? '-'
                    : l10n.compactDuration(
                        Duration(seconds: longest.durationSeconds),
                      ),
                label: l10n.usageCalendarLongestSession,
                footer: longest == null
                    ? null
                    : Text(
                        DateFormat.MMMd(
                          Localizations.localeOf(context).toString(),
                        ).format(longest.startedAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _monthChange(BuildContext context, UsageTrendChange change) {
    if (change.state == UsageTrendState.unavailable) return null;
    return UsageChangeLabel(
      change: change,
      isGood: isGood,
      caption: context.l10n.usageCalendarVsLastMonth,
    );
  }
}

/// A small tonal circle holding a metric's icon, shared by every metric.
class _MetricIcon extends StatelessWidget {
  const _MetricIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.14),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: scheme.primary),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.footer,
    this.today,
  });

  final IconData icon;
  final String value;
  final String label;
  final Widget? footer;

  /// Today's part of [value], such as "+2h 15m", shown beside it in green.
  final String? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.25,
    );
    final footer = this.footer;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetricIcon(icon),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            // Today's part in green on its own line, reserved in every tile
            // so the labels stay aligned across the row.
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(16),
              child: today == null
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        today!,
                        semanticsLabel:
                            '${context.l10n.dashboardDayToday} $today',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: trendColor(
                            theme,
                            isFlat: false,
                            isIncrease: false,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            // Two reserved lines so a one-line label doesn't lift its footer.
            SizedBox(
              height: 2 * (labelStyle?.fontSize ?? 11) * 1.25,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            const SizedBox(height: 6),
            // A fixed slot, even when a month has no comparison, so the card
            // keeps its height. Narrow tiles shrink the caption, not wrap it.
            SizedBox(
              height: 34,
              child: footer == null
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: footer,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An arrow and percentage; red for more use, green for less, flipped for
/// apps where more use is good.
class UsageChangeLabel extends StatelessWidget {
  const UsageChangeLabel({
    required this.change,
    required this.isGood,
    required this.caption,
    super.key,
  });

  final UsageTrendChange change;
  final bool isGood;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = change.state == UsageTrendState.newUsage;
    final isFlat =
        change.state == UsageTrendState.unchanged ||
        (change.state == UsageTrendState.change &&
            change.displayMagnitude == 0);
    final isIncrease = isNew || (!isFlat && change.percent! > 0);
    final color = trendColor(
      theme,
      isFlat: isFlat,
      isIncrease: isGood ? !isIncrease : isIncrease,
    );
    final value = isNew
        ? context.l10n.usageTrendNew
        : '${change.displayMagnitude}%${change.exceedsDisplayCap ? '+' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFlat
                  ? Icons.remove_rounded
                  : isIncrease
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              value,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Text(
          caption,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A month grid where each day is shaded by how long the app was used.
class UsageCalendar extends StatelessWidget {
  const UsageCalendar({
    required this.state,
    required this.isGood,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
    super.key,
  });

  final AppUsageCalendarState state;
  final bool isGood;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  static const _cellRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final firstWeekday = materialL10n.firstDayOfWeekIndex; // 0 = Sunday
    final month = state.month;
    final leading = (month.weekday % 7 - firstWeekday) % 7;
    // Always six weeks, so the grid is the same height for every month.
    const cellCount = 42;
    return Card(
      key: const ValueKey('usage-calendar'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('usage-calendar-previous'),
                  tooltip: context.l10n.usageCalendarPreviousMonth,
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('usage-calendar-next'),
                  tooltip: context.l10n.usageCalendarNextMonth,
                  onPressed: state.canShowNextMonth ? onNextMonth : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: Text(
                      materialL10n.narrowWeekdays[(firstWeekday + column) % 7],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            // A fixed-height slot, so loading never shifts the grid.
            SizedBox(
              height: 8,
              child: state.isLoading
                  ? const Center(child: LinearProgressIndicator(minHeight: 2))
                  : null,
            ),
            // Swipe left for the next month, right for the previous one.
            GestureDetector(
              key: const ValueKey('usage-calendar-swipe'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -200 && state.canShowNextMonth) {
                  onNextMonth();
                } else if (velocity > 200) {
                  onPreviousMonth();
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: GridView.count(
                  key: ValueKey(month),
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.82,
                  children: [
                    for (var cell = 0; cell < cellCount; cell++)
                      _dayCell(
                        context,
                        DateTime(month.year, month.month, cell - leading + 1),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Legend(isGood: isGood),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inMonth = day.month == state.month.month;
    final isFuture = day.isAfter(state.today);
    if (!inMonth || isFuture) {
      return Container(
        padding: const EdgeInsets.fromLTRB(7, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cellRadius),
          color: scheme.surfaceContainerHigh.withValues(
            alpha: inMonth ? 0.35 : 0.12,
          ),
        ),
        alignment: Alignment.topLeft,
        child: Text(
          '${day.day}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(
              alpha: inMonth ? 0.55 : 0.3,
            ),
          ),
        ),
      );
    }
    final seconds = state.dayUsage(day).durationSeconds;
    final isSelected = day == state.selectedDay;
    final isApproximate = state.isApproximateDay(day);
    final heat = usageHeatColor(
      theme,
      usageHeatBucket(seconds),
      isGood: isGood,
    );
    // Approximate days keep their colour but sit back, and read "≈".
    final background = seconds == 0
        ? scheme.surfaceContainerHigh
        : isApproximate
        ? Color.lerp(scheme.surfaceContainerHigh, heat, 0.55)!
        : heat;
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final duration =
        '${isApproximate ? '≈' : ''}'
        '${context.l10n.compactDuration(Duration(seconds: seconds))}';
    final locale = Localizations.localeOf(context).toString();
    return Semantics(
      button: true,
      selected: isSelected,
      label: context.l10n.usageDetailsDayValue(
        DateFormat.yMMMd(locale).format(day),
        duration,
      ),
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        // The selected day keeps its usage colour and gains a primary ring.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cellRadius),
          border: Border.all(
            color: isSelected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(_cellRadius - 2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('usage-calendar-day-${day.day}'),
            onTap: () => onDaySelected(day),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 4, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.day}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: seconds == 0 ? scheme.onSurface : foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (seconds > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        duration,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.isGood});

  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String d(int minutes) =>
        context.l10n.compactDuration(Duration(minutes: minutes));
    final labels = [
      '< ${d(30)}',
      '${d(30)} - ${d(60)}',
      '${d(60)} - ${d(120)}',
      '${d(120)} - ${d(180)}',
      '> ${d(180)}',
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (var bucket = 0; bucket < usageHeatBucketCount; bucket++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: usageHeatColor(theme, bucket, isGood: isGood),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                labels[bucket],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The day as a 24-hour dial: midnight at the top, noon at the bottom. The
/// ring is cut into quarter-hour slices that glow brighter the more of that
/// quarter was used. Tap or drag around it to select the nearest session and
/// read its exact times in the centre. With [onRestrictRange], press and
/// hold to pick a time frame (outlined in red), drag or tap to move its end,
/// then restrict it.
class UsageDayTimeline extends StatefulWidget {
  const UsageDayTimeline({
    required this.day,
    required this.intervals,
    this.emptyLabel,
    this.onRestrictRange,
    this.restrictedFrames = const [],
    super.key,
  });

  /// Schedules already restricting this app on [day], as (start, end)
  /// minutes; shown faintly behind the usage.
  final List<(int, int)> restrictedFrames;

  final DateTime day;
  final List<AppUsageInterval> intervals;

  /// Shown in the centre when the day has no sessions.
  final String? emptyLabel;

  /// Called with minutes since midnight; [endMinute] < [startMinute] means
  /// the frame runs past midnight.
  final void Function(int startMinute, int endMinute)? onRestrictRange;

  @override
  State<UsageDayTimeline> createState() => _UsageDayTimelineState();
}

/// Quarter-hour slices: wide enough to read, with exact times on selection.
const _slotMinutes = 15;
const _slots = 24 * 60 ~/ _slotMinutes;

/// Minutes since local midnight on the clock face, clipped to [day].
double _clockMinute(DateTime value, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  if (!value.isAfter(start)) return 0;
  if (!value.isBefore(end)) return 24 * 60;
  return value.hour * 60 + value.minute + value.second / 60;
}

/// Seconds used in each quarter-hour of [day], by local clock time.
List<int> usageBySlot(DateTime day, List<AppUsageInterval> intervals) {
  final slots = List.filled(_slots, 0);
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  for (final interval in intervals) {
    var cursor = interval.startedAt.isBefore(dayStart)
        ? dayStart
        : interval.startedAt;
    final end = interval.endedAt.isAfter(dayEnd) ? dayEnd : interval.endedAt;
    while (cursor.isBefore(end)) {
      final slot = (cursor.hour * 60 + cursor.minute) ~/ _slotMinutes;
      final boundary = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
        (cursor.minute ~/ _slotMinutes + 1) * _slotMinutes,
      );
      final stop = boundary.isBefore(end) ? boundary : end;
      slots[slot] += stop.difference(cursor).inSeconds;
      // A clock change can make the next boundary not move forward.
      cursor = stop.isAfter(cursor) ? stop : end;
    }
  }
  return slots;
}

class _UsageDayTimelineState extends State<UsageDayTimeline> {
  int? _selected;
  late List<int> _slotSeconds;

  /// First and last slot of the time frame being picked, inclusive. The last
  /// one may be "before" the first: the frame then runs past midnight.
  (int, int)? _range;

  @override
  void initState() {
    super.initState();
    _slotSeconds = usageBySlot(widget.day, widget.intervals);
  }

  @override
  void didUpdateWidget(UsageDayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day ||
        oldWidget.intervals != widget.intervals) {
      _selected = null;
      _range = null;
      _slotSeconds = usageBySlot(widget.day, widget.intervals);
    }
  }

  /// Whether [position] is on the ring itself (with a little slack), not in
  /// the middle or out by the labels. Matches the painter's geometry.
  bool _onRing(Offset position, Size size) {
    final distance = (position - size.center(Offset.zero)).distance;
    final outer = size.shortestSide / 2 - 30;
    final inner = outer * 0.76;
    return distance >= inner - 14 && distance <= outer + 14;
  }

  /// The quarter-hour slot under [position], or null off the ring.
  int? _slotAt(Offset position, Size size) {
    final delta = position - size.center(Offset.zero);
    if (!_onRing(position, size)) return null;
    final turn = (math.atan2(delta.dx, -delta.dy) / (2 * math.pi) + 1) % 1;
    return (turn * _slots).floor() % _slots;
  }

  /// Press and hold: start a frame on the session under the finger, or on
  /// the touched quarter-hour when there is none.
  void _startRange(Offset position, Size size) {
    final slot = _slotAt(position, size);
    if (slot == null) return;
    var range = (slot, slot);
    final minute = slot * _slotMinutes + _slotMinutes / 2;
    for (final interval in widget.intervals) {
      final start = _clockMinute(interval.startedAt, widget.day);
      final end = _clockMinute(interval.endedAt, widget.day);
      if (start <= minute && minute <= end + _slotMinutes / 2) {
        final first = start ~/ _slotMinutes;
        range = (first, math.max(first, (end - 0.001) ~/ _slotMinutes));
        break;
      }
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _range = range;
      _selected = null;
    });
  }

  /// Dragging or tapping while a frame is picked moves its end there.
  void _moveRangeEnd(Offset position, Size size) {
    final range = _range;
    final slot = _slotAt(position, size);
    if (range == null || slot == null || slot == range.$2) return;
    // A whole day would leave no start or end; stop one slot short.
    if ((slot - range.$1) % _slots == _slots - 1) return;
    HapticFeedback.selectionClick();
    setState(() => _range = (range.$1, slot));
  }

  void _restrictRange() {
    final range = _range;
    if (range == null) return;
    widget.onRestrictRange?.call(
      range.$1 * _slotMinutes,
      (range.$2 + 1) * _slotMinutes % (24 * 60),
    );
    setState(() => _range = null);
  }

  /// Selects the session under the touch, or one within a few minutes of it.
  /// A tap on an empty part of the ring clears the selection; touches off
  /// the ring are ignored.
  void _pick(Offset position, Size size, {bool clearOnMiss = false}) {
    final intervals = widget.intervals;
    if (intervals.isEmpty || !_onRing(position, size)) return;
    final delta = position - size.center(Offset.zero);
    // 0 at the top, growing clockwise.
    final turn = (math.atan2(delta.dx, -delta.dy) / (2 * math.pi) + 1) % 1;
    final minute = turn * 24 * 60;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < intervals.length; i++) {
      final start = _clockMinute(intervals[i].startedAt, widget.day);
      final end = _clockMinute(intervals[i].endedAt, widget.day);
      final distance = minute < start
          ? start - minute
          : minute > end
          ? minute - end
          : 0.0;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    // ponytail: fixed 20-minute reach, about one slice either side.
    if (bestDistance > 20) {
      if (clearOnMiss && _selected != null) setState(() => _selected = null);
      return;
    }
    if (best != _selected) {
      HapticFeedback.selectionClick();
      setState(() => _selected = best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final hourFormat = use24 ? DateFormat('HH', locale) : DateFormat.j(locale);
    final timeFormat = use24 ? DateFormat.Hm(locale) : DateFormat.jm(locale);
    final muted = theme.colorScheme.onSurfaceVariant;
    final intervals = widget.intervals;
    final selected = _selected == null || _selected! >= intervals.length
        ? null
        : intervals[_selected!];
    final total = intervals.fold(
      Duration.zero,
      (sum, interval) => sum + interval.endedAt.difference(interval.startedAt),
    );
    String range(AppUsageInterval interval) =>
        '${timeFormat.format(interval.startedAt)} – '
        '${timeFormat.format(interval.endedAt)}';

    // A clear red, stronger than the theme's soft error tone.
    const rangeColor = Color(0xFFFF5A5F);
    final picked = _range;
    String clock(int minute) =>
        timeFormat.format(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));
    final Widget centre;
    if (picked != null) {
      final slots = (picked.$2 - picked.$1) % _slots + 1;
      centre = Column(
        key: const ValueKey('usage-day-timeline-range'),
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${clock(picked.$1 * _slotMinutes)} – '
              '${clock((picked.$2 + 1) * _slotMinutes % (24 * 60))}',
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: rangeColor,
              ),
            ),
          ),
          Text(
            l10n.compactDuration(Duration(minutes: slots * _slotMinutes)),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    } else if (intervals.isEmpty) {
      centre = Text(
        widget.emptyLabel ?? '',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      );
    } else if (selected == null) {
      centre = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.compactDuration(total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l10n.usageCalendarTotalTime,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      );
    } else {
      centre = Column(
        key: const ValueKey('usage-day-timeline-selection'),
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              range(selected),
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            l10n.compactDuration(
              selected.endedAt.difference(selected.startedAt),
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.usageCalendarTotalTime} ${l10n.compactDuration(total)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
    }

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, 320.0);
            final size = Size.square(side);
            return Semantics(
              label: [
                for (final interval in intervals)
                  '${range(interval)}, '
                      '${l10n.compactDuration(interval.endedAt.difference(interval.startedAt))}',
              ].join('; '),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Only a finished tap or a real drag selects, so a touch
                // that turns into scrolling the page selects nothing.
                onTapUp: (d) => _range == null
                    ? _pick(d.localPosition, size, clearOnMiss: true)
                    : _moveRangeEnd(d.localPosition, size),
                onPanStart: (d) => _range == null
                    ? _pick(d.localPosition, size)
                    : _moveRangeEnd(d.localPosition, size),
                onPanUpdate: (d) => _range == null
                    ? _pick(d.localPosition, size)
                    : _moveRangeEnd(d.localPosition, size),
                onLongPressStart: widget.onRestrictRange == null
                    ? null
                    : (d) => _startRange(d.localPosition, size),
                onLongPressMoveUpdate: widget.onRestrictRange == null
                    ? null
                    : (d) => _moveRangeEnd(d.localPosition, size),
                child: SizedBox.fromSize(
                  size: size,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('usage-day-timeline'),
                          painter: _ClockPainter(
                            day: widget.day,
                            slotSeconds: _slotSeconds,
                            selected: picked == null ? selected : null,
                            range: picked,
                            frames: widget.restrictedFrames,
                            rangeColor: rangeColor,
                            trackColor: theme
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.7),
                            dimColor: const Color(0xFF1C5FA6),
                            brightColor: const Color(0xFF8FDBFF),
                            tickColor: muted.withValues(alpha: 0.6),
                            outlineColor: Colors.white,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.all(side * 0.28),
                          child: Center(child: centre),
                        ),
                      ),
                      // The four cardinal hours, just outside the ticks.
                      for (final (hour, alignment) in const [
                        (0, Alignment.topCenter),
                        (6, Alignment.centerRight),
                        (12, Alignment.bottomCenter),
                        (18, Alignment.centerLeft),
                      ])
                        Align(
                          alignment: alignment,
                          child: Text(
                            hourFormat.format(DateTime(2000, 1, 1, hour)),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (picked != null)
          // The "popup": restrict the picked frame, or let it go.
          Container(
            key: const ValueKey('usage-day-timeline-restrict-bar'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: rangeColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: rangeColor.withValues(alpha: .5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rxRangeQuestion,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.rxRangeHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _range = null),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: rangeColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _restrictRange,
                  child: Text(l10n.rxRangeAction),
                ),
              ],
            ),
          )
        else
          // Always laid out, so the card keeps its height on empty days.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Visibility(
              visible: intervals.isNotEmpty,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Text(
                l10n.usageTimelineHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({
    required this.day,
    required this.slotSeconds,
    required this.selected,
    this.range,
    this.frames = const [],
    this.startHandle = false,
    this.slotCapacitySeconds = _slotMinutes * 60,
    this.rangeColor = Colors.red,
    required this.trackColor,
    required this.dimColor,
    required this.brightColor,
    required this.tickColor,
    required this.outlineColor,
  });

  final DateTime day;
  final List<int> slotSeconds;
  final AppUsageInterval? selected;
  final (int, int)? range;

  /// Restrictions already set, as (start, end) minutes; drawn faintly.
  final List<(int, int)> frames;

  /// Also marks the range's start with a dot, when both ends can move.
  final bool startHandle;

  /// Seconds that make a slice fully bright (more than 15 min when the
  /// usage covers several days).
  final int slotCapacitySeconds;
  final Color rangeColor;
  final Color trackColor;
  final Color dimColor;
  final Color brightColor;
  final Color tickColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 30;
    final thickness = outer * 0.24;
    final inner = outer - thickness;
    const turn = 2 * math.pi;
    // Clockwise from the top.
    double angleOf(double minute) => -math.pi / 2 + minute / (24 * 60) * turn;
    final slice = turn / _slots;
    // A hairline gap between slices, constant in pixels.
    final gap = 1.2 / outer;

    Path sector(double from, double to, double r0, double r1) => Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: r1),
        from,
        to - from,
        true,
      )
      ..arcTo(Rect.fromCircle(center: center, radius: r0), to, from - to, false)
      ..close();

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _slots; i++) {
      final from = -math.pi / 2 + i * slice + gap / 2;
      final to = from + slice - gap;
      final used = slotSeconds[i] / slotCapacitySeconds;
      paint.color = used <= 0
          ? trackColor
          // Any use gets at least a visible shade.
          : Color.lerp(dimColor, brightColor, used.clamp(0.0, 1.0))!;
      canvas.drawPath(sector(from, to, inner, outer), paint);
    }

    // Hour ticks outside the ring; the four cardinal hours are longer.
    final tick = Paint()
      ..color = tickColor
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var hour = 0; hour < 24; hour++) {
      final angle = angleOf(hour * 60.0);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final length = hour % 6 == 0 ? 9.0 : 4.0;
      canvas.drawLine(
        center + direction * (outer + 5),
        center + direction * (outer + 5 + length),
        tick,
      );
    }

    // Existing restrictions: a soft red band, quieter than a fresh pick.
    for (final (start, end) in frames) {
      final from = angleOf(start.toDouble());
      var to = angleOf(end.toDouble());
      if (to <= from) to += turn;
      final band = sector(from, to, inner - 2, outer + 2);
      canvas.drawPath(band, Paint()..color = rangeColor.withValues(alpha: .16));
      canvas.drawPath(
        band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = rangeColor.withValues(alpha: .55),
      );
    }

    final picked = range;
    if (picked != null) {
      // The time frame being picked: tinted, outlined in red, with a dot on
      // the end that moves.
      final slots = (picked.$2 - picked.$1) % _slots + 1;
      final from = -math.pi / 2 + picked.$1 * slice + gap / 2;
      final to = from + slots * slice - gap;
      final band = sector(from, to, inner - 3, outer + 3);
      canvas.drawPath(band, Paint()..color = rangeColor.withValues(alpha: .25));
      canvas.drawPath(
        band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round
          ..color = rangeColor,
      );
      canvas.drawCircle(
        center + Offset(math.cos(to), math.sin(to)) * (outer + 3),
        6,
        Paint()..color = rangeColor,
      );
      if (startHandle) {
        canvas.drawCircle(
          center + Offset(math.cos(from), math.sin(from)) * (outer + 3),
          6,
          Paint()..color = rangeColor,
        );
      }
    }

    final session = selected;
    if (session != null) {
      // Outline the whole quarter-hour slices the session touches, so even
      // a short one is easy to spot; the centre gives its exact times.
      final start = _clockMinute(session.startedAt, day);
      final end = _clockMinute(session.endedAt, day);
      final firstSlot = start ~/ _slotMinutes;
      final lastSlot = math.max(firstSlot, (end - 0.001) ~/ _slotMinutes);
      final from = angleOf(firstSlot * _slotMinutes.toDouble()) + gap / 2;
      final to = angleOf((lastSlot + 1) * _slotMinutes.toDouble()) - gap / 2;
      canvas.drawPath(
        sector(from, to, inner - 3, outer + 3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round
          ..color = outlineColor,
      );
      final middle = (from + to) / 2;
      canvas.drawCircle(
        center + Offset(math.cos(middle), math.sin(middle)) * (inner - 9),
        4,
        Paint()..color = outlineColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) =>
      oldDelegate.slotSeconds != slotSeconds ||
      oldDelegate.selected != selected ||
      oldDelegate.range != range ||
      oldDelegate.frames != frames ||
      oldDelegate.day != day ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.tickColor != tickColor;
}

/// Picks a schedule on a 24-hour dial over this app's usage: drag either red
/// end around the ring, or tap where the nearer end should go. Ends snap to
/// quarter-hours.
class ScheduleRangeDial extends StatefulWidget {
  const ScheduleRangeDial({
    required this.startMinute,
    required this.endMinute,
    required this.onChanged,
    this.slotSeconds,
    this.slotCapacitySeconds = _slotMinutes * 60,
    super.key,
  });

  final int startMinute;
  final int endMinute;
  final void Function(int startMinute, int endMinute) onChanged;

  /// Usage per quarter-hour to draw under the range; null while loading.
  final List<int>? slotSeconds;
  final int slotCapacitySeconds;

  @override
  State<ScheduleRangeDial> createState() => _ScheduleRangeDialState();
}

class _ScheduleRangeDialState extends State<ScheduleRangeDial> {
  bool? _movingStart;

  /// The quarter-hour boundary (0-95) nearest [position], or null in the
  /// middle of the dial.
  int? _boundaryAt(Offset position, Size size) {
    final delta = position - size.center(Offset.zero);
    if (delta.distance < size.shortestSide / 2 * 0.4) return null;
    final turn = (math.atan2(delta.dx, -delta.dy) / (2 * math.pi) + 1) % 1;
    return (turn * _slots).round() % _slots;
  }

  int _distance(int boundary, int minute) {
    final d = (boundary - minute / _slotMinutes).abs() % _slots;
    return math.min(d, _slots - d).round();
  }

  void _grab(Offset position, Size size) {
    final boundary = _boundaryAt(position, size);
    if (boundary == null) return;
    _movingStart =
        _distance(boundary, widget.startMinute) <
        _distance(boundary, widget.endMinute);
    _move(position, size);
  }

  void _move(Offset position, Size size) {
    final movingStart = _movingStart;
    final boundary = _boundaryAt(position, size);
    if (movingStart == null || boundary == null) return;
    final minute = boundary * _slotMinutes;
    final start = movingStart ? minute : widget.startMinute;
    final end = movingStart ? widget.endMinute : minute;
    // A schedule needs different start and end times.
    if (start == end ||
        (start == widget.startMinute && end == widget.endMinute)) {
      return;
    }
    HapticFeedback.selectionClick();
    widget.onChanged(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final hourFormat = use24 ? DateFormat('HH', locale) : DateFormat.j(locale);
    final timeFormat = use24 ? DateFormat.Hm(locale) : DateFormat.jm(locale);
    final muted = theme.colorScheme.onSurfaceVariant;
    const rangeColor = Color(0xFFFF5A5F);
    String clock(int minute) =>
        timeFormat.format(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));
    final start = widget.startMinute;
    final end = widget.endMinute;
    final length = (end - start) % (24 * 60);
    final firstSlot = start ~/ _slotMinutes;
    final lastSlot = ((end - 1) % (24 * 60)) ~/ _slotMinutes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, 300.0);
        final size = Size.square(side);
        return Center(
          child: Semantics(
            label: '${clock(start)} – ${clock(end)}',
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              // Claims touches at once, so dragging around the ring moves an
              // end instead of scrolling the sheet.
              gestures: {
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      EagerGestureRecognizer
                    >(EagerGestureRecognizer.new, (_) {}),
              },
              child: Listener(
                onPointerDown: (e) => _grab(e.localPosition, size),
                onPointerMove: (e) => _move(e.localPosition, size),
                onPointerUp: (_) => _movingStart = null,
                onPointerCancel: (_) => _movingStart = null,
                child: SizedBox.fromSize(
                  size: size,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('schedule-range-dial'),
                          painter: _ClockPainter(
                            day: DateTime(2000),
                            slotSeconds:
                                widget.slotSeconds ?? List.filled(_slots, 0),
                            slotCapacitySeconds: widget.slotCapacitySeconds,
                            selected: null,
                            range: (firstSlot, lastSlot),
                            rangeColor: rangeColor,
                            startHandle: true,
                            trackColor: theme
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.7),
                            dimColor: const Color(0xFF1C5FA6),
                            brightColor: const Color(0xFF8FDBFF),
                            tickColor: muted.withValues(alpha: 0.6),
                            outlineColor: Colors.white,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.all(side * 0.28),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${clock(start)} – ${clock(end)}',
                                    key: const ValueKey('schedule-range-text'),
                                    maxLines: 1,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: rangeColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  l10n.compactDuration(
                                    Duration(minutes: length),
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (end < start)
                                  Text(
                                    l10n.rxNextDay,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (final (hour, alignment) in const [
                        (0, Alignment.topCenter),
                        (6, Alignment.centerRight),
                        (12, Alignment.bottomCenter),
                        (18, Alignment.centerLeft),
                      ])
                        Align(
                          alignment: alignment,
                          child: Text(
                            hourFormat.format(DateTime(2000, 1, 1, hour)),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
