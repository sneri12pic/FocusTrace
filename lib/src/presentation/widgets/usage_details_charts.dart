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
    super.key,
  });

  final List<DailyUsagePoint> points;
  final UsageDetailsPeriod period;
  final UsageDetailsChart chart;
  final ValueChanged<UsageDetailsChart> onChartChanged;

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
    return Column(
      children: [
        SizedBox(
          height: 218,
          child: PageView(
            key: const ValueKey('usage-chart-pages'),
            controller: _controller,
            onPageChanged: (index) =>
                widget.onChartChanged(UsageDetailsChart.values[index]),
            children: [
              _UsageBarChart(points: widget.points, period: widget.period),
              _UsageAreaChart(points: widget.points, period: widget.period),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final chart in UsageDetailsChart.values)
              Semantics(
                selected: chart == widget.chart,
                child: IconButton(
                  key: ValueKey('usage-chart-dot-${chart.name}'),
                  tooltip: chart == UsageDetailsChart.bars
                      ? context.l10n.usageDetailsBarChart
                      : context.l10n.usageDetailsAreaChart,
                  onPressed: () => _showChart(chart),
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary.withValues(
                        alpha: chart == widget.chart ? 1 : 0.3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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
  const _UsageBarChart({required this.points, required this.period});

  static const _maxBarHeight = 120.0;

  final List<DailyUsagePoint> points;
  final UsageDetailsPeriod period;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = _maximum(points);
    return Card(
      key: const ValueKey('usage-bar-chart'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth =
                constraints.maxWidth / math.max(1, points.length);
            final labelStep = math.max(1, (44 / columnWidth).ceil());
            // Both charts fit the selected period, leaving horizontal gestures
            // to the pager instead of a competing nested horizontal scroller.
            return CustomPaint(
              key: const ValueKey('usage-trend-line'),
              foregroundPainter: _UsageTrendLinePainter(
                points: points,
                maxSeconds: maxSeconds,
                increaseColor: trendColor(
                  Theme.of(context),
                  isFlat: false,
                  isIncrease: true,
                ),
                decreaseColor: trendColor(
                  Theme.of(context),
                  isFlat: false,
                  isIncrease: false,
                ),
                flatColor: trendColor(
                  Theme.of(context),
                  isFlat: true,
                  isIncrease: false,
                ),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: math.min(20, columnWidth * 0.65),
                                height: _barHeight(
                                  points[index].durationSeconds,
                                  maxSeconds,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              SizedBox(
                                height: 16,
                                child: OverflowBox(
                                  maxWidth: math.max(44, columnWidth),
                                  child: index % labelStep == 0
                                      ? Text(
                                          _dateLabel(
                                            context,
                                            points[index],
                                            period,
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
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
        ..strokeWidth = 3
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
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      key: const ValueKey('usage-area-chart'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.l10n.compactDuration(Duration(seconds: maxSeconds)),
                style: Theme.of(context).textTheme.labelSmall,
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
                      style: Theme.of(context).textTheme.labelSmall,
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
        ..strokeWidth = 3
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
