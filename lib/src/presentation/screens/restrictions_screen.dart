import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/block_routine.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_item.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../widgets/app_category_widgets.dart';
import '../widgets/app_icon_avatar.dart';
import '../widgets/trend_color.dart';
import '../widgets/restriction_discovery.dart';
import '../view_models/restriction_insights.dart';
import 'restriction_editor_sheet.dart';
import 'routine_editor_sheet.dart';
import 'routine_details_screen.dart';

/// Rules under their app's category, in category order. An app with no
/// usage summary is classified from its stored name and key.
@visibleForTesting
List<MapEntry<UsageCategory, List<RestrictionRule>>> groupRulesByCategory(
  List<RestrictionRule> rules,
  Map<String, AppUsageSummary> appsByKey,
  Map<String, UsageCategory> overrides,
) {
  final groups = <UsageCategory, List<RestrictionRule>>{};
  for (final rule in rules) {
    final summary =
        appsByKey[rule.appKey] ??
        AppUsageSummary(
          appName: rule.appName,
          packageName: rule.appKey,
          totalDurationSeconds: 0,
          percentageOfTotal: 0,
        );
    groups
        .putIfAbsent(resolveUsageCategory(summary, overrides), () => [])
        .add(rule);
  }
  return [
    for (final category in UsageCategory.values)
      if (groups[category] case final rules?) MapEntry(category, rules),
  ];
}

