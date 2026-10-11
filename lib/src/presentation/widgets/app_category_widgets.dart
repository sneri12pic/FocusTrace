import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_item.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';

extension UsageCategoryColor on UsageCategory {
  Color get color => switch (this) {
    UsageCategory.entertainment => const Color(0xFFFFD166),
    UsageCategory.productivity => const Color(0xFFC4A7FF),
    UsageCategory.web => const Color(0xFF5BC0EB),
    UsageCategory.communication => const Color(0xFF75D99C),
    UsageCategory.system => const Color(0xFFB8C2D1),
    UsageCategory.activity => const Color(0xFFFFA383),
  };
}

extension UsageCategoryIcon on UsageCategory {
  IconData get icon => switch (this) {
    UsageCategory.entertainment => Icons.movie_outlined,
    UsageCategory.productivity => Icons.work_outline,
    UsageCategory.web => Icons.public,
    UsageCategory.communication => Icons.chat_bubble_outline,
    UsageCategory.system => Icons.settings_outlined,
    UsageCategory.activity => Icons.directions_run,
  };
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 16});

  final UsageCategory category;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(category.icon, size: size, color: category.color);
}

/// The category tag: a tinted pill with the category's icon and name.
class CategoryPill extends StatelessWidget {
  const CategoryPill(
    this.category, {
    super.key,
    this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final UsageCategory category;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final style =
        (compact
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelLarge)
            ?.copyWith(color: color, fontWeight: FontWeight.w700);
    final pill = Material(
      color: color.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryIcon(category, size: compact ? 12 : 16),
              SizedBox(width: compact ? 4 : 6),
              Flexible(
                child: Text(
                  context.l10n.usageCategoryLabel(category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 14, color: color),
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return pill;
    // Keeps the visual pill small while the touch target stays 48dp tall.
    final target = Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: pill,
          ),
        ),
      ),
    );
    return tooltip == null ? target : Tooltip(message: tooltip, child: target);
  }
}

class UsageCategoryLabel extends StatelessWidget {
  const UsageCategoryLabel(this.category, {super.key});

  final UsageCategory category;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: CategoryPill(category, compact: true),
    ),
  );
}

class AppCategoryTag extends ConsumerWidget {
  const AppCategoryTag(this.summary, {super.key});

  final AppUsageSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appCategoriesViewModelProvider);
    final overrides = state.asData?.value ?? const <String, UsageCategory>{};
    final category = resolveUsageCategory(summary, overrides);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryPill(
          category,
          key: const ValueKey('app-category-tag'),
          tooltip: context.l10n.appCategoryTitle,
          onTap: state.asData == null
              ? null
              : () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF0D111A),
                  builder: (context) => _CategoryPicker(
                    summary: summary,
                    initialCategory: overrides[summary.appKey],
                  ),
                ),
        ),
        if (state.hasError) ...[
          Text(context.l10n.commonUnexpectedError),
          TextButton(
            onPressed: () =>
                ref.read(appCategoriesViewModelProvider.notifier).load(),
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ],
    );
  }
}

class _CategoryPicker extends ConsumerStatefulWidget {
  const _CategoryPicker({required this.summary, this.initialCategory});

  final AppUsageSummary summary;
  final UsageCategory? initialCategory;

  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  late String _selected = widget.initialCategory?.name ?? 'automatic';
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final saved = await ref
        .read(appCategoriesViewModelProvider.notifier)
        .save(
          widget.summary.appKey,
          _selected == 'automatic'
              ? null
              : UsageCategory.values.byName(_selected),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !saved;
    });
    if (saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final automatic = automaticUsageCategory(widget.summary.appName);
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.appCategoryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.summary.appName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final category in [null, ...UsageCategory.values])
                RadioListTile<String>(
                  value: category?.name ?? 'automatic',
                  // Matches existing radio controls; migrate with the Flutter SDK.
                  // ignore: deprecated_member_use
                  groupValue: _selected,
                  // ignore: deprecated_member_use
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selected = value!),
                  title: Text(
                    category == null
                        ? context.l10n.appCategoryAutomatic
                        : context.l10n.usageCategoryLabel(category),
                  ),
                  subtitle: category == null
                      ? Text(context.l10n.usageCategoryLabel(automatic))
                      : null,
                  secondary: CategoryIcon(category ?? automatic, size: 22),
                ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.appCategorySaveError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                key: const ValueKey('save-app-category'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.appCategorySave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
