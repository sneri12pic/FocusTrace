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
    final items = viewModel.itemsFor(summaries);
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
                  for (final summary in summaries)
                    SummaryTile(
                      summary,
                      isToday: isToday,
                      trend: trendsByAppKey[summary.appKey],
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