class RestrictionsScreen extends ConsumerWidget {
  const RestrictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restrictionsViewModelProvider);
    final viewModel = ref.read(restrictionsViewModelProvider.notifier);
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final summaries = dashboardState.summaries;

    final installedApps =
        ref.watch(installedAppsProvider).valueOrNull ?? const [];
    final appCandidates = _mergeAppCandidates(summaries, installedApps);
    final appsByKey = {for (final app in appCandidates) app.appKey: app};
    final routineAppsByKey = <String, AppUsageSummary>{
      ...appsByKey,
      for (final app in state.todayUsage) app.appKey: app,
    };
    final categoryOverrides =
        ref.watch(appCategoriesViewModelProvider).asData?.value ??
        const <String, UsageCategory>{};
    final todayUsageByKey = {
      for (final app in state.todayUsage) app.appKey: app.totalDurationSeconds,
    };

    void chooseApp({bool search = false}) => _chooseAppAndCreateRule(
      context,
      ref,
      apps: appCandidates,
      rules: state.rules,
      search: search,
    );
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.restrictionsTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restrictionPeriodInsightsProvider);
          await viewModel.load();
        },
        child: ListView(
          key: const ValueKey('restrictions-scroll-view'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            // Permission and platform problems stay at the very top.
            if (state.platform == UsagePlatform.android &&
                !state.hasOverlayPermission) ...[
              _OverlayPermissionCard(
                onOpenSettings: viewModel.openOverlaySettings,
                onRecheck: viewModel.refreshOverlayPermission,
              ),
              const SizedBox(height: 12),
            ],
            if (state.platform != UsagePlatform.android) ...[
              _InfoCard(
                title: context.l10n.restrictionsPlatformStatusTitle,
                body: context.l10n.restrictionsPlatformStatusBody,
              ),
              const SizedBox(height: 12),
            ],
            if (state.errorMessage != null) ...[
              Text(
                restrictionErrorText(context, state.errorMessage!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            _SectionTitle(
              title: context.l10n.rxYourRules,
              badge: state.isLoading ? null : _CountBadge(state.rules.length),
              action: FilledButton(
                key: const ValueKey('restriction-add'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: chooseApp,
                child: Text(context.l10n.rxAdd),
              ),
            ),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.rules.isEmpty)
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.rxNoRulesYet,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else ...[
              // Rules grouped under their app's category, in category order.
              for (final group in groupRulesByCategory(
                state.rules,
                appsByKey,
                categoryOverrides,
              )) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CategoryPill(
                      group.key,
                      key: ValueKey('restriction-group-${group.key.name}'),
                      compact: true,
                    ),
                  ),
                ),
                for (final rule in group.value)
                  _RestrictionRuleTile(
                    rule: rule,
                    summary: routineAppsByKey[rule.appKey]?.copyWith(
                      totalDurationSeconds: todayUsageByKey[rule.appKey] ?? 0,
                    ),
                    isSaving: state.isSaving,
                    onUnblockNow: () async {
                      if (!await confirmRestrictionChange(
                        context,
                        body: rule.difficulty == RestrictionDifficulty.moderate
                            ? context.l10n.rxModerateUnblockBody
                            : null,
                      )) {
                        return;
                      }
                      await viewModel.unblockAppNow(
                        appKey: rule.appKey,
                        usageSecondsToday: todayUsageByKey[rule.appKey] ?? 0,
                      );
                      if (context.mounted) {
                        await showRestrictionResult(context, ref);
                      }
                    },
                    onTap: () async {
                      final updated = await showRestrictionEditor(
                        context,
                        appKey: rule.appKey,
                        appName: rule.appName,
                        existing: rule,
                        iconBytes: appsByKey[rule.appKey]?.iconBytes,
                        averageSeconds: ref.read(restrictionWeekProvider)
                            ? ref
                                  .read(restrictionInsightsProvider)
                                  .asData
                                  ?.value
                                  .apps
                                  .where((a) => a.appKey == rule.appKey)
                                  .firstOrNull
                                  ?.totalDurationSeconds
                            : null,
                      );
                      if (updated == null || !context.mounted) return;
                      await viewModel.saveRule(updated, replacing: rule);
                      if (context.mounted) {
                        await showRestrictionResult(context, ref);
                      }
                    },
                    onDelete: () async {
                      if (!await confirmRestrictionChange(context)) return;
                      await viewModel.deleteRule(rule.appKey, rule.type);
                      if (context.mounted) {
                        await showRestrictionResult(context, ref);
                      }
                    },
                  ),
              ],
            ],
            const SizedBox(height: 28),
            ChooseAppsSection(onSearch: () => chooseApp(search: true)),
            const SizedBox(height: 24),
            const BusiestHoursCard(),
            const SizedBox(height: 28),
            _SectionTitle(
              title: context.l10n.restrictionsRoutinesTitle,
              action: Tooltip(
                message: context.l10n.restrictionsAddRoutine,
                child: TextButton.icon(
                  onPressed: () => _createRoutine(context, ref, appCandidates),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.rxCreate),
                ),
              ),
            ),
            if (state.routines.isEmpty)
              _InfoCard(
                title: context.l10n.restrictionsRoutinesEmptyTitle,
                body: context.l10n.restrictionsRoutinesEmptyBody,
              )
            else
              for (final routine in state.routines)
                _RoutineTile(
                  routine: routine,
                  appsByKey: routineAppsByKey,
                  usageSeconds: routine.usageSeconds(todayUsageByKey),
                  isSaving: state.isSaving,
                  onToggle: (enabled) =>
                      viewModel.setRoutineEnabled(routine, enabled),
                  onTap: () => _openRoutineDetails(
                    context,
                    routine: routine,
                    apps: appCandidates,
                  ),
                ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  List<AppUsageSummary> _mergeAppCandidates(
    List<AppUsageSummary> summaries,
    List<AppUsageSummary> installedApps,
  ) {
    final byKey = <String, AppUsageSummary>{};
    for (final app in installedApps) {
      byKey[app.appKey] = app;
    }
    for (final app in summaries) {
      byKey[app.appKey] = app;
    }
    return byKey.values.toList();
  }

  Future<void> _createRoutine(
    BuildContext context,
    WidgetRef ref,
    List<AppUsageSummary> apps,
  ) async {
    final routine = await showRoutineEditor(context, apps: apps);
    if (routine == null || !context.mounted) {
      return;
    }
    await ref.read(restrictionsViewModelProvider.notifier).saveRoutine(routine);
    if (context.mounted) {
      await promptRestrictionPermissionsIfNeeded(context, ref);
    }
  }

  Future<void> _openRoutineDetails(
    BuildContext context, {
    required List<AppUsageSummary> apps,
    required BlockRoutine routine,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            RoutineDetailsScreen(routineId: routine.id, appCandidates: apps),
      ),
    );
  }

  Future<void> _chooseAppAndCreateRule(
    BuildContext context,
    WidgetRef ref, {
    required List<AppUsageSummary> apps,
    required List<RestrictionRule> rules,
    bool search = false,
  }) async {
    final candidates = _appCandidates(apps, rules);
    final selected = await showModalBottomSheet<_AppCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D111A),
      builder: (context) =>
          _AppSearchSheet(candidates: candidates, autofocus: search),
    );
    if (selected == null || !context.mounted) {
      return;
    }
    await createRestrictionForApp(
      context,
      ref,
      appKey: selected.appKey,
      appName: selected.appName,
    );
  }

  List<_AppCandidate> _appCandidates(
    List<AppUsageSummary> apps,
    List<RestrictionRule> rules,
  ) {
    final candidatesByKey = <String, _AppCandidate>{};
    for (final app in apps) {
      candidatesByKey[app.appKey] = _AppCandidate(
        appKey: app.appKey,
        appName: app.appName,
        subtitle: app.processName ?? app.packageName,
        iconBytes: app.iconBytes,
      );
    }
    for (final rule in rules) {
      candidatesByKey.putIfAbsent(
        rule.appKey,
        () => _AppCandidate(
          appKey: rule.appKey,
          appName: rule.appName,
          subtitle: rule.appKey,
        ),
      );
    }
    final candidates = candidatesByKey.values.toList()
      ..sort(
        (first, second) =>
            first.appName.toLowerCase().compareTo(second.appName.toLowerCase()),
      );
    return candidates;
  }
}

