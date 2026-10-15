import 'dart:math' as math;

import 'package:flutter/material.dart';
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
                value: l10n.compactDuration(
                  Duration(seconds: total.durationSeconds),
                ),
                label: l10n.usageCalendarTotalThisMonth,
                footer: _monthChange(
                  context,
                  change(total.durationSeconds, previous.durationSeconds),
                ),
              ),
              divider,
              _StatTile(
                icon: Icons.bar_chart_rounded,
                value: l10n.compactDuration(
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
  });

  final IconData icon;
  final String value;
  final String label;
  final Widget? footer;

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
            GridView.count(
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
    final background = seconds == 0
        ? scheme.surfaceContainerHigh
        : usageHeatColor(theme, usageHeatBucket(seconds), isGood: isGood);
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final duration = context.l10n.compactDuration(Duration(seconds: seconds));
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

/// The selected day's total, opens, average session and 24-hour timeline.
class UsageDayPanel extends StatelessWidget {
  const UsageDayPanel({
    required this.state,
    required this.day,
    required this.isGood,
    super.key,
  });

  final AppUsageCalendarState state;
  final DateTime day;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final usage = state.dayUsage(day);
    final busiest = state.busiestDaySeconds;
    final average = state.averagePerDaySeconds;
    final intervals = state.intervalsOn(day);
    return Card(
      key: const ValueKey('usage-day-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMEd(locale).format(day),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox.square(
                  dimension: 112,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: busiest == 0
                            ? 0
                            : usage.durationSeconds / busiest,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              child: Text(
                                l10n.compactDuration(
                                  Duration(seconds: usage.durationSeconds),
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              l10n.usageCalendarTotalTime,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PanelValue(
                        icon: Icons.smartphone_rounded,
                        child: _valueAndLabel(
                          context,
                          '${usage.launchCount}',
                          l10n.usageCalendarAppOpens,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PanelValue(
                        icon: Icons.schedule_rounded,
                        child: _valueAndLabel(
                          context,
                          usage.launchCount == 0
                              ? '-'
                              : l10n.compactDuration(
                                  Duration(
                                    seconds:
                                        usage.durationSeconds ~/
                                        usage.launchCount,
                                  ),
                                ),
                          l10n.usageCalendarAverageSession,
                        ),
                      ),
                      // Always present, so the panel keeps its height.
                      const SizedBox(height: 12),
                      _PanelValue(
                        icon: Icons.insights_rounded,
                        child: UsageChangeLabel(
                          change: UsageTrendChange.compare(
                            currentSeconds: usage.durationSeconds,
                            previousSeconds: average,
                            previousWindowCovered: true,
                          ),
                          isGood: isGood,
                          caption: l10n.usageCalendarVsDailyAverage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.usageCalendarTimeline,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            UsageDayTimeline(
              day: day,
              intervals: intervals,
              emptyLabel: l10n.usageCalendarNoTimeline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueAndLabel(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PanelValue extends StatelessWidget {
  const _PanelValue({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricIcon(icon),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

/// A 24-hour strip with a mark for each stretch of use.
class UsageDayTimeline extends StatelessWidget {
  const UsageDayTimeline({
    required this.day,
    required this.intervals,
    this.emptyLabel,
    super.key,
  });

  final DateTime day;
  final List<AppUsageInterval> intervals;

  /// Shown inside the empty track, which keeps the strip's height.
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final hourFormat = MediaQuery.alwaysUse24HourFormatOf(context)
        ? DateFormat.H(locale)
        : DateFormat.j(locale);
    return Column(
      children: [
        SizedBox(
          height: 28,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey('usage-day-timeline'),
            painter: _TimelinePainter(
              day: day,
              intervals: intervals,
              trackColor: theme.colorScheme.surfaceContainerHigh,
              gridColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.35,
              ),
              markColor: theme.colorScheme.primary,
            ),
            child: intervals.isEmpty && emptyLabel != null
                ? Center(
                    child: Text(
                      emptyLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final hour in const [0, 6, 12, 18, 24])
              Text(
                hourFormat.format(DateTime(2000, 1, 1, hour % 24)),
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

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.day,
    required this.intervals,
    required this.trackColor,
    required this.gridColor,
    required this.markColor,
  });

  final DateTime day;
  final List<AppUsageInterval> intervals;
  final Color trackColor;
  final Color gridColor;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = trackColor,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final hour in const [6, 12, 18]) {
      final x = size.width * hour / 24;
      canvas.drawLine(Offset(x, 6), Offset(x, size.height - 6), grid);
    }
    final mark = Paint()..color = markColor;
    const daySeconds = 24 * 60 * 60;
    for (final interval in intervals) {
      final start = interval.startedAt.difference(day).inSeconds / daySeconds;
      final end = interval.endedAt.difference(day).inSeconds / daySeconds;
      // Keep short sessions visible as at least a thin mark.
      final width = math.max(4.0, (end - start) * size.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(start * size.width, 5, width, size.height - 10),
          const Radius.circular(3),
        ),
        mark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.intervals != intervals ||
      oldDelegate.day != day ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.markColor != markColor;
}
