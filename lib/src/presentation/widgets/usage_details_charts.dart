import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/usage_details_chart.dart';
import '../localization/app_localizations_x.dart';
import '../view_models/app_usage_details_view_model.dart';
import 'trend_color.dart';

class UsageDetailsCharts extends StatefulWidget {
  const UsageDetailsCharts({
    required this.points,
    required this.period,
    required this.chart,
    required this.onChartChanged,
    this.isGood = false,
    this.selector,
    this.total,
    super.key,
  });

  final List<DailyUsagePoint> points;
  final UsageDetailsPeriod period;
  final UsageDetailsChart chart;
  final ValueChanged<UsageDetailsChart> onChartChanged;

  /// Productivity apps: more use is good, so increases are green.
  final bool isGood;

  /// The range selector, shown at the top left of the card.
  final Widget? selector;

  /// The range total, shown under the selector.
  final Widget? total;

  @override
  State<UsageDetailsCharts> createState() => _UsageDetailsChartsState();
}

class _UsageDetailsChartsState extends State<UsageDetailsCharts> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.chart.index,
      keepPage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showChart(UsageDetailsChart chart) {
    _controller.animateToPage(
      chart.index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selector = widget.selector;
    final total = widget.total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The page dots share the selector's row, top right, so they
            // never overlap the chart and need no space of their own.
            Row(
              children: [
                if (selector != null) selector,
                const Spacer(),
                for (final chart in UsageDetailsChart.values)
                  _PageDot(
                    chart: chart,
                    selected: chart == widget.chart,
                    onTap: () => _showChart(chart),
                  ),
              ],
            ),
            if (total != null) ...[const SizedBox(height: 8), total],
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: PageView(
                key: const ValueKey('usage-chart-pages'),
                controller: _controller,
                onPageChanged: (index) =>
                    widget.onChartChanged(UsageDetailsChart.values[index]),
                children: [
                  _UsageBarChart(
                    points: widget.points,
                    period: widget.period,
                    isGood: widget.isGood,
                  ),
                  _UsageAreaChart(points: widget.points, period: widget.period),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact page indicator: the active chart is a short blue pill.
class _PageDot extends StatelessWidget {
  const _PageDot({
    required this.chart,
    required this.selected,
    required this.onTap,
  });

  final UsageDetailsChart chart;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: chart == UsageDetailsChart.bars
            ? context.l10n.usageDetailsBarChart
            : context.l10n.usageDetailsAreaChart,
        child: InkWell(
          key: ValueKey('usage-chart-dot-${chart.name}'),
          onTap: onTap,
          customBorder: const StadiumBorder(),
          // A 32px target around a 6px mark keeps the dots tappable.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: selected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: selected ? 1 : 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _dateLabel(
  BuildContext context,
  DailyUsagePoint point,
  UsageDetailsPeriod period,
) {
  final locale = Localizations.localeOf(context).toString();
  return switch (period) {
    UsageDetailsPeriod.year => DateFormat.MMM(locale).format(point.day),
    UsageDetailsPeriod.sevenDays => DateFormat.E(locale).format(point.day),
    // Month names keep 30-day labels unambiguous across a month change.
    UsageDetailsPeriod.month => DateFormat.MMMd(locale).format(point.day),
    _ => DateFormat.Md(locale).format(point.day),
  };
}

String _pointLabel(
  BuildContext context,
  DailyUsagePoint point,
  UsageDetailsPeriod period,
) {
  final locale = Localizations.localeOf(context).toString();
  final date = period == UsageDetailsPeriod.year
      ? DateFormat.yMMM(locale).format(point.day)
      : DateFormat.yMMMd(locale).format(point.day);
  return context.l10n.usageDetailsDayValue(
    date,
    context.l10n.compactDuration(point.duration),
  );
}

int _maximum(List<DailyUsagePoint> points) => points.fold<int>(
  0,
  (maximum, point) => math.max(maximum, point.durationSeconds),
);

class _UsageBarChart extends StatelessWidget {
  const _UsageBarChart({
    required this.points,
    required this.period,
    required this.isGood,
  });

  static const _maxBarHeight = 120.0;

  final List<DailyUsagePoint> points;
  final UsageDetailsPeriod period;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = _maximum(points);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return KeyedSubtree(
      key: const ValueKey('usage-bar-chart'),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth =
                constraints.maxWidth / math.max(1, points.length);
            final isMonth = period == UsageDetailsPeriod.month;
            // A month gets one label per week, counted back from the
            // selected day so the latest bar is always labelled.
            final labelStep = isMonth
                ? 7
                : math.max(1, (44 / columnWidth).ceil());
            final labelWidth = isMonth ? 56.0 : 44.0;
            // Both charts fit the selected period, leaving horizontal gestures
            // to the pager instead of a competing nested horizontal scroller.
            return CustomPaint(
              key: const ValueKey('usage-trend-line'),
              // Thirty thin columns carry no readable trend line.
              foregroundPainter: isMonth
                  ? null
                  : _UsageTrendLinePainter(
                      points: points,
                      maxSeconds: maxSeconds,
                      // A thinner, softened line keeps the bars primary.
                      increaseColor: trendColor(
                        theme,
                        isFlat: false,
                        isIncrease: !isGood,
                      ).withValues(alpha: 0.75),
                      decreaseColor: trendColor(
                        theme,
                        isFlat: false,
                        isIncrease: isGood,
                      ).withValues(alpha: 0.75),
                      flatColor: trendColor(
                        theme,
                        isFlat: true,
                        isIncrease: false,
                      ).withValues(alpha: 0.75),
                    ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < points.length; index++)
                    Expanded(
                      child: Semantics(
                        label: _pointLabel(context, points[index], period),
                        excludeSemantics: true,
                        child: Tooltip(
                          message: _pointLabel(context, points[index], period),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (points[index].durationSeconds > 0 &&
                                  columnWidth >= 32)
                                FittedBox(
                                  child: Text(
                                    context.l10n.compactDuration(
                                      points[index].duration,
                                    ),
                                    style: labelStyle,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: math.min(18, columnWidth * 0.55),
                                height: _barHeight(
                                  points[index].durationSeconds,
                                  maxSeconds,
                                ),
                                decoration: BoxDecoration(
                                  // The selected day (last bar) leads; the
                                  // rest stay readable but recede.
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: index == points.length - 1 ? 1 : 0.8,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                    bottom: Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              SizedBox(
                                height: 16,
                                child: OverflowBox(
                                  maxWidth: math.max(labelWidth, columnWidth),
                                  // Edge labels grow inward so the card
                                  // never clips them.
                                  alignment: index < labelStep ~/ 2
                                      ? Alignment.centerLeft
                                      : index == points.length - 1 &&
                                            columnWidth < labelWidth
                                      ? Alignment.centerRight
                                      : Alignment.center,
                                  child:
                                      (points.length - 1 - index) % labelStep ==
                                          0
                                      ? Text(
                                          _dateLabel(
                                            context,
                                            points[index],
                                            period,
                                          ),
                                          style: labelStyle,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static double _barHeight(int seconds, int maxSeconds) {
    if (maxSeconds == 0) return 4;
    return (seconds / maxSeconds * _maxBarHeight)
        .clamp(4, _maxBarHeight)
        .toDouble();
  }
}

/// Horizontal tangents join neighboring values smoothly without overshooting
/// their range, which would imply usage above/below the actual observations.
Path _smoothSegment(Offset start, Offset end) {
  final middleX = (start.dx + end.dx) / 2;
  return Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(middleX, start.dy, middleX, end.dy, end.dx, end.dy);
}

class _UsageTrendLinePainter extends CustomPainter {
  const _UsageTrendLinePainter({
    required this.points,
    required this.maxSeconds,
    required this.increaseColor,
    required this.decreaseColor,
    required this.flatColor,
  });

  final List<DailyUsagePoint> points;
  final int maxSeconds;
  final Color increaseColor;
  final Color decreaseColor;
  final Color flatColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final columnWidth = size.width / points.length;
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index].durationSeconds;
      final next = points[index + 1].durationSeconds;
      final paint = Paint()
        ..color = next == current
            ? flatColor
            : next > current
            ? increaseColor
            : decreaseColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        _smoothSegment(
          Offset(
            columnWidth * (index + 0.5),
            size.height - 23 - _UsageBarChart._barHeight(current, maxSeconds),
          ),
          Offset(
            columnWidth * (index + 1.5),
            size.height - 23 - _UsageBarChart._barHeight(next, maxSeconds),
          ),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UsageTrendLinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maxSeconds != maxSeconds ||
      oldDelegate.increaseColor != increaseColor ||
      oldDelegate.decreaseColor != decreaseColor ||
      oldDelegate.flatColor != flatColor;
}

class _UsageAreaChart extends StatelessWidget {
  const _UsageAreaChart({required this.points, required this.period});

  final List<DailyUsagePoint> points;
  final UsageDetailsPeriod period;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = _maximum(points);
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return KeyedSubtree(
      key: const ValueKey('usage-area-chart'),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.l10n.compactDuration(Duration(seconds: maxSeconds)),
                style: labelStyle,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CustomPaint(
                painter: _UsageAreaPainter(points: points, color: color),
                child: Row(
                  children: [
                    for (final point in points)
                      Expanded(
                        child: Semantics(
                          label: _pointLabel(context, point, period),
                          child: Tooltip(
                            message: _pointLabel(context, point, period),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final index in <int>{
                    if (points.isNotEmpty) 0,
                    if (points.length > 2) points.length ~/ 2,
                    if (points.length > 1) points.length - 1,
                  })
                    Text(
                      _dateLabel(context, points[index], period),
                      style: labelStyle,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageAreaPainter extends CustomPainter {
  const _UsageAreaPainter({required this.points, required this.color});

  final List<DailyUsagePoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 3;
    final grid = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      canvas.drawLine(
        Offset(0, baseline * fraction),
        Offset(size.width, baseline * fraction),
        grid,
      );
    }
    if (points.isEmpty) return;
    final maxSeconds = math.max(1, _maximum(points));
    final columnWidth = size.width / points.length;
    final positions = [
      for (var index = 0; index < points.length; index++)
        Offset(
          columnWidth * (index + 0.5),
          baseline -
              points[index].durationSeconds / maxSeconds * (baseline - 3),
        ),
    ];
    final line = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (var index = 1; index < positions.length; index++) {
      line.extendWithPath(
        _smoothSegment(positions[index - 1], positions[index]),
        Offset.zero,
      );
    }
    final area = Path.from(line)
      ..lineTo(positions.last.dx, baseline)
      ..lineTo(positions.first.dx, baseline)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.03),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (final position in positions) {
      canvas.drawCircle(position, 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _UsageAreaPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