/// A section heading with its one action. Large text stacks the action
/// under the heading instead of squeezing the heading mid-word.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action, this.badge});

  final String title;
  final Widget action;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (badge != null) ...[const SizedBox(width: 8), badge!],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 6), action],
            )
          : Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 8),
                action,
              ],
            ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A small rounded label, such as a rule's difficulty or "Paused".
class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// "12m used" on the left, "33m left" on the right, under a progress bar.
class _UsageCaption extends StatelessWidget {
  const _UsageCaption({required this.usedSeconds, required this.limitSeconds});

  final int usedSeconds;
  final int limitSeconds;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              l.rxUsed(l.compactDuration(Duration(seconds: usedSeconds))),
              style: style,
            ),
          ),
          // Once the limit is reached the status line says what happens.
          if (usedSeconds < limitSeconds) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l.rxLeft(
                  l.compactDuration(
                    Duration(seconds: math.max(0, limitSeconds - usedSeconds)),
                  ),
                ),
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.routine,
    required this.appsByKey,
    required this.usageSeconds,
    required this.isSaving,
    required this.onToggle,
    required this.onTap,
  });

  final BlockRoutine routine;
  final Map<String, AppUsageSummary> appsByKey;
  final int usageSeconds;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final limit = routine.dailyLimitMinutes;
    final names = routine.apps.take(2).map((a) => a.appName).join(', ');
    final apps = routine.apps.isEmpty
        ? l.routineNoAppsShort
        : routine.apps.length > 2
        ? l.rxMoreApps(names, routine.apps.length - 2)
        : names;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (MediaQuery.textScalerOf(context).scale(1) <= 1.3) ...[
                    _RoutineIconStack(routine: routine, appsByKey: appsByKey),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          apps,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                        Text(
                          limit == null
                              ? l.routineUsageOnly(
                                  l.compactDuration(
                                    Duration(seconds: usageSeconds),
                                  ),
                                )
                              : l.rxSharedLimit(
                                  l.compactDuration(Duration(minutes: limit)),
                                ),
                          style: muted,
                        ),
                        if (limit != null && !routine.isEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _Tag(l.rxPaused),
                          ),
                      ],
                    ),
                  ),
                  if (limit != null)
                    Switch(
                      value: routine.isEnabled,
                      onChanged: isSaving || !routine.canEnforceLimit
                          ? null
                          : onToggle,
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (limit != null && routine.isEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LimitProgress(
                        usedSeconds: usageSeconds,
                        limitSeconds: limit * 60,
                      ),
                      _UsageCaption(
                        usedSeconds: usageSeconds,
                        limitSeconds: limit * 60,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineIconStack extends StatelessWidget {
  const _RoutineIconStack({required this.routine, required this.appsByKey});

  final BlockRoutine routine;
  final Map<String, AppUsageSummary> appsByKey;

  @override
  Widget build(BuildContext context) {
    final apps = routine.apps.take(3).toList();
    if (apps.isEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.apps, size: 20),
      );
    }
    return SizedBox(
      width: 40 + (apps.length - 1) * 12,
      height: 40,
      child: Stack(
        children: [
          for (var index = 0; index < apps.length; index++)
            PositionedDirectional(
              start: index * 12,
              child: AppIconAvatar(
                appName: apps[index].appName,
                iconBytes: appsByKey[apps[index].appKey]?.iconBytes,
                size: 40,
              ),
            ),
        ],
      ),
    );
  }
}

class _AppCandidate {
  const _AppCandidate({
    required this.appKey,
    required this.appName,
    this.subtitle,
    this.iconBytes,
  });

  final String appKey;
  final String appName;
  final String? subtitle;
  final Uint8List? iconBytes;
}

class _AppSearchSheet extends StatefulWidget {
  const _AppSearchSheet({required this.candidates, this.autofocus = false});

  final List<_AppCandidate> candidates;
  final bool autofocus;

  @override
  State<_AppSearchSheet> createState() => _AppSearchSheetState();
}

class _AppSearchSheetState extends State<_AppSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCandidates();
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: TextField(
                  autofocus: widget.autofocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.l10n.restrictionsSearchApps,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: widget.candidates.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.l10n.restrictionsNoAppsAvailable,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(context.l10n.restrictionsNoMatchingApps),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final candidate = filtered[index];
                          return ListTile(
                            leading: AppIconAvatar(
                              appName: candidate.appName,
                              iconBytes: candidate.iconBytes,
                            ),
                            title: Text(
                              candidate.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: candidate.subtitle == null
                                ? null
                                : Text(
                                    candidate.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => Navigator.of(context).pop(candidate),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_AppCandidate> _filteredCandidates() {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.candidates;
    }
    return widget.candidates
        .where(
          (candidate) =>
              candidate.appName.toLowerCase().contains(query) ||
              candidate.appKey.toLowerCase().contains(query) ||
              (candidate.subtitle?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }
}

class _RestrictionRuleTile extends StatelessWidget {
  const _RestrictionRuleTile({
    required this.rule,
    required this.summary,
    required this.isSaving,
    required this.onUnblockNow,
    required this.onTap,
    required this.onDelete,
  });

  final RestrictionRule rule;
  final AppUsageSummary? summary;
  final bool isSaving;
  final VoidCallback onUnblockNow;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final usageSeconds = summary?.totalDurationSeconds ?? 0;
    final now = DateTime.now();
    final blockedUntil = rule.blockedUntil(
      now,
      usageSecondsToday: usageSeconds,
    );
    final isBlocked = rule.blocksAt(now, usageSeconds);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final (status, statusColor) = _status(context, rule, usageSeconds);
    final difficulty = [
      l.rxEasy,
      l.rxModerate,
      l.rxHard,
    ][rule.difficulty.index];
    final isLimit =
        rule.type == RestrictionRuleType.dailyLimit &&
        (rule.limitMinutes ?? 0) > 0;
    // Hard rules cannot be unblocked or removed while they block, so the
    // menu says so instead of offering an action that would be refused.
    final locked = isBlocked && rule.difficulty == RestrictionDifficulty.hard;
    final lockedUntil = blockedUntil == null
        ? null
        : _formatTime(context, TimeOfDay.fromDateTime(blockedUntil));
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconAvatar(
                    appName: rule.appName,
                    iconBytes: summary?.iconBytes,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(_ruleSummary(context, rule), style: muted),
                        if (rule.type == RestrictionRuleType.schedule)
                          Text(_days(context, rule.weekdays), style: muted),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !isSaving,
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) => switch (action) {
                      'edit' => onTap(),
                      'unblock' => onUnblockNow(),
                      _ => onDelete(),
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text(l.rxEdit)),
                      if (isBlocked && !locked)
                        PopupMenuItem(
                          value: 'unblock',
                          child: Text(
                            rule.difficulty == RestrictionDifficulty.moderate
                                ? l.rxUnblockAfterWait
                                : l.restrictionsUnblockNow,
                          ),
                        ),
                      if (locked && lockedUntil != null)
                        PopupMenuItem(
                          enabled: false,
                          child: Text(l.rxLockedUntil(lockedUntil)),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        enabled: !locked,
                        child: Text(l.restrictionsDeleteRule),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isLimit) ...[
                      _LimitProgress(
                        usedSeconds: usageSeconds,
                        limitSeconds: rule.limitMinutes! * 60,
                      ),
                      _UsageCaption(
                        usedSeconds: usageSeconds,
                        limitSeconds: rule.limitMinutes! * 60,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        // A limit with time left reads from its caption;
                        // anything else gets a status line.
                        if (!isLimit || blockedUntil != null) ...[
                          Icon(
                            blockedUntil != null
                                ? Icons.lock_outline
                                : Icons.schedule,
                            size: 18,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else
                          const Spacer(),
                        _Tag(difficulty),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Mon–Fri", "Every day", or the selected days in order.
  String _days(BuildContext context, List<int> weekdays) {
    final days = [...weekdays]..sort();
    if (days.length == 7) return context.l10n.rxEveryDay;
    final names = DateFormat.E(
      Localizations.localeOf(context).toString(),
    ).dateSymbols.SHORTWEEKDAYS;
    String name(int day) => names[day % 7];
    final consecutive =
        days.length >= 3 && days.last - days.first == days.length - 1;
    return consecutive
        ? '${name(days.first)}–${name(days.last)}'
        : days.map(name).join(', ');
  }

  /// What the rule is: "Daily limit · 1h 30m", "Schedule · 9:00 PM – 7:00 AM",
  /// "Block now · Until 3:00 PM".
  String _ruleSummary(BuildContext context, RestrictionRule rule) {
    final l = context.l10n;
    return switch (rule.type) {
      RestrictionRuleType.dailyLimit =>
        '${l.rxDailyLimit} · ${l.compactDuration(Duration(minutes: rule.limitMinutes ?? 0))}',
      RestrictionRuleType.schedule =>
        '${l.restrictionEditorTypeSchedule} · ${_minuteTime(context, rule.startMinute)} – ${_minuteTime(context, rule.endMinute)}',
      RestrictionRuleType.blockNow =>
        '${l.rxBlockNow} · ${l.rxUntil(_formatTime(context, TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(rule.untilMs ?? 0))))}',
    };
  }

  /// Where the rule stands now, with the colour that status reads in.
  (String, Color) _status(
    BuildContext context,
    RestrictionRule rule,
    int usageSeconds,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final blockedUntil = rule.blockedUntil(
      now,
      usageSecondsToday: usageSeconds,
    );
    final red = trendColor(theme, isFlat: false, isIncrease: true);
    if (blockedUntil != null) {
      return (
        context.l10n.restrictionsBlockedUntil(
          _formatTime(context, TimeOfDay.fromDateTime(blockedUntil)),
        ),
        red,
      );
    }
    switch (rule.type) {
      case RestrictionRuleType.dailyLimit:
        final left = (rule.limitMinutes ?? 0) * 60 - usageSeconds;
        return (
          context.l10n.rxLeftToday(
            context.l10n.compactDuration(Duration(seconds: left)),
          ),
          theme.colorScheme.primary,
        );
      case RestrictionRuleType.schedule:
        final next = rule.nextScheduledStart(now);
        if (next == null) {
          return (_statusText(context, rule, null), theme.colorScheme.primary);
        }
        final sameDay =
            next.year == now.year &&
            next.month == now.month &&
            next.day == now.day;
        final time = _formatTime(context, TimeOfDay.fromDateTime(next));
        final when = sameDay
            ? time
            : '${DateFormat.E(Localizations.localeOf(context).toString()).format(next)} $time';
        return (context.l10n.rxStarts(when), theme.colorScheme.primary);
      case RestrictionRuleType.blockNow:
        return (
          context.l10n.restrictionsTemporaryBlockExpired,
          theme.colorScheme.onSurfaceVariant,
        );
    }
  }

  String _statusText(
    BuildContext context,
    RestrictionRule rule,
    AppUsageSummary? summary,
  ) {
    final now = DateTime.now();
    final usageSeconds = summary?.totalDurationSeconds ?? 0;
    final blockedUntil = rule.blockedUntil(
      now,
      usageSecondsToday: usageSeconds,
    );
    if (blockedUntil != null) {
      return context.l10n.restrictionsBlockedUntil(
        _formatTime(context, TimeOfDay.fromDateTime(blockedUntil)),
      );
    }

    switch (rule.type) {
      case RestrictionRuleType.blockNow:
        return context.l10n.restrictionsTemporaryBlockExpired;
      case RestrictionRuleType.dailyLimit:
        final limit = context.l10n.compactDuration(
          Duration(minutes: rule.limitMinutes ?? 0),
        );
        final used = context.l10n.compactDuration(
          Duration(seconds: usageSeconds),
        );
        return context.l10n.restrictionsDailyLimitStatus(limit, used);
      case RestrictionRuleType.schedule:
        final next = rule.nextScheduledStart(now);
        final range = context.l10n.restrictionsScheduleStatus(
          _minuteTime(context, rule.startMinute),
          _minuteTime(context, rule.endMinute),
        );
        if (next == null) return range;
        final formatted =
            '${MaterialLocalizations.of(context).formatShortDate(next)} ${TimeOfDay.fromDateTime(next).format(context)}';
        return '$range · ${context.l10n.rxNextBlock(formatted)}';
    }
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  String _minuteTime(BuildContext context, int? minute) {
    if (minute == null) {
      return '--:--';
    }
    return _formatTime(
      context,
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
  }
}

/// Today's use against a daily limit: green, then amber past three
/// quarters, then red once the limit is reached.
class _LimitProgress extends StatelessWidget {
  const _LimitProgress({required this.usedSeconds, required this.limitSeconds});

  final int usedSeconds;
  final int limitSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = (usedSeconds / limitSeconds).clamp(0.0, 1.0);
    final green = trendColor(theme, isFlat: false, isIncrease: false);
    final red = trendColor(theme, isFlat: false, isIncrease: true);
    // The amber is the palette's existing yellow (Entertainment's tag).
    final color = fraction >= 1
        ? red
        : fraction >= 0.75
        ? UsageCategory.entertainment.color
        : green;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        key: const ValueKey('restriction-limit-progress'),
        value: fraction,
        minHeight: 6,
        color: color,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _OverlayPermissionCard extends StatelessWidget {
  const _OverlayPermissionCard({
    required this.onOpenSettings,
    required this.onRecheck,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.restrictionsOverlayPermissionTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.restrictionsOverlayPermissionBody),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(context.l10n.restrictionsOpenOverlaySettings),
                ),
                OutlinedButton.icon(
                  onPressed: onRecheck,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.restrictionsRecheck),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
