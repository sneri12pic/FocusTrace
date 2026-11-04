import 'package:flutter/material.dart';

import '../../domain/models/usage_item.dart';
import '../localization/app_localizations_x.dart';
import 'app_category_widgets.dart';

const _duration = Duration(milliseconds: 200);

// Other is not a UsageCategory, so it has no palette entry of its own.
const _otherColor = Color(0xFF8A94A6);

Color _colorOf(UsageCategory? category) => category?.color ?? _otherColor;

String _labelOf(BuildContext context, UsageCategory? category) =>
    category == null
    ? context.l10n.usageCategoryOther
    : context.l10n.usageCategoryLabel(category);

/// The "Usage by category" row and, once tapped open, its progress bars.
class CategoryUsageSection extends StatelessWidget {
  const CategoryUsageSection({
    required this.rows,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final List<CategoryUsage> rows;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Rows are sorted, so the first is the category that dominates the day.
    final tint = _colorOf(rows.first.category);
    return AnimatedContainer(
      key: const ValueKey('category-usage-tint'),
      duration: _duration,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [tint.withValues(alpha: 0.3), tint.withValues(alpha: 0.06)],
        ),
      ),
      // Keeps the ink ripple above the tint.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              child: InkWell(
                key: const ValueKey('category-usage-toggle'),
                borderRadius: BorderRadius.circular(8),
                onTap: onToggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.usageByCategory,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: tint,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(dimension: 8),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            _labelOf(context, rows.first.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: _duration,
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: _duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        children: [
                          for (final row in rows) _CategoryUsageRow(row),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryUsageRow extends StatelessWidget {
  const _CategoryUsageRow(this.row);

  final CategoryUsage row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final category = row.category;
    final color = _colorOf(category);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wraps rather than overflows with long labels or large text.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category?.icon ?? Icons.category_outlined,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _labelOf(context, category),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    text: l.compactDuration(Duration(seconds: row.seconds)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text:
                            '  ${l.percentageValue((row.share * 100).toStringAsFixed(0))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: row.share,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
      ),
    );
  }
}
