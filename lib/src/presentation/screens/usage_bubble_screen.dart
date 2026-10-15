import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_item.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/usage_bubble_view_model.dart';
import '../widgets/bubble_chart.dart';
import '../widgets/app_category_widgets.dart';
import '../widgets/summary_tile.dart';
import 'restriction_editor_sheet.dart';

class UsageBubbleScreen extends ConsumerWidget {
  const UsageBubbleScreen({
    required this.summaries,
    required this.trendsByAppKey,
    required this.isToday,
    super.key,
  });

  final List<AppUsageSummary> summaries;
  final Map<String, UsageTrend> trendsByAppKey;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usageBubbleViewModelProvider);
    final viewModel = ref.read(usageBubbleViewModelProvider.notifier);
    final overrides =
        ref.watch(appCategoriesViewModelProvider).asData?.value ??
        const <String, UsageCategory>{};
    final items = viewModel.itemsFor(summaries, categoryOverrides: overrides);
    final categorySeconds = <UsageCategory, int>{};
    for (final summary in summaries) {
      final category = resolveUsageCategory(summary, overrides);
      categorySeconds[category] =
          (categorySeconds[category] ?? 0) + summary.totalDurationSeconds;
    }
    final categories = categorySeconds.keys.toSet();
    // Most time-consuming category first.
    final rankedCategories = categorySeconds.keys.toList()
      ..sort((a, b) => categorySeconds[b]!.compareTo(categorySeconds[a]!));
    final selectedCategory = categories.contains(state.selectedCategory)
        ? state.selectedCategory
        : null;
    final listed = [
      for (final summary in summaries)
        if (selectedCategory == null ||
            resolveUsageCategory(summary, overrides) == selectedCategory)
          summary,
    ];
    // Summaries arrive sorted by time (repository and native queries).
    final hiddenCount = state.listExpanded
        ? 0
        : listed.length - UsageBubbleViewModel.topAppCount;
    final selectedItem = viewModel.selectedItemFor(items, state.selectedItemId);
    final restrictionState = ref.watch(restrictionsViewModelProvider);
    final now = DateTime.now();
    final blockedItemIds = {
      for (final summary in summaries)
        if (isToday &&
            isAppBlocked(
              appKey: summary.appKey,
              rules: restrictionState.rules,
              now: now,
              usageSecondsToday: summary.totalDurationSeconds,
            ))
          summary.appKey,
    };
    final nearLimitItemIds = isToday
        ? viewModel.nearLimitItemIds(
            summaries: summaries,
            rules: restrictionState.rules,
            now: now,
          )
        : const <String>{};

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5BC0EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Column(
            children: [
              _SectionCard(
                children: [
                  Text(
                    context.l10n.usageBubblesTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.usageBubblesDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  BubbleChart(
                    items: items,
                    selectedItem: selectedItem,
                    blockedItemIds: blockedItemIds,
                    nearLimitItemIds: nearLimitItemIds,
                    onItemSelected: viewModel.selectItem,
                    onItemLongPressed: isToday
                        ? (item) => _showBubbleActions(
                            context,
                            ref,
                            item,
                            isBlocked: blockedItemIds.contains(item.id),
                          )
                        : null,
                    onSelectionDismissed: viewModel.clearSelection,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                children: [
                  Text(
                    context.l10n.usageBubblesCurrentList,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ChipRow(
                    children: [
                      for (final category in [null, ...rankedCategories])
                        _CategoryFilterChip(
                          category: category,
                          seconds: category == null
                              ? null
                              : categorySeconds[category],
                          selected: selectedCategory == category,
                          onSelected: () => viewModel.selectCategory(category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final summary
                      in hiddenCount > 0
                          ? listed.take(UsageBubbleViewModel.topAppCount)
                          : listed)
                    SummaryTile(
                      summary,
                      isToday: isToday,
                      trend: trendsByAppKey[summary.appKey],
                    ),
                  if (listed.length > UsageBubbleViewModel.topAppCount)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        key: const ValueKey('current-list-toggle'),
                        onPressed: viewModel.toggleListExpanded,
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.white.withValues(alpha: 0.8),
                          textStyle: theme.textTheme.labelLarge,
                        ),
                        icon: Icon(
                          state.listExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          state.listExpanded
                              ? context.l10n.usageListShowLess
                              : context.l10n.usageListShowAll(hiddenCount),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _restrictItem(
    BuildContext context,
    WidgetRef ref,
    UsageItem item,
  ) {
    return createRestrictionForApp(
      context,
      ref,
      appKey: item.id,
      appName: item.name,
    );
  }

  Future<void> _showBubbleActions(
    BuildContext context,
    WidgetRef ref,
    UsageItem item, {
    required bool isBlocked,
  }) async {
    if (!isBlocked) {
      await _restrictItem(context, ref, item);
      return;
    }

    final action = await showModalBottomSheet<_BubbleAction>(
      context: context,
      backgroundColor: const Color(0xFF0D111A),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open_outlined),
              title: Text(context.l10n.actionUnblockNow),
              subtitle: Text(context.l10n.actionUnblockNowDescription),
              onTap: () => Navigator.of(context).pop(_BubbleAction.unblockNow),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.l10n.actionRestrictApp),
              subtitle: Text(context.l10n.actionRestrictAppDescription),
              onTap: () => Navigator.of(context).pop(_BubbleAction.restrict),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case _BubbleAction.unblockNow:
        final summary = summaries.where((summary) => summary.appKey == item.id);
        await ref
            .read(restrictionsViewModelProvider.notifier)
            .unblockAppNow(
              appKey: item.id,
              usageSecondsToday: summary.isEmpty
                  ? item.totalDurationSeconds
                  : summary.first.totalDurationSeconds,
            );
      case _BubbleAction.restrict:
        await _restrictItem(context, ref, item);
    }
  }
}

enum _BubbleAction { unblockNow, restrict }

/// Scrolls horizontally within the card's content width, so the chips start
/// and end where the app rows below do.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (index, child) in children.indexed)
          Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == children.length - 1 ? 0 : 8,
            ),
            child: child,
          ),
      ],
    ),
  );
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.category,
    required this.seconds,
    required this.selected,
    required this.onSelected,
  });

  final UsageCategory? category;
  final int? seconds;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    final accent = category?.color ?? Colors.white;
    return ChoiceChip(
      key: ValueKey('category-filter-${category?.name ?? 'all'}'),
      selected: selected,
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: BorderSide(
        color: selected
            ? accent.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.06),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      selectedColor: accent.withValues(alpha: 0.18),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? accent : Colors.white.withValues(alpha: 0.72),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      avatar: category == null ? null : CategoryIcon(category),
      label: Text.rich(
        TextSpan(
          text: category == null
              ? context.l10n.appCategoryAll
              : context.l10n.usageCategoryLabel(category),
          children: [
            if (seconds case final seconds?)
              TextSpan(
                text:
                    '  ${context.l10n.compactDuration(Duration(seconds: seconds))}',
                style: TextStyle(
                  color: (selected ? accent : Colors.white).withValues(
                    alpha: 0.6,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D111A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
