import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/usage_item.dart';
import 'bubble_tooltip.dart';
import 'usage_bubble.dart';

class BubbleChart extends StatefulWidget {
  const BubbleChart({
    required this.items,
    required this.selectedItem,
    required this.blockedItemIds,
    required this.nearLimitItemIds,
    required this.onItemSelected,
    this.onItemLongPressed,
    required this.onSelectionDismissed,
    super.key,
  });

  final List<UsageItem> items;
  final UsageItem? selectedItem;
  final Set<String> blockedItemIds;
  final Set<String> nearLimitItemIds;
  final ValueChanged<UsageItem> onItemSelected;
  final ValueChanged<UsageItem>? onItemLongPressed;
  final VoidCallback onSelectionDismissed;

  static const double _minRadius = 20;
  static const double _maxRadius = 72;

  @override
  State<BubbleChart> createState() => _BubbleChartState();
}

class _BubbleChartState extends State<BubbleChart>
    with TickerProviderStateMixin {
  static const _tooltipLifetime = Duration(seconds: 4);
  static const _tooltipFadeDuration = Duration(milliseconds: 400);

  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  Timer? _fadeTimer;
  Timer? _clearTimer;
  bool _tooltipVisible = false;

  @override
  void initState() {
    super.initState();
    // Interpolates from the chart edges into the packed layout on mount. The
    // chart section unmounts during refresh, so each refresh replays it.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    if (widget.selectedItem != null) {
      _tooltipVisible = true;
      _fadeTimer = Timer(_tooltipLifetime, _fadeOutTooltip);
    }
  }

  @override
  void didUpdateWidget(covariant BubbleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItem?.id == oldWidget.selectedItem?.id) {
      return;
    }
    _cancelTimers();
    _tooltipVisible = widget.selectedItem != null;
    if (_tooltipVisible) {
      _fadeTimer = Timer(_tooltipLifetime, _fadeOutTooltip);
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _fadeTimer?.cancel();
    _clearTimer?.cancel();
  }

  void _fadeOutTooltip() {
    setState(() => _tooltipVisible = false);
    _clearTimer = Timer(_tooltipFadeDuration, widget.onSelectionDismissed);
  }

  void _handleBubbleTap(UsageItem item) {
    if (item.id == widget.selectedItem?.id) {
      widget.onSelectionDismissed();
    } else {
      widget.onItemSelected(item);
    }
  }

  void _handleBackgroundTap() {
    if (widget.selectedItem != null) {
      widget.onSelectionDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _entranceController,
            builder: (context, _) => _buildChart(size),
          );
        },
      ),
    );
  }

  Widget _buildChart(Size size) {
    // Each frame moves the bubbles from the edges toward their tangent pockets.
    final steps = (_entranceController.value * packSteps).ceil();
    final layout = _layoutItems(widget.items, size, steps);
    final selectedLayout = layout.cast<_BubbleLayout?>().firstWhere(
      (bubble) => bubble?.item.id == widget.selectedItem?.id,
      orElse: () => null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleBackgroundTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _PulsingGlow(listenable: _pulseController)),
          Positioned.fill(child: CustomPaint(painter: _ScaleRingPainter())),
          for (final bubble in layout)
            Positioned(
              left: bubble.center.dx - bubble.radius,
              top: bubble.center.dy - bubble.radius,
              child: UsageBubble(
                item: bubble.item,
                radius: bubble.radius,
                isSelected: bubble.item.id == widget.selectedItem?.id,
                isBlocked: widget.blockedItemIds.contains(bubble.item.id),
                isNearLimit: widget.nearLimitItemIds.contains(bubble.item.id),
                warningAnimation: _pulseController,
                onTap: () => _handleBubbleTap(bubble.item),
                onLongPress: widget.onItemLongPressed == null
                    ? null
                    : () => widget.onItemLongPressed!(bubble.item),
              ),
            ),
          if (selectedLayout != null)
            Positioned(
              left: _clamp(selectedLayout.center.dx - 82, 8, size.width - 172),
              top: _tooltipTop(selectedLayout, size.height),
              width: 164,
              child: AnimatedOpacity(
                opacity: _tooltipVisible ? 1 : 0,
                duration: _tooltipFadeDuration,
                child: BubbleTooltip(item: selectedLayout.item),
              ),
            ),
        ],
      ),
    );
  }

  List<_BubbleLayout> _layoutItems(
    List<UsageItem> items,
    Size size,
    int steps,
  ) {
    if (items.isEmpty) {
      return const <_BubbleLayout>[];
    }

    final maxSeconds = items
        .map((item) => item.totalDurationSeconds)
        .reduce(math.max)
        .toDouble();
    final minDimension = math.min(size.width, size.height);
    final maxRadius = math.min(BubbleChart._maxRadius, minDimension * 0.2);
    final radii = [
      for (final item in items) _radiusFor(item, maxSeconds, maxRadius),
    ];
    final centers = packBubbles(radii, size, steps: steps);

    return [
      for (var index = 0; index < items.length; index++)
        _BubbleLayout(
          item: items[index],
          radius: radii[index],
          center: centers[index],
        ),
    ];
  }

  double _radiusFor(UsageItem item, double maxSeconds, double maxRadius) {
    return bubbleRadiusForUsage(
      durationSeconds: item.totalDurationSeconds,
      maxDurationSeconds: maxSeconds,
      minRadius: BubbleChart._minRadius,
      maxRadius: maxRadius,
    );
  }

  double _tooltipTop(_BubbleLayout layout, double height) {
    final below = layout.center.dy + layout.radius + 10;
    if (below + 120 <= height) {
      return below;
    }
    return math.max(8, layout.center.dy - layout.radius - 124);
  }
}

