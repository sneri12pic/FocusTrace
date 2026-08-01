import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/models/restriction_rule.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../screens/restriction_editor_sheet.dart';
import '../screens/usage_details_screen.dart';
import '../view_models/app_usage_details_view_model.dart';
import 'app_icon_avatar.dart';
import 'trend_color.dart';

const _sheetColor = Color(0xFF0D111A);

class SummaryTile extends ConsumerWidget {
  const SummaryTile(
    this.summary, {
    required this.isToday,
    this.trend,
    super.key,
  });

  final AppUsageSummary summary;
  final bool isToday;
  final UsageTrend? trend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final percentage = (summary.percentageOfTotal * 100).clamp(0, 100);
    final restrictionState = ref.watch(restrictionsViewModelProvider);
    final isBlocked =
        isToday &&
        isAppBlocked(
          appKey: summary.appKey,
          rules: restrictionState.rules,
          now: DateTime.now(),
          usageSecondsToday: summary.totalDurationSeconds,
        );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openUsageDetails(context, ref),
        onLongPress: isToday ? () => _showActions(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppIconAvatar(
                        appName: summary.appName,
                        iconBytes: summary.iconBytes,
                        size: 36,
                      ),
                      if (isBlocked) const _LockBadge(),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (summary.launchCount > 0)
                          Text(
                            context.l10n.summaryLaunchCount(
                              summary.launchCount,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.l10n.compactDuration(summary.totalDuration),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.l10n.percentageValue(
                          percentage.toStringAsFixed(0),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              if (trend?.hasData ?? false) ...[
                const SizedBox(height: 10),
                _UsageTrendBadges(trend: trend!),
              ],
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: summary.percentageOfTotal.clamp(0, 1),
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUsageDetails(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.read(dashboardViewModelProvider);
    // Summaries arrive sorted by usage, so the list index is the day's rank.
    final summaries = dashboardState.summaries;
    final index = summaries.indexWhere((item) => item.appKey == summary.appKey);
    final isTopThree = index >= 0 && index < 3;
    final runnerUp = isTopThree && index + 1 < summaries.length
        ? summaries[index + 1]
        : null;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => UsageDetailsScreen(
          request: AppUsageDetailsRequest(
            summary: summary,
            selectedDate: dashboardState.selectedDate,
            platform: dashboardState.platform,
            rank: isTopThree ? index + 1 : null,
            runnerUpName: runnerUp?.appName,
            leadSeconds: runnerUp == null
                ? null
                : summary.totalDurationSeconds - runnerUp.totalDurationSeconds,
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final restrictionState = ref.read(restrictionsViewModelProvider);
    final isBlocked = isAppBlocked(
      appKey: summary.appKey,
      rules: restrictionState.rules,
      now: DateTime.now(),
      usageSecondsToday: summary.totalDurationSeconds,
    );
    final action = await showModalBottomSheet<_SummaryAction>(
      context: context,
      backgroundColor: _sheetColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(title: summary.appName),
            if (isBlocked)
              ListTile(
                leading: const Icon(Icons.lock_open_outlined),
                title: Text(context.l10n.actionUnblockNow),
                subtitle: Text(context.l10n.actionUnblockNowDescription),
                onTap: () =>
                    Navigator.of(context).pop(_SummaryAction.unblockNow),
              ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.l10n.actionRestrictApp),
              subtitle: Text(context.l10n.actionRestrictAppDescription),
              onTap: () => Navigator.of(context).pop(_SummaryAction.restrict),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(context.l10n.actionRemoveFromToday),
              subtitle: Text(context.l10n.actionRemoveFromTodayDescription),
              onTap: () =>
                  Navigator.of(context).pop(_SummaryAction.removeFromToday),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(context.l10n.actionExcludeFromTracking),
              subtitle: Text(context.l10n.actionExcludeFromTrackingDescription),
              onTap: () => Navigator.of(context).pop(_SummaryAction.exclude),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) {
      return;
    }

    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    switch (action) {
      case _SummaryAction.unblockNow:
        await ref
            .read(restrictionsViewModelProvider.notifier)
            .unblockAppNow(
              appKey: summary.appKey,
              usageSecondsToday: summary.totalDurationSeconds,
            );
      case _SummaryAction.restrict:
        await createRestrictionForApp(
          context,
          ref,
          appKey: summary.appKey,
          appName: summary.appName,
        );
      case _SummaryAction.removeFromToday:
        await dashboardViewModel.hideAppForToday(summary);
      case _SummaryAction.exclude:
        final confirmed = await _confirmExclude(context);
        if (confirmed) {
          await dashboardViewModel.excludeApp(summary);
          // Keep the settings screen's excluded-apps list in sync.
          await ref.read(settingsViewModelProvider.notifier).load();
        }
    }
  }

  Future<bool> _confirmExclude(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(context.l10n.excludeAppDialogTitle(summary.appName)),
              content: Text(context.l10n.excludeAppDialogBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.actionExclude),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class _UsageTrendBadges extends StatelessWidget {
  const _UsageTrendBadges({required this.trend});

  final UsageTrend trend;

  @override
  Widget build(BuildContext context) {
    final values = <({String period, double? value})>[
      (period: context.l10n.usageTrendDayShort, value: trend.dayChangePercent),
      (
        period: context.l10n.usageTrendWeekShort,
        value: trend.weekChangePercent,
      ),
      (
        period: context.l10n.usageTrendMonthShort,
        value: trend.monthChangePercent,
      ),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in values)
          if (entry.value != null)
            _UsageTrendBadge(period: entry.period, value: entry.value!),
      ],
    );
  }
}

class _UsageTrendBadge extends StatelessWidget {
  const _UsageTrendBadge({required this.period, required this.value});

  final String period;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFlat = value.abs() < 0.5;
    final isIncrease = value > 0;
    final color = trendColor(theme, isFlat: isFlat, isIncrease: isIncrease);
    final rounded = value.abs().round();
    final semanticLabel = isFlat
        ? context.l10n.usageTrendUnchanged(period)
        : isIncrease
        ? context.l10n.usageTrendIncrease(period, rounded)
        : context.l10n.usageTrendDecrease(period, rounded);

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFlat
                    ? Icons.remove
                    : isIncrease
                    ? Icons.trending_up
                    : Icons.trending_down,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                '$period ${isIncrease && !isFlat
                    ? '+'
                    : isFlat
                    ? ''
                    : '-'}'
                '$rounded%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SummaryAction { unblockNow, restrict, removeFromToday, exclude }

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -2,
      bottom: -2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0D111A), width: 1.5),
        ),
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.lock, size: 10, color: Colors.white),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
