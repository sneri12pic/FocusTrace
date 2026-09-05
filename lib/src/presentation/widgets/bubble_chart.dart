import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/usage_item.dart';
import '../../performance/dashboard_performance.dart';
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
    this.onLayoutComputed,
    super.key,
  });

  final List<UsageItem> items;
  final UsageItem? selectedItem;
  final Set<String> blockedItemIds;
  final Set<String> nearLimitItemIds;
  final ValueChanged<UsageItem> onItemSelected;
  final ValueChanged<UsageItem>? onItemLongPressed;
  final VoidCallback onSelectionDismissed;
  final VoidCallback? onLayoutComputed;

  static const double _minRadius = 26;
  static const double _maxRadius = 72;

  @override
  State<BubbleChart> createState() => _BubbleChartState();
}

class _BubbleChartState extends State<BubbleChart>
    with TickerProviderStateMixin {
  static const _tooltipLifetime = Duration(seconds: 4);
  static const _tooltipFadeDuration = Duration(milliseconds: 400);

  late final AnimationController _layoutController;
  late final AnimationController _pulseController;
  Timer? _fadeTimer;
  Timer? _clearTimer;
  bool _tooltipVisible = false;
  bool _firstFrameScheduled = false;
  bool _entrancePending = true;
  Size? _layoutSize;
  List<String> _layoutSignature = const <String>[];
  List<_BubbleGeometry> _fromGeometry = const <_BubbleGeometry>[];
  List<_BubbleGeometry> _toGeometry = const <_BubbleGeometry>[];

  @override
  void initState() {
    super.initState();
    _layoutController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1200),
          )
          ..addStatusListener(_handleLayoutStatus)
          ..forward();
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
    _layoutController.dispose();
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

  void _handleLayoutStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_entrancePending) {
      return;
    }
    _entrancePending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DashboardPerformance.entranceAnimationComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_firstFrameScheduled) {
            _firstFrameScheduled = true;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              DashboardPerformance.bubbleFrame(
                topKeys: widget.items.map((item) => item.id),
                realIconKeys: widget.items
                    .where((item) => item.iconBytes != null)
                    .map((item) => item.id),
              );
            }
          });
          _ensureLayout(widget.items, size);
          return AnimatedBuilder(
            animation: _layoutController,
            builder: (context, _) => _buildChart(size),
          );
        },
      ),
    );
  }

  Widget _buildChart(Size size) {
    final layout = _interpolatedLayout(widget.items);
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

  void _ensureLayout(List<UsageItem> items, Size size) {
    final signature = [
      for (final item in items) '${item.id}\u0000${item.totalDurationSeconds}',
    ];
    if (_layoutSize == size && _sameSignature(_layoutSignature, signature)) {
      return;
    }

    final target = _calculateGeometry(items, size, steps: packSteps);
    widget.onLayoutComputed?.call();
    if (_layoutSize == null) {
      _fromGeometry = _calculateGeometry(items, size, steps: 0);
      _toGeometry = target;
    } else {
      final currentById = {
        for (final geometry in _interpolatedGeometry()) geometry.id: geometry,
      };
      final entranceById = {
        for (final geometry in _calculateGeometry(items, size, steps: 0))
          geometry.id: geometry,
      };
      _fromGeometry = [
        for (final geometry in target)
          currentById[geometry.id] ?? entranceById[geometry.id]!,
      ];
      _toGeometry = target;

      if (_entrancePending && _layoutController.isAnimating) {
        final currentDuration = _layoutController.duration!;
        final remainingUs = math.max(
          1,
          (currentDuration.inMicroseconds * (1 - _layoutController.value))
              .round(),
        );
        _layoutController.duration = Duration(microseconds: remainingUs);
      } else {
        _layoutController.duration = const Duration(milliseconds: 300);
      }
      _layoutController.forward(from: 0);
    }
    _layoutSize = size;
    _layoutSignature = signature;
  }

  List<_BubbleLayout> _interpolatedLayout(List<UsageItem> items) {
    final itemsById = {for (final item in items) item.id: item};
    return [
      for (final geometry in _interpolatedGeometry())
        if (itemsById[geometry.id] case final item?)
          _BubbleLayout(
            item: item,
            radius: geometry.radius,
            center: geometry.center,
          ),
    ];
  }

  List<_BubbleGeometry> _interpolatedGeometry() {
    if (_toGeometry.isEmpty) {
      return const <_BubbleGeometry>[];
    }
    final fromById = {
      for (final geometry in _fromGeometry) geometry.id: geometry,
    };
    final progress = Curves.easeOutCubic.transform(_layoutController.value);
    return [
      for (final target in _toGeometry)
        _BubbleGeometry(
          id: target.id,
          radius:
              (fromById[target.id]?.radius ?? target.radius) +
              (target.radius - (fromById[target.id]?.radius ?? target.radius)) *
                  progress,
          center: Offset.lerp(
            fromById[target.id]?.center ?? target.center,
            target.center,
            progress,
          )!,
        ),
    ];
  }

  List<_BubbleGeometry> _calculateGeometry(
    List<UsageItem> items,
    Size size, {
    required int steps,
  }) {
    if (items.isEmpty) {
      return const <_BubbleGeometry>[];
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
        _BubbleGeometry(
          id: items[index].id,
          radius: radii[index],
          center: centers[index],
        ),
    ];
  }

  bool _sameSignature(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }

  double _radiusFor(UsageItem item, double maxSeconds, double maxRadius) {
    if (maxSeconds <= 0) {
      return BubbleChart._minRadius;
    }
    final normalized = item.totalDurationSeconds / maxSeconds;
    return BubbleChart._minRadius +
        normalized * (maxRadius - BubbleChart._minRadius);
  }

  double _tooltipTop(_BubbleLayout layout, double height) {
    final below = layout.center.dy + layout.radius + 10;
    if (below + 120 <= height) {
      return below;
    }
    return math.max(8, layout.center.dy - layout.radius - 124);
  }
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

class _BubbleGeometry {
  const _BubbleGeometry({
    required this.id,
    required this.radius,
    required this.center,
  });

  final String id;
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

/// Total relaxation steps of the packing simulation. The chart computes the
/// zero-step entrance positions and the fully packed positions once, then
/// interpolates between those cached geometries during animation frames.
const int packSteps = 150;

/// Iterative circle packing: every bubble is pulled toward the center while
/// colliding pairs push apart, with the displacement split by mass (radius²),
/// so the heaviest bubbles claim the middle and light ones get pushed out.
/// Deterministic — same radii always produce the same layout.
List<Offset> packBubbles(
  List<double> radii,
  Size size, {
  int steps = packSteps,
}) {
  final center = Offset(size.width / 2, size.height / 2 + 10);
  // Seed scattered around the chart edges (deterministic golden-angle fan) so
  // playing the simulation forward shows the bubbles flying in from the edges
  // and colliding until they settle.
  final farOut = size.width + size.height;
  final positions = [
    for (var i = 0; i < radii.length; i++)
      _clampToBounds(
        center + Offset.fromDirection(i * _goldenAngle, farOut),
        radii[i],
        size,
      ),
  ];

  final maxRadius = radii.reduce(math.max);

  // ponytail: fixed 150 relaxation steps for <=10 bubbles; converges long before that.
  for (var step = 0; step < steps; step++) {
    // Gravity fades out so late steps purely resolve collisions, and it is
    // mass-weighted so heavy bubbles pull to the center harder than light ones.
    final gravity = 0.04 * (1 - step / packSteps);
    for (var i = 0; i < positions.length; i++) {
      final weight = (radii[i] * radii[i]) / (maxRadius * maxRadius);
      positions[i] +=
          (center - positions[i]) * (gravity * (0.2 + 0.8 * weight));
    }
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        var delta = positions[j] - positions[i];
        var distance = delta.distance;
        final minDistance = radii[i] + radii[j] + 4;
        if (distance >= minDistance) {
          continue;
        }
        if (distance < 0.01) {
          delta = Offset.fromDirection(j * _goldenAngle, 0.01);
          distance = 0.01;
        }
        final direction = delta / distance;
        final overlap = minDistance - distance;
        final massI = radii[i] * radii[i];
        final massJ = radii[j] * radii[j];
        positions[i] -= direction * (overlap * massJ / (massI + massJ));
        positions[j] += direction * (overlap * massI / (massI + massJ));
      }
    }
    for (var i = 0; i < positions.length; i++) {
      positions[i] = _clampToBounds(positions[i], radii[i], size);
    }
  }
  return positions;
}

Offset _clampToBounds(Offset position, double radius, Size size) {
  return Offset(
    _clamp(position.dx, radius, size.width - radius),
    _clamp(position.dy, radius, size.height - radius),
  );
}
