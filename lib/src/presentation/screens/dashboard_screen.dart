import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/permission_card.dart';
import '../widgets/tracking_status_banner.dart';
import 'usage_bubble_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    final trackingState = ref.watch(trackingViewModelProvider);
    final trackingViewModel = ref.read(trackingViewModelProvider.notifier);
    ref.watch(restrictionsViewModelProvider);

    // Reload the dashboard on every tracking sample so the total climbs live.
    ref.listen(trackingViewModelProvider, (previous, next) {
      if (next.status.lastUpdatedAt != previous?.status.lastUpdatedAt) {
        dashboardViewModel.refreshSilently();
      }
    });

    return Scaffold(
      body: SafeArea(
        // The day header stays pinned; only the content below it scrolls.
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _DayHeader(
                state: dashboardState,
                viewModel: dashboardViewModel,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: dashboardViewModel.refresh,
                // Horizontal swipes page through days; vertical scroll and
                // pull-to-refresh keep working since they're separate axes.
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 300) {
                      dashboardViewModel.previousDay();
                    } else if (velocity < -300) {
                      // No-op on today: nextDay() is guarded in the view model.
                      dashboardViewModel.nextDay();
                    }
                  },
                  child: ListView(
                    primary: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (dashboardState.errorMessage == null &&
                          !dashboardState.isLoading &&
                          dashboardState.summaries.isNotEmpty) ...[
                        UsageBubbleScreen(
                          summaries: dashboardState.summaries,
                          trendsByAppKey: dashboardState.trendsByAppKey,
                          isToday: dashboardState.isToday,
                        ),
                        const SizedBox(height: 12),
                      ],
                      PermissionCard(
                        platform: dashboardState.platform,
                        hasUsageAccess: dashboardState.hasUsageAccess,
                        onOpenSettings:
                            dashboardViewModel.openPermissionSettings,
                        onRecheck: dashboardViewModel.checkPermission,
                      ),
                      if (dashboardState.platform == UsagePlatform.windows) ...[
                        const SizedBox(height: 12),
                        TrackingStatusBanner(status: trackingState.status),
                        const SizedBox(height: 12),
                        _TrackingControls(
                          isTracking: trackingState.status.isTracking,
                          isBusy: trackingState.isBusy,
                          onStart: () async {
                            await trackingViewModel.startTracking();
                            await dashboardViewModel.refresh();
                          },
                          onStop: () async {
                            await trackingViewModel.stopTracking();
                            await dashboardViewModel.refresh();
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.trackingRunsWhileOpen,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (dashboardState.platform != UsagePlatform.android &&
                          dashboardState.platform != UsagePlatform.windows) ...[
                        const SizedBox(height: 12),
                        const _UnsupportedPanel(),
                      ],
                      const SizedBox(height: 16),
                      if (dashboardState.errorMessage != null)
                        _ErrorPanel(
                          message: context.l10n.commonUnexpectedError,
                          onRetry: dashboardViewModel.refresh,
                        )
                      else if (dashboardState.isLoading)
                        const _LoadingPanel()
                      else if (dashboardState.summaries.isEmpty)
                        _EmptyPanel(isToday: dashboardState.isToday),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `<  Today · tracked 2h 15m  >` — steps through daily usage snapshots.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.state, required this.viewModel});

  final DashboardState state;
  final DashboardViewModel viewModel;

  String _title(BuildContext context) {
    switch (state.dayOffset) {
      case 0:
        return context.l10n.dashboardDayToday;
      case -1:
        return context.l10n.dashboardDayYesterday;
      default:
        return DateFormat.MMMEd(
          Localizations.localeOf(context).toString(),
        ).format(state.selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: context.l10n.dashboardPreviousDayTooltip,
          onPressed: viewModel.previousDay,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          // Tapping the day title scrolls the content back to the top.
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final controller = PrimaryScrollController.of(context);
              if (controller.hasClients) {
                controller.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: Column(
              children: [
                Text(
                  _title(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  context.l10n.dashboardDayTracked(
                    context.l10n.compactDuration(
                      Duration(seconds: state.totalDurationSeconds),
                    ),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.dashboardNextDayTooltip,
          onPressed: state.isToday ? null : viewModel.nextDay,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({
    required this.isTracking,
    required this.isBusy,
    required this.onStart,
    required this.onStop,
  });

  final bool isTracking;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isBusy ? null : (isTracking ? onStop : onStart),
      icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
      label: Text(
        isTracking
            ? context.l10n.dashboardStopTracking
            : context.l10n.dashboardStartTracking,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          isToday
              ? context.l10n.dashboardNoUsageToday
              : context.l10n.dashboardNoUsageDay,
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _UnsupportedPanel extends StatelessWidget {
  const _UnsupportedPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.dashboardUnsupportedPlatform),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
