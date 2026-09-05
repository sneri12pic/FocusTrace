import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/block_routine.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../widgets/app_icon_avatar.dart';
import 'restriction_editor_sheet.dart';
import 'routine_editor_sheet.dart';

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
          padding: const EdgeInsets.all(16),
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
                  label: Text(context.l10n.routineAddApp),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final app in routine.apps)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: AppIconAvatar(
                    appName: app.appName,
                    iconBytes: summariesByKey[app.appKey]?.iconBytes,
                  ),
                  title: Text(
                    app.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    app.isIncludedInLimit
                        ? context.l10n.routineAppUsage(
                            context.l10n.compactDuration(
                              Duration(seconds: usageByKey[app.appKey] ?? 0),
                            ),
                          )
                        : context.l10n.routineAppUsageExcluded(
                            context.l10n.compactDuration(
                              Duration(seconds: usageByKey[app.appKey] ?? 0),
                            ),
                          ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: app.isIncludedInLimit,
                        onChanged: state.isSaving
                            ? null
                            : (value) => _setIncluded(routine, app, value),
                      ),
                      IconButton(
                        tooltip: context.l10n.routineRemoveApp,
                        onPressed: state.isSaving
                            ? null
                            : () => _removeApp(routine, app),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
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
    final selected = await showModalBottomSheet<AppUsageSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D111A),
      builder: (context) => _RoutineAppSearch(
        apps: candidates
            .where((app) => !existingKeys.contains(app.appKey))
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    await _save(
      routine.copyWith(
        apps: [
          ...routine.apps,
          RoutineApp(appKey: selected.appKey, appName: selected.appName),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.routineKeepOneApp)));
      return;
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

class _RoutineAppSearch extends StatefulWidget {
  const _RoutineAppSearch({required this.apps});

  final List<AppUsageSummary> apps;

  @override
  State<_RoutineAppSearch> createState() => _RoutineAppSearchState();
}

class _RoutineAppSearchState extends State<_RoutineAppSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final apps =
        widget.apps
            .where(
              (app) =>
                  query.isEmpty ||
                  app.appName.toLowerCase().contains(query) ||
                  app.appKey.toLowerCase().contains(query),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
          );
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: context.l10n.routineEditorSearchApps,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: apps.isEmpty
                  ? Center(
                      child: Text(context.l10n.routineEditorNoMatchingApps),
                    )
                  : ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        return ListTile(
                          leading: AppIconAvatar(
                            appName: app.appName,
                            iconBytes: app.iconBytes,
                          ),
                          title: Text(app.appName),
                          onTap: () => Navigator.of(context).pop(app),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