/// Converts usage to radius with extra contrast between light and heavy use.
/// The 1.25 power counteracts the visual compression caused by a non-zero
/// minimum radius while keeping every app large enough to tap.
double bubbleRadiusForUsage({
  required num durationSeconds,
  required num maxDurationSeconds,
  required double minRadius,
  required double maxRadius,
}) {
  if (maxDurationSeconds <= 0 || maxRadius <= minRadius) {
    return minRadius;
  }
  final normalized = (durationSeconds / maxDurationSeconds).clamp(0, 1);
  final emphasized = math.pow(normalized, 1.25).toDouble();
  return minRadius + emphasized * (maxRadius - minRadius);
}

class _BubbleLayout {
  const _BubbleLayout({
    required this.item,
    required this.radius,
    required this.center,
  });

  final UsageItem item;
  final double radius;
  final Offset center;
}

/// A soft radial glow behind the bubbles that slowly "breathes" in sync with
/// the chart's pulse controller. Kept at very low opacity so it stays calm.
class _PulsingGlow extends StatelessWidget {
  const _PulsingGlow({required this.listenable});

  final Animation<double> listenable;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final pulse = Curves.easeInOut.transform(listenable.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.06),
                radius: 0.72 + 0.12 * pulse,
                colors: [
                  const Color(
                    0xFF5BC0EB,
                  ).withValues(alpha: 0.04 + 0.05 * pulse),
                  Colors.transparent,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScaleRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final maxRadius = math.min(size.width, size.height) * 0.48;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);

