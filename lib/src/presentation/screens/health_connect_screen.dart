import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../domain/models/health_connect.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';

/// Settings for the optional Health Connect workout import, and the imported
/// workouts themselves so the user can see it working.
class HealthConnectScreen extends ConsumerStatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  ConsumerState<HealthConnectScreen> createState() =>
      _HealthConnectScreenState();
}

class _HealthConnectScreenState extends ConsumerState<HealthConnectScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Access may have changed in Health Connect while the user was there.
    if (state == AppLifecycleState.resumed) {
      ref.read(healthConnectViewModelProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthConnectViewModelProvider);
    final viewModel = ref.read(healthConnectViewModelProvider.notifier);
    final status = state.status;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );
    final available =
        status.availability == HealthConnectAvailability.available;
    final canImport = available && status.enabled && status.readGranted;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthConnectTitle)),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Text(l10n.healthConnectIntro, style: muted),
                const SizedBox(height: 16),
                if (status.availability ==
                    HealthConnectAvailability.unavailable)
                  _Notice(text: l10n.healthConnectUnavailable)
                else if (status.availability ==
                    HealthConnectAvailability.updateRequired)
                  _Notice(
                    text: l10n.healthConnectUpdateRequired,
                    action: l10n.healthConnectGetApp,
                    onAction: viewModel.openPermissionSettings,
                  )
                else ...[
                  Card(
                    elevation: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          key: const ValueKey('health-connect-enabled'),
                          title: Text(l10n.healthConnectImportSwitch),
                          value: status.enabled,
                          onChanged: state.isBusy
                              ? null
                              : (on) => on
                                    ? viewModel.enable()
                                    : viewModel.disable(),
                        ),
                        if (status.enabled) ...[
                          SwitchListTile(
                            key: const ValueKey('health-connect-auto'),
                            title: Text(l10n.healthConnectAutoImport),
                            subtitle: Text(
                              status.backgroundSupported
                                  ? l10n.healthConnectAutoImportBody
                                  : l10n.healthConnectAutoImportUnsupported,
                            ),
                            value:
                                status.autoImport && status.backgroundSupported,
                            onChanged:
                                state.isBusy || !status.backgroundSupported
                                ? null
                                : viewModel.setAutoImport,
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: _StatusLines(status: status),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: Row(
                              children: [
                                FilledButton.tonal(
                                  key: const ValueKey('health-connect-import'),
                                  onPressed: canImport && !state.isBusy
                                      ? viewModel.importNow
                                      : null,
                                  child: Text(l10n.healthConnectImportNow),
                                ),
                                const SizedBox(width: 12),
                                if (state.isBusy)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (status.accessRevoked) ...[
                    const SizedBox(height: 12),
                    _Notice(
                      text: l10n.healthConnectRevoked,
                      action: l10n.healthConnectGrantAgain,
                      onAction: state.isBusy ? null : viewModel.enable,
                      isWarning: true,
                    ),
                  ] else if (status.autoImportBlocked) ...[
                    const SizedBox(height: 12),
                    _Notice(
                      text: l10n.healthConnectAutoImportBlocked,
                      isWarning: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(l10n.healthConnectManage),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: viewModel.openPermissionSettings,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.healthConnectOffNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  l10n.healthConnectDataTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(l10n.healthConnectDataBody, style: muted),
                if (available) ...[
                  const SizedBox(height: 20),
                  Text(
                    l10n.healthConnectWorkoutsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (state.workouts.isEmpty)
                    Text(l10n.healthConnectNoWorkouts, style: muted)
                  else
                    Card(
                      elevation: 0,
                      child: Column(
                        children: [
                          for (final workout in state.workouts)
                            _WorkoutTile(workout: workout),
                        ],
                      ),
                    ),
                  if (status.workoutCount > 0) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const ValueKey('health-connect-delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.healthConnectDeleteImported),
                      onPressed: state.isBusy
                          ? null
                          : () => _confirmDelete(context),
                    ),
                  ],
                ],
                if (state.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.commonUnexpectedError,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.healthConnectDeleteTitle),
        content: Text(l10n.healthConnectDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.healthConnectDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(healthConnectViewModelProvider.notifier).deleteImported();
    }
  }
}

/// Last success and what the last attempt ended with, failures in red.
class _StatusLines extends StatelessWidget {
  const _StatusLines({required this.status});

  final HealthConnectStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lastSuccess = status.lastSuccess;
    final outcome = status.lastOutcome;
    final outcomeText = switch (outcome) {
      null => null,
      HealthConnectOutcome.imported => l10n.healthConnectOutcomeImported(
        status.lastImportedCount,
      ),
      HealthConnectOutcome.noNew => l10n.healthConnectOutcomeNoNew,
      HealthConnectOutcome.unavailable || HealthConnectOutcome.updateRequired =>
        l10n.healthConnectOutcomeUnavailable,
      HealthConnectOutcome.permissionMissing =>
        l10n.healthConnectOutcomePermission,
      HealthConnectOutcome.backgroundPermissionMissing =>
        l10n.healthConnectOutcomeBackground,
      HealthConnectOutcome.failed => l10n.healthConnectOutcomeFailed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lastSuccess == null
              ? l10n.healthConnectNeverImported
              : l10n.healthConnectLastSuccess(
                  DateFormat.yMMMd(locale).add_jm().format(lastSuccess),
                ),
          key: const ValueKey('health-connect-last-success'),
        ),
        if (outcomeText != null)
          Text(
            outcomeText,
            key: const ValueKey('health-connect-outcome'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: outcome!.isSuccess
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout});

  final ImportedWorkout workout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final title = workout.title?.trim();
    return ListTile(
      leading: Icon(_icon(workout.category)),
      title: Text(
        title == null || title.isEmpty
            ? workoutCategoryLabel(l10n, workout.category)
            : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${DateFormat.MMMd(locale).add_jm().format(workout.start)}\n'
        '${l10n.healthConnectWorkoutSource(l10n.compactDuration(workout.duration), workout.sourceName)}',
      ),
      isThreeLine: true,
    );
  }

  static IconData _icon(WorkoutCategory category) => switch (category) {
    WorkoutCategory.strength => Icons.fitness_center,
    WorkoutCategory.running => Icons.directions_run,
    WorkoutCategory.walking => Icons.directions_walk,
    WorkoutCategory.cycling => Icons.directions_bike,
    WorkoutCategory.swimming => Icons.pool,
    WorkoutCategory.yoga => Icons.self_improvement,
    WorkoutCategory.other => Icons.sports_gymnastics,
  };
}

String workoutCategoryLabel(AppLocalizations l10n, WorkoutCategory category) =>
    switch (category) {
      WorkoutCategory.strength => l10n.workoutStrength,
      WorkoutCategory.running => l10n.workoutRunning,
      WorkoutCategory.walking => l10n.workoutWalking,
      WorkoutCategory.cycling => l10n.workoutCycling,
      WorkoutCategory.swimming => l10n.workoutSwimming,
      WorkoutCategory.yoga => l10n.workoutYoga,
      WorkoutCategory.other => l10n.workoutOther,
    };

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    this.action,
    this.onAction,
    this.isWarning = false,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: isWarning ? scheme.errorContainer.withValues(alpha: 0.35) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            if (action != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
