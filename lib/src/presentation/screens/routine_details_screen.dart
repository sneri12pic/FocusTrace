import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/block_routine.dart';
import '../../domain/models/restriction_rule.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/app_usage_details_view_model.dart';
import '../widgets/app_icon_avatar.dart';
import '../widgets/routine_app_picker.dart';
import '../widgets/trend_color.dart';
import 'restriction_editor_sheet.dart';
import 'routine_editor_sheet.dart';
import 'usage_details_screen.dart';

/// Every restriction blocking [appKey] right now, in plain words. An app
/// stays blocked while any of them applies, so all are listed.
List<String> appBlockReasons(
  BuildContext context, {
  required String appKey,
  required List<RestrictionRule> rules,
  required List<BlockRoutine> routines,
  required Map<String, int> usageByAppKey,
  DateTime? now,
}) {
  final l = context.l10n;
  final at = now ?? DateTime.now();
  final usage = usageByAppKey[appKey] ?? 0;
  String time(DateTime value) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(value),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
  return [
    for (final rule in rules)
      if (rule.appKey == appKey && rule.blocksAt(at, usage))
        switch (rule.type) {
          RestrictionRuleType.dailyLimit => l.reasonDailyAppLimit,
          RestrictionRuleType.schedule => l.reasonScheduleUntil(
            time(rule.blockedUntil(at, usageSecondsToday: usage)!),
          ),
          RestrictionRuleType.blockNow => l.reasonTemporaryUntil(
            time(rule.blockedUntil(at, usageSecondsToday: usage)!),
          ),
        },
    for (final routine in routines)
      if (routine.apps.any((a) => a.appKey == appKey)) ...[
        if (routine.apps.any(
              (a) => a.appKey == appKey && a.isIncludedInLimit,
            ) &&
            routine.isSharedAllowanceReached(usageByAppKey))
          l.routineReasonShared(routine.name),
        if (routine.isAppCapReached(appKey, usageByAppKey))
          l.routineReasonApp(routine.name),
      ],
  ];
}

class RoutineDetailsScreen extends ConsumerStatefulWidget {
  const RoutineDetailsScreen({
    required this.routineId,
    required this.appCandidates,
    super.key,
  });

  final String routineId;
  final List<AppUsageSummary> appCandidates;

  @override
  ConsumerState<RoutineDetailsScreen> createState() =>
      _RoutineDetailsScreenState();
}

