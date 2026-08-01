import 'package:flutter/material.dart';

import '../../domain/models/usage_item.dart';
import '../localization/app_localizations_x.dart';

class UsageBubble extends StatelessWidget {
  const UsageBubble({
    required this.item,
    required this.radius,
    required this.isSelected,
    required this.isBlocked,
    required this.isNearLimit,
    required this.warningAnimation,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final UsageItem item;
  final double radius;
  final bool isSelected;
  final bool isBlocked;
  final bool isNearLimit;
  final Animation<double> warningAnimation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final colors = _colorsFor(item.name);
    final category = context.l10n.usageCategoryLabel(item.category);

    return Semantics(
      button: true,
      label: isNearLimit
          ? context.l10n.usageBubbleNearLimitSemanticsLabel(item.name, category)
          : context.l10n.usageBubbleSemanticsLabel(item.name, category),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedScale(
          scale: isSelected ? 1.08 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedBuilder(
            animation: warningAnimation,
            builder: (context, child) {
              final pulse = isNearLimit
                  ? Curves.easeInOut.transform(warningAnimation.value)
                  : 0.0;
              final warningColor = Theme.of(context).colorScheme.error;
              final gradientColors = isNearLimit
                  ? [
                      Color.lerp(
                        colors.first,
                        warningColor,
                        0.12 + 0.08 * pulse,
                      )!,
                      Color.lerp(
                        colors.last,
                        warningColor,
                        0.18 + 0.1 * pulse,
                      )!,
                    ]
                  : colors;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  border: Border.all(
                    color: isNearLimit
                        ? warningColor.withValues(alpha: 0.65 + 0.3 * pulse)
                        : isSelected
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.22),
                    width: isNearLimit
                        ? 2 + pulse
                        : isSelected
                        ? 2.4
                        : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(
                        alpha: isSelected ? 0.5 : 0.3,
                      ),
                      blurRadius: isSelected ? 24 : 14,
                      offset: const Offset(0, 8),
                    ),
                    if (isNearLimit)
                      BoxShadow(
                        color: warningColor.withValues(
                          alpha: 0.26 + 0.28 * pulse,
                        ),
                        blurRadius: 18 + 12 * pulse,
                        spreadRadius: 2 + 3 * pulse,
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: Stack(
              children: [
                Center(
                  child: _BubbleContent(item: item, radius: radius),
                ),
                if (isNearLimit)
                  Positioned(
                    right: radius * 0.2,
                    top: radius * 0.2,
                    child: _BubbleStatusBadge(
                      icon: Icons.priority_high_rounded,
                      radius: radius,
                    ),
                  ),
                if (isBlocked)
                  Positioned(
                    right: radius * 0.24,
                    bottom: radius * 0.24,
                    child: _BubbleStatusBadge(icon: Icons.lock, radius: radius),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleStatusBadge extends StatelessWidget {
  const _BubbleStatusBadge({required this.icon, required this.radius});

  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all((radius * 0.08).clamp(3, 5)),
        child: Icon(
          icon,
          color: Colors.white,
          size: (radius * 0.22).clamp(10, 15),
        ),
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({required this.item, required this.radius});

  final UsageItem item;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final iconSize = (radius * 0.58).clamp(18.0, 34.0);
    final iconBytes = item.iconBytes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(iconSize * 0.28),
            child: Image.memory(
              iconBytes,
              width: iconSize * 1.3,
              height: iconSize * 1.3,
              cacheWidth: 132,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          )
        else
          Icon(_iconFor(item.name), color: Colors.white, size: iconSize),
      ],
    );
  }
}

List<Color> _colorsFor(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('youtube')) {
    return const [Color(0xFFFF5A6E), Color(0xFFB5122A)];
  }
  if (normalized.contains('tiktok')) {
    return const [Color(0xFF58E7FF), Color(0xFF171B2F)];
  }
  if (normalized.contains('instagram')) {
    return const [Color(0xFFFFC26A), Color(0xFFB832B2)];
  }
  if (normalized.contains('code') || normalized.contains('editor')) {
    return const [Color(0xFF58B7FF), Color(0xFF1759C8)];
  }
  if (normalized.contains('chrome') || normalized.contains('browser')) {
    return const [Color(0xFF5DD68D), Color(0xFF1B74E4)];
  }
  if (normalized.contains('whatsapp')) {
    return const [Color(0xFF52D273), Color(0xFF128C7E)];
  }
  if (normalized.contains('spotify')) {
    return const [Color(0xFF69D86A), Color(0xFF169B45)];
  }
  if (normalized.contains('discord')) {
    return const [Color(0xFF8EA1FF), Color(0xFF5865F2)];
  }
  if (normalized.contains('gmail') || normalized.contains('mail')) {
    return const [Color(0xFFFFD166), Color(0xFFE64B3C)];
  }
  if (normalized.contains('settings')) {
    return const [Color(0xFF9DA8BA), Color(0xFF4D5868)];
  }
  return const [Color(0xFF7BDFF2), Color(0xFF6A5AE0)];
}

IconData _iconFor(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('youtube')) {
    return Icons.play_arrow_rounded;
  }
  if (normalized.contains('tiktok') || normalized.contains('spotify')) {
    return Icons.music_note_rounded;
  }
  if (normalized.contains('instagram')) {
    return Icons.camera_alt_rounded;
  }
  if (normalized.contains('code') || normalized.contains('editor')) {
    return Icons.code_rounded;
  }
  if (normalized.contains('chrome') || normalized.contains('browser')) {
    return Icons.public_rounded;
  }
  if (normalized.contains('whatsapp') || normalized.contains('discord')) {
    return Icons.chat_bubble_rounded;
  }
  if (normalized.contains('gmail') || normalized.contains('mail')) {
    return Icons.mail_rounded;
  }
  if (normalized.contains('settings')) {
    return Icons.settings_rounded;
  }
  return Icons.apps_rounded;
}