    for (final factor in const [0.36, 0.62, 0.88]) {
      canvas.drawCircle(center, maxRadius * factor, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double _clamp(double value, double min, double max) {
  return value.clamp(min, math.max(min, max)).toDouble();
}

const double _goldenAngle = 2.399963;
const double _bubbleGap = 4;
const int _candidateAngles = 72;

/// Number of frames used to interpolate from the edge into the packed layout.
const int packSteps = 150;

/// Greedy tangent-pocket packing. Radii are expected largest-first: the first
/// stays central and every later bubble chooses the closest valid gap touching
/// one or, preferably, two already placed circles.
List<Offset> packBubbles(
  List<double> radii,
  Size size, {
  int steps = packSteps,
}) {
  if (radii.isEmpty) {
    return const [];
  }
  final packed = _packIntoPockets(radii, size);
  if (steps >= packSteps) {
    return packed;
  }

  final center = Offset(size.width / 2, size.height / 2 + 10);
  final farOut = size.width + size.height;
  final initial = [
    for (var i = 0; i < radii.length; i++)
      _clampToBounds(
        center + Offset.fromDirection(i * _goldenAngle, farOut),
        radii[i],
        size,
      ),
  ];
  final progress = (steps / packSteps).clamp(0.0, 1.0);
  final eased = 1 - math.pow(1 - progress, 3).toDouble();
  return [
    for (var index = 0; index < radii.length; index++)
      Offset.lerp(initial[index], packed[index], eased)!,
  ];
}

List<Offset> _packIntoPockets(List<double> radii, Size size) {
  final center = Offset(size.width / 2, size.height / 2 + 10);
  final positions = <Offset>[center];

  for (var index = 1; index < radii.length; index++) {
    final radius = radii[index];
    final candidates = <Offset>[];

    // Exact circle intersections are the pockets tangent to two neighbours.
    for (var first = 0; first < positions.length; first++) {
      for (var second = first + 1; second < positions.length; second++) {
        candidates.addAll(
          _tangentIntersections(
            positions[first],
            radii[first] + radius + _bubbleGap,
            positions[second],
            radii[second] + radius + _bubbleGap,
          ),
        );
      }
    }

    // Circumference samples cover edge gaps and one-neighbour placements.
    final startAngle = -math.pi / 2 + (index - 1) * _goldenAngle;
    for (var placedIndex = 0; placedIndex < positions.length; placedIndex++) {
      final tangentDistance = radii[placedIndex] + radius + _bubbleGap;
      for (var sample = 0; sample < _candidateAngles; sample++) {
        final angle = startAngle + 2 * math.pi * sample / _candidateAngles;
        candidates.add(
          positions[placedIndex] + Offset.fromDirection(angle, tangentDistance),
        );
      }
    }

    final valid = candidates.where(
      (candidate) =>
          _isValidPosition(candidate, radius, positions, radii, size),
    );
    positions.add(
      _bestPocket(valid, radius, positions, radii, center) ??
          _firstOpenRingPosition(index, radius, positions, radii, center, size),
    );
  }
  return positions;
}

Offset? _bestPocket(
  Iterable<Offset> candidates,
  double radius,
  List<Offset> positions,
  List<double> radii,
  Offset center,
) {
  Offset? best;
  var bestTouches = -1;
  var bestDistanceSquared = double.infinity;
  for (final candidate in candidates) {
    var touches = 0;
    for (var index = 0; index < positions.length; index++) {
      final tangentDistance = radius + radii[index] + _bubbleGap;
      if (((candidate - positions[index]).distance - tangentDistance).abs() <
          0.75) {
        touches++;
      }
    }
    final delta = candidate - center;
    final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    if (touches > bestTouches ||
        (touches == bestTouches && distanceSquared < bestDistanceSquared)) {
      best = candidate;
      bestTouches = touches;
      bestDistanceSquared = distanceSquared;
    }
  }
  return best;
}

Offset _firstOpenRingPosition(
  int index,
  double radius,
  List<Offset> positions,
  List<double> radii,
  Offset center,
  Size size,
) {
  final ringStep = math.max(2.0, radius * 0.25);
  for (
    var ring = ringStep;
    ring <= size.width + size.height;
    ring += ringStep
  ) {
    for (var sample = 0; sample < _candidateAngles * 2; sample++) {
      final angle =
          index * _goldenAngle + 2 * math.pi * sample / (_candidateAngles * 2);
      final candidate = center + Offset.fromDirection(angle, ring);
      if (_isValidPosition(candidate, radius, positions, radii, size)) {
        return candidate;
      }
    }
  }

  // Only reachable if a host constrains the chart below its minimum size.
  return _clampToBounds(center, radius, size);
}

bool _isValidPosition(
  Offset candidate,
  double radius,
  List<Offset> positions,
  List<double> radii,
  Size size,
) {
  if (candidate.dx < radius ||
      candidate.dx > size.width - radius ||
      candidate.dy < radius ||
      candidate.dy > size.height - radius) {
    return false;
  }
  for (var index = 0; index < positions.length; index++) {
    if ((candidate - positions[index]).distance <
        radius + radii[index] + _bubbleGap - 0.25) {
      return false;
    }
  }
  return true;
}

List<Offset> _tangentIntersections(
  Offset first,
  double firstDistance,
  Offset second,
  double secondDistance,
) {
  final delta = second - first;
  final distance = delta.distance;
  if (distance < 0.001 ||
      distance > firstDistance + secondDistance ||
      distance < (firstDistance - secondDistance).abs()) {
    return const [];
  }
  final along =
      (firstDistance * firstDistance -
          secondDistance * secondDistance +
          distance * distance) /
      (2 * distance);
  final heightSquared = firstDistance * firstDistance - along * along;
  if (heightSquared < -0.01) {
    return const [];
  }
  final perpendicular = math.sqrt(math.max(0, heightSquared));
  final direction = delta / distance;
  final middle = first + direction * along;
  final normal = Offset(-direction.dy, direction.dx) * perpendicular;
  return [middle + normal, middle - normal];
}

Offset _clampToBounds(Offset position, double radius, Size size) {
  return Offset(
    _clamp(position.dx, radius, size.width - radius),
    _clamp(position.dy, radius, size.height - radius),
  );
}