class _RoutineDetailsScreenState extends ConsumerState<RoutineDetailsScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_refreshUsage);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshUsage(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUsage();
    }
  }

  void _refreshUsage() {
    ref.read(restrictionsViewModelProvider.notifier).refreshRoutineUsage();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restrictionsViewModelProvider);
    final routine = state.routines
        .where((item) => item.id == widget.routineId)
        .firstOrNull;
    if (routine == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.routineNotFound)),
      );
    }
    final summariesByKey = <String, AppUsageSummary>{
      for (final app in widget.appCandidates) app.appKey: app,
      for (final app in state.todayUsage) app.appKey: app,
    };
    final usageByKey = {
      for (final app in state.todayUsage) app.appKey: app.totalDurationSeconds,
    };
    final usedSeconds = routine.usageSeconds(usageByKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          IconButton(
            tooltip: context.l10n.routineRename,
            onPressed: state.isSaving ? null : () => _rename(routine),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete(routine);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline),
                    const SizedBox(width: 12),
                    Text(context.l10n.restrictionsDeleteRoutine),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(restrictionsViewModelProvider.notifier)
            .refreshRoutineUsage(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Edge-to-edge: reserve room so the last app clears the nav bar.
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            48 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _UsageCard(
              routine: routine,
              usedSeconds: usedSeconds,
              isSaving: state.isSaving,
              onToggle: (value) => _toggleLimit(routine, value),
              onEditLimit: () => _editLimit(routine),
              onRemoveLimit: routine.dailyLimitMinutes == null
                  ? null
                  : () => _save(
                      routine.copyWith(clearDailyLimit: true, isEnabled: false),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.routineAppsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: state.isSaving
                      ? null
                      : () => _addApp(routine, summariesByKey.values.toList()),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.routineAddApps),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (routine.apps.isEmpty)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.l10n.routineEmpty),
                ),
              ),
            for (final app in routine.apps)
              _RoutineAppRow(
                key: ValueKey(app.appKey),
                app: app,
                summary: summariesByKey[app.appKey],
                usageSeconds: usageByKey[app.appKey] ?? 0,
                reasons: appBlockReasons(
                  context,
                  appKey: app.appKey,
                  rules: state.rules,
                  routines: state.routines,
                  usageByAppKey: usageByKey,
                ),
                isSaving: state.isSaving,
                onOpen: () => _openDetails(app, summariesByKey[app.appKey]),
                onEditLimit: () => _editAppLimit(routine, app),
                onIncluded: (value) => _setIncluded(routine, app, value),
                onRemove: () => _removeApp(routine, app),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BlockRoutine routine) {
    return ref
        .read(restrictionsViewModelProvider.notifier)
        .saveRoutine(routine);
  }

  Future<void> _toggleLimit(BlockRoutine routine, bool enabled) async {
    await _save(routine.copyWith(isEnabled: enabled));
    if (enabled && mounted) {
      await promptRestrictionPermissionsIfNeeded(context, ref);
    }
  }

  Future<void> _rename(BlockRoutine routine) async {
    final controller = TextEditingController(text: routine.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.routineRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.routineEditorName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && mounted) await _save(routine.copyWith(name: name));
  }

  Future<void> _editLimit(BlockRoutine routine) async {
    final minutes = await showRoutineLimitPicker(
      context,
      initialMinutes: routine.dailyLimitMinutes ?? 180,
    );
    if (minutes != null && mounted) {
      await _save(
        routine.copyWith(dailyLimitMinutes: minutes, isEnabled: true),
      );
      if (mounted) {
        await promptRestrictionPermissionsIfNeeded(context, ref);
      }
    }
  }

  Future<void> _addApp(
    BlockRoutine routine,
    List<AppUsageSummary> candidates,
  ) async {
    final existingKeys = routine.apps.map((app) => app.appKey).toSet();
    final available = candidates
        .where((app) => !existingKeys.contains(app.appKey))
        .toList();
    final selected = await showModalBottomSheet<List<AppUsageSummary>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D111A),
      builder: (context) => _AddAppsSheet(apps: available),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _save(
      routine.copyWith(
        apps: [
          ...routine.apps,
          for (final app in selected)
            RoutineApp(appKey: app.appKey, appName: app.appName),
        ],
      ),
    );
  }

  void _openDetails(RoutineApp app, AppUsageSummary? summary) {
    final platform = ref.read(restrictionsViewModelProvider).platform;
    final now = DateTime.now();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => UsageDetailsScreen(
          request: AppUsageDetailsRequest(
            summary:
                summary ??
                AppUsageSummary(
                  appName: app.appName,
                  packageName: app.appKey,
                  totalDurationSeconds: 0,
                  percentageOfTotal: 0,
                ),
            selectedDate: DateTime(now.year, now.month, now.day),
            platform: platform,
          ),
        ),
      ),
    );
  }

  Future<void> _editAppLimit(BlockRoutine routine, RoutineApp target) async {
    final minutes = await showRoutineLimitPicker(
      context,
      initialMinutes: target.limitMinutes ?? 60,
      title: context.l10n.routineAppLimitTitle(target.appName),
      hint: context.l10n.routineAppLimitHint,
      removeLabel: target.limitMinutes == null
          ? null
          : context.l10n.routineNoAppLimit,
    );
    if (minutes == null || !mounted) return;
    await _save(
      routine.copyWith(
        apps: [
          for (final app in routine.apps)
            if (app.appKey != target.appKey)
              app
            else if (minutes <= 0)
              app.copyWith(clearLimit: true)
            else
              app.copyWith(limitMinutes: minutes),
        ],
      ),
    );
  }

  Future<void> _setIncluded(
    BlockRoutine routine,
    RoutineApp target,
    bool included,
  ) {
    return _save(
      routine.copyWith(
        apps: [
          for (final app in routine.apps)
            if (app.appKey == target.appKey)
              app.copyWith(isIncludedInLimit: included)
            else
              app,
        ],
      ),
    );
  }

  Future<void> _removeApp(BlockRoutine routine, RoutineApp target) async {
    if (routine.apps.length == 1) {
      final delete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(context.l10n.routineLastAppPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.routineKeepRoutine),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.restrictionsDeleteRoutine),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (delete == true) {
        await ref
            .read(restrictionsViewModelProvider.notifier)
            .deleteRoutine(routine.id);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // Keep (or dismissing the question) keeps the routine, now empty, so
      // apps can be added again later.
    }
    await _save(
      routine.copyWith(
        apps: routine.apps.where((app) => app.appKey != target.appKey).toList(),
      ),
    );
  }

  Future<void> _delete(BlockRoutine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.restrictionsDeleteRoutine),
        content: Text(context.l10n.routineDeleteConfirmation(routine.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.restrictionsDeleteRoutine),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(restrictionsViewModelProvider.notifier)
        .deleteRoutine(routine.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.routine,
    required this.usedSeconds,
    required this.isSaving,
    required this.onToggle,
    required this.onEditLimit,
    this.onRemoveLimit,
  });

  final BlockRoutine routine;
  final int usedSeconds;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditLimit;
  final VoidCallback? onRemoveLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limitMinutes = routine.dailyLimitMinutes;
    final limitSeconds = (limitMinutes ?? 0) * 60;
    final progress = limitSeconds == 0
        ? 0.0
        : (usedSeconds / limitSeconds).clamp(0.0, 1.0);
    final exhausted = limitSeconds > 0 && usedSeconds >= limitSeconds;
    final status = limitMinutes == null
        ? context.l10n.routineNoDailyLimit
        : !routine.canEnforceLimit
        ? context.l10n.routineNoIncludedApps
        : exhausted
        ? context.l10n.routineLimitReached
        : routine.isEnabled
        ? context.l10n.routineActive
        : context.l10n.routinePaused;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.routineUsageToday,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (limitMinutes != null)
                  Switch(
                    value: routine.isEnabled,
                    onChanged: isSaving || !routine.canEnforceLimit
                        ? null
                        : onToggle,
                  ),
              ],
            ),
            Text(
              context.l10n.compactDuration(Duration(seconds: usedSeconds)),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(status),
            if (limitMinutes != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                context.l10n.routineUsageOfLimit(
                  context.l10n.compactDuration(Duration(seconds: usedSeconds)),
                  context.l10n.compactDuration(Duration(minutes: limitMinutes)),
                ),
              ),
              if (!exhausted)
                Text(
                  context.l10n.routineRemaining(
                    context.l10n.compactDuration(
                      Duration(
                        seconds: (limitSeconds - usedSeconds).clamp(
                          0,
                          limitSeconds,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: isSaving ? null : onEditLimit,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(
                    limitMinutes == null
                        ? context.l10n.routineSetLimit
                        : context.l10n.routineEditLimit,
                  ),
                ),
                if (onRemoveLimit != null)
                  TextButton(
                    onPressed: isSaving ? null : onRemoveLimit,
                    child: Text(context.l10n.routineRemoveLimit),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineAppRow extends StatelessWidget {
  const _RoutineAppRow({
    super.key,
    required this.app,
    required this.summary,
    required this.usageSeconds,
    required this.reasons,
    required this.isSaving,
    required this.onOpen,
    required this.onEditLimit,
    required this.onIncluded,
    required this.onRemove,
  });

  final RoutineApp app;
  final AppUsageSummary? summary;
  final int usageSeconds;
  final List<String> reasons;
  final bool isSaving;
  final VoidCallback onOpen;
  final VoidCallback onEditLimit;
  final ValueChanged<bool> onIncluded;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final usage = l.compactDuration(Duration(seconds: usageSeconds));
    final blocked = trendColor(theme, isFlat: false, isIncrease: true);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Icon and name open the app's details; the controls beside
                // them never do.
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l.routineOpenDetails(app.appName),
                    excludeSemantics: true,
                    onTap: onOpen,
                    child: InkWell(
                      onTap: onOpen,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: [
                            AppIconAvatar(
                              appName: app.appName,
                              iconBytes: summary?.iconBytes,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    app.isIncludedInLimit
                                        ? l.routineAppUsage(usage)
                                        : l.routineAppUsageExcluded(usage),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Switch(
                  value: app.isIncludedInLimit,
                  onChanged: isSaving ? null : onIncluded,
                ),
                IconButton(
                  tooltip: l.routineRemoveApp,
                  onPressed: isSaving ? null : onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ActionChip(
                  avatar: Icon(
                    app.limitMinutes == null ? Icons.add : Icons.timer_outlined,
                    size: 18,
                  ),
                  label: Text(
                    app.limitMinutes == null
                        ? l.routineNoAppLimit
                        : l.routineAppLimit(
                            l.compactDuration(
                              Duration(minutes: app.limitMinutes!),
                            ),
                          ),
                  ),
                  onPressed: isSaving ? null : onEditLimit,
                ),
              ),
            ),
            for (final reason in reasons)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: blocked),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: blocked,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddAppsSheet extends StatefulWidget {
  const _AddAppsSheet({required this.apps});

  final List<AppUsageSummary> apps;

  @override
  State<_AddAppsSheet> createState() => _AddAppsSheetState();
}

class _AddAppsSheetState extends State<_AddAppsSheet> {
  Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.routineAddApps,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RoutineAppPicker(
                apps: widget.apps,
                selected: _selected,
                onChanged: (keys) => setState(() => _selected = keys),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                        for (final app in widget.apps)
                          if (_selected.contains(app.appKey)) app,
                      ]),
                child: Text(
                  _selected.isEmpty
                      ? context.l10n.routineAddApps
                      : context.l10n.routineAddSelected(_selected.length),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
