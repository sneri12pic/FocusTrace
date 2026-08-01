import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/block_routine.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../widgets/app_icon_avatar.dart';
import 'restriction_editor_sheet.dart';
import 'routine_editor_sheet.dart';

class RestrictionsScreen extends ConsumerWidget {
  const RestrictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restrictionsViewModelProvider);
    final viewModel = ref.read(restrictionsViewModelProvider.notifier);
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final summaries = dashboardState.summaries;
    final topApps = dashboardState.allTimeTopApps;
    final installedApps =
        ref.watch(installedAppsProvider).valueOrNull ?? const [];
    final routineCandidates = _mergeAppCandidates(summaries, installedApps);
    final usageByApp = {
      for (final summary in summaries) summary.appKey: summary,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.restrictionsTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.restrictionsSearchApps,
            onPressed: () => _chooseAppAndCreateRule(
              context,
              ref,
              summaries: summaries,
              rules: state.rules,
            ),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (topApps.isNotEmpty) ...[
              _TopUsedCard(
                apps: topApps,
                onAppTap: (app) => createRestrictionForApp(
                  context,
                  ref,
                  appKey: app.appKey,
                  appName: app.appName,
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: () => _chooseAppAndCreateRule(
                context,
                ref,
                summaries: summaries,
                rules: state.rules,
              ),
              icon: const Icon(Icons.search),
              label: Text(context.l10n.restrictionsAddRestriction),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _createRoutine(context, ref, routineCandidates),
              icon: const Icon(Icons.playlist_add),
              label: Text(context.l10n.restrictionsAddRoutine),
            ),
            const SizedBox(height: 12),
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
                context.l10n.commonUnexpectedError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.rules.isEmpty && state.routines.isEmpty)
              _InfoCard(
                title: context.l10n.restrictionsEmptyTitle,
                body: context.l10n.restrictionsEmptyBody,
              )
            else ...[
              _SectionTitle(
                title: context.l10n.restrictionsRoutinesTitle,
                onAdd: () => _createRoutine(context, ref, routineCandidates),
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
                    isSaving: state.isSaving,
                    onToggle: (enabled) =>
                        viewModel.setRoutineEnabled(routine, enabled),
                    onTap: () =>
                        _editRoutine(context, ref, routineCandidates, routine),
                    onDelete: () => viewModel.deleteRoutine(routine.id),
                  ),
              const SizedBox(height: 14),
              if (state.rules.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.restrictionsIndividualRulesTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final rule in state.rules)
                _RestrictionRuleTile(
                  rule: rule,
                  summary: usageByApp[rule.appKey],
                  isSaving: state.isSaving,
                  onUnblockNow: () => viewModel.unblockAppNow(
                    appKey: rule.appKey,
                    usageSecondsToday:
                        usageByApp[rule.appKey]?.totalDurationSeconds ?? 0,
                  ),
                  onTap: () async {
                    final updated = await showRestrictionEditor(
                      context,
                      appKey: rule.appKey,
                      appName: rule.appName,
                      existing: rule,
                    );
                    if (updated == null || !context.mounted) {
                      return;
                    }
                    await viewModel.saveRule(updated);
                    if (context.mounted) {
                      await promptRestrictionPermissionsIfNeeded(context, ref);
                    }
                  },
                  onDelete: () => viewModel.deleteRule(rule.appKey, rule.type),
                ),
            ],
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

  Future<void> _editRoutine(
    BuildContext context,
    WidgetRef ref,
    List<AppUsageSummary> apps,
    BlockRoutine existing,
  ) async {
    final routine = await showRoutineEditor(
      context,
      apps: apps,
      existing: existing,
    );
    if (routine == null || !context.mounted) {
      return;
    }
    await ref.read(restrictionsViewModelProvider.notifier).saveRoutine(routine);
  }

  Future<void> _chooseAppAndCreateRule(
    BuildContext context,
    WidgetRef ref, {
    required List<AppUsageSummary> summaries,
    required List<RestrictionRule> rules,
  }) async {
    final candidates = _appCandidates(summaries, rules);
    final selected = await showModalBottomSheet<_AppCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D111A),
      builder: (context) => _AppSearchSheet(candidates: candidates),
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
    List<AppUsageSummary> summaries,
    List<RestrictionRule> rules,
  ) {
    final candidatesByKey = <String, _AppCandidate>{};
    for (final summary in summaries) {
      candidatesByKey[summary.appKey] = _AppCandidate(
        appKey: summary.appKey,
        appName: summary.appName,
        subtitle: summary.processName ?? summary.packageName,
        iconBytes: summary.iconBytes,
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

class _TopUsedCard extends StatelessWidget {
  const _TopUsedCard({required this.apps, required this.onAppTap});

  final List<AppUsageSummary> apps;
  final ValueChanged<AppUsageSummary> onAppTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                context.l10n.dashboardAllTimeMostUsedTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (var index = 0; index < apps.length; index++)
              ListTile(
                dense: true,
                onTap: () => onAppTap(apps[index]),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${index + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AppIconAvatar(
                      appName: apps[index].appName,
                      iconBytes: apps[index].iconBytes,
                      size: 32,
                    ),
                  ],
                ),
                title: Text(
                  apps[index].appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: Text(
                  context.l10n.compactDuration(apps[index].totalDuration),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: context.l10n.restrictionsAddRoutine,
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.routine,
    required this.isSaving,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final BlockRoutine routine;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final appNames = routine.apps.map((app) => app.appName).join(', ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.library_add_check_outlined),
        title: Text(routine.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${context.l10n.restrictionsRoutineAppCount(routine.apps.length)} · $appNames',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: routine.isEnabled,
              onChanged: isSaving ? null : onToggle,
            ),
            IconButton(
              tooltip: context.l10n.restrictionsDeleteRoutine,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
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
  const _AppSearchSheet({required this.candidates});

  final List<_AppCandidate> candidates;

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
    final usageSeconds = summary?.totalDurationSeconds ?? 0;
    final isBlocked = rule.blocksAt(DateTime.now(), usageSeconds);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: Icon(_iconFor(rule.type)),
            title: Text(
              rule.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_statusText(context, rule, summary)),
            onTap: onTap,
            trailing: IconButton(
              tooltip: context.l10n.restrictionsDeleteRule,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: isSaving ? null : onUnblockNow,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(context.l10n.restrictionsUnblockNow),
                ),
              ),
            ),
        ],
      ),
    );
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
        return context.l10n.restrictionsScheduleStatus(
          _minuteTime(context, rule.startMinute),
          _minuteTime(context, rule.endMinute),
        );
    }
  }

  IconData _iconFor(RestrictionRuleType type) {
    switch (type) {
      case RestrictionRuleType.blockNow:
        return Icons.lock_clock_outlined;
      case RestrictionRuleType.dailyLimit:
        return Icons.timer_outlined;
      case RestrictionRuleType.schedule:
        return Icons.bedtime_outlined;
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
