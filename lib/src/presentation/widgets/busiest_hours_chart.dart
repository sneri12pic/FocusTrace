import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations_x.dart';
import 'usage_details_charts.dart';

const _chartHeight = 104.0;

/// Hourly usage as swipeable bars and curve, the three hours from [peak]
/// highlighted. Hours are drawn in equal columns, so one label row fits both.
class BusiestHoursChart extends StatefulWidget {
  const BusiestHoursChart({
    required this.hours,
    required this.peak,
    required this.hourLabel,
    required this.header,
    super.key,
  });

  final List<int> hours;
  final int peak;
  final String Function(int hour) hourLabel;

  /// Shown at the top left; the page dots share its row.
  final Widget header;

  @override
  State<BusiestHoursChart> createState() => _BusiestHoursChartState();
}

class _BusiestHoursChartState extends State<BusiestHoursChart> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  String _hourValue(int hour) =>
      '${widget.hourLabel(hour)}: ${context.l10n.compactDuration(Duration(seconds: widget.hours[hour]))}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: widget.header),
            for (final (page, label) in [
              l.usageDetailsBarChart,
              l.usageDetailsAreaChart,
            ].indexed)
              ChartPageDot(
                inkKey: ValueKey('busiest-chart-dot-$page'),
                label: label,
                selected: page == _page,
                onTap: () => _showPage(page),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SizedBox(
            height: _chartHeight,
            child: PageView(
              key: const ValueKey('busiest-chart-pages'),
              controller: _controller,
              onPageChanged: (page) => setState(() => _page = page),
              children: [
                _BusiestBars(
                  hours: widget.hours,
                  peak: widget.peak,
                  hourValue: _hourValue,
                ),
                CustomPaint(
                  painter: _BusiestCurvePainter(
                    hours: widget.hours,
                    peak: widget.peak,
                    color: theme.colorScheme.primary,
                  ),
                  child: Row(
                    children: [
                      for (var hour = 0; hour < 24; hour++)
                        Expanded(
                          child: Tooltip(
                            message: _hourValue(hour),
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // A label every six hours, centred under its own column.
        Row(
          children: [
            for (var hour = 0; hour < 24; hour++)
              Expanded(
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(16),
                  child: hour % 6 == 0
                      ? OverflowBox(
                          maxWidth: 56,
                          alignment: hour == 0
                              ? AlignmentDirectional.centerStart
                              : Alignment.center,
                          child: Text(
                            widget.hourLabel(hour),
                            maxLines: 1,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BusiestBars extends StatelessWidget {
  const _BusiestBars({
    required this.hours,
    required this.peak,
    required this.hourValue,
  });

  final List<int> hours;
  final int peak;
  final String Function(int hour) hourValue;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final maximum = math.max(1, hours.fold(0, math.max));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var hour = 0; hour < 24; hour++)
          Expanded(
            child: Tooltip(
              message: hourValue(hour),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Column by column, so a window across midnight just works.
                  ColoredBox(
                    color: _inWindow(hour, peak) ? primary : Colors.transparent,
                    child: const SizedBox(height: 2),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: hours[hour] == 0
                        ? const SizedBox.expand()
                        : FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            // A floor keeps a minute of use visible.
                            heightFactor: math.max(0.04, hours[hour] / maximum),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  color: _inWindow(hour, peak)
                                      ? primary
                                      : primary.withValues(alpha: 0.32),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

bool _inWindow(int hour, int peak) => (hour - peak + 24) % 24 < 3;

class _BusiestCurvePainter extends CustomPainter {
  const _BusiestCurvePainter({
    required this.hours,
    required this.peak,
    required this.color,
  });

  final List<int> hours;
  final int peak;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final column = size.width / 24;
    final maximum = math.max(1, hours.fold(0, math.max));
    double y(int hour) =>
        size.height - hours[hour] / maximum * (size.height - 10);
    final positions = [
      Offset(0, y(0)),
      for (var hour = 0; hour < 24; hour++)
        Offset(column * (hour + 0.5), y(hour)),
      Offset(size.width, y(23)),
    ];
    final line = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (var index = 1; index < positions.length; index++) {
      line.extendWithPath(
        smoothChartSegment(positions[index - 1], positions[index]),
        Offset.zero,
      );
    }

    // A window across midnight is two bands, one at each end.
    final end = peak + 3;
    final window = Path();
    for (final (from, to) in [
      (peak, math.min(end, 24)),
      if (end > 24) (0, end - 24),
    ]) {
      window.addRRect(
        RRect.fromLTRBR(
          from * column,
          0,
          to * column,
          size.height,
          const Radius.circular(8),
        ),
      );
    }
    canvas.drawPath(window, Paint()..color = color.withValues(alpha: 0.12));

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
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
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      line,
      stroke
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );
    canvas.save();
    canvas.clipPath(window);
    canvas.drawPath(
      line,
      stroke
        ..color = color
        ..strokeWidth = 2.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BusiestCurvePainter oldDelegate) =>
      oldDelegate.hours != hours ||
      oldDelegate.peak != peak ||
      oldDelegate.color != color;
}
