import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/app_usage_details_view_model.dart';
import '../widgets/app_icon_avatar.dart';
import '../widgets/trend_color.dart';

class UsageDetailsScreen extends ConsumerWidget {
  const UsageDetailsScreen({required this.request, super.key});

  final AppUsageDetailsRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUsageDetailsViewModelProvider(request));
    return Scaffold(
      appBar: AppBar(title: Text(request.summary.appName)),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.errorMessage != null
            ? _ErrorPanel(
                onRetry: () => ref
                    .read(appUsageDetailsViewModelProvider(request).notifier)
                    .load(),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AppSummaryHeader(request: request),
                  const SizedBox(height: 12),
                  if (request.rank != null) ...[
                    _RankBadge(request: request),
                    const SizedBox(height: 8),
                  ],
                  _ComparisonBadge(
                    changePercent: state.changeFromYesterdayPercent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.usageDetailsLastSevenDays,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _UsageBarChart(points: state.points),
                  if (request.platform == UsagePlatform.windows) ...[
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.sessionLongestTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (state.sessions.isEmpty)
                      Text(context.l10n.sessionNoneRecorded)
                    else
                      for (final session in state.sessions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule, size: 20),
                          title: Text(_sessionLabel(context, session)),
                        ),
                  ],
                ],
              ),
      ),
    );
  }

  String _sessionLabel(BuildContext context, UsageSession session) {
    final start = _clock(context, session.startedAt);
    final duration = context.l10n.compactDuration(session.duration);
    final endedAt = session.endedAt;
    if (endedAt == null) {
      return context.l10n.sessionOngoingLabel(start, duration);
    }
    return context.l10n.sessionRangeLabel(
      start,
      _clock(context, endedAt),
      duration,
    );
  }

  String _clock(BuildContext context, DateTime time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}

class _AppSummaryHeader extends StatelessWidget {
  const _AppSummaryHeader({required this.request});

  final AppUsageDetailsRequest request;

  @override
  Widget build(BuildContext context) {
    final summary = request.summary;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AppIconAvatar(
              appName: summary.appName,
              iconBytes: summary.iconBytes,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(request.selectedDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    context.l10n.compactDuration(summary.totalDuration),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (summary.launchCount > 0)
                    Text(
                      context.l10n.summaryLaunchCount(summary.launchCount),
                      style: Theme.of(context).textTheme.bodySmall,
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

/// `#1 most used · 2h 5m more than YouTube` for the day's top 3 apps.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.request});

  final AppUsageDetailsRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final runnerUpName = request.runnerUpName;
    final leadSeconds = request.leadSeconds;
    var text = context.l10n.usageDetailsRankLabel(request.rank!);
    if (runnerUpName != null && leadSeconds != null && leadSeconds > 0) {
      text +=
          ' · ${context.l10n.usageDetailsRankLead(context.l10n.compactDuration(Duration(seconds: leadSeconds)), runnerUpName)}';
    }

    return Semantics(
      label: text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonBadge extends StatelessWidget {
  const _ComparisonBadge({required this.changePercent});

  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = changePercent;
    final isUnavailable = value == null;
    final isFlat = value != null && value.abs() < 0.5;
    final isIncrease = value != null && value > 0;
    final color = trendColor(
      theme,
      isFlat: isUnavailable || isFlat,
      isIncrease: isIncrease,
    );
    final text = isUnavailable
        ? context.l10n.usageDetailsNoYesterdayComparison
        : isFlat
        ? context.l10n.usageDetailsSameAsYesterday
        : isIncrease
        ? context.l10n.usageDetailsMoreThanYesterday(value.abs().round())
        : context.l10n.usageDetailsLessThanYesterday(value.abs().round());

    return Semantics(
      label: text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isUnavailable || isFlat
                    ? Icons.remove
                    : isIncrease
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageBarChart extends StatelessWidget {
  const _UsageBarChart({required this.points});

  final List<DailyUsagePoint> points;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = points.fold<int>(
      0,
      (maximum, point) => math.max(maximum, point.durationSeconds),
    );
    final locale = Localizations.localeOf(context).toString();
    return Card(
      elevation: 0,
      child: SizedBox(
        height: 210,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in points)
                Expanded(
                  child: Semantics(
                    label: context.l10n.usageDetailsDayValue(
                      DateFormat.MMMd(locale).format(point.day),
                      context.l10n.compactDuration(point.duration),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (point.durationSeconds > 0)
                          FittedBox(
                            child: Text(
                              context.l10n.compactDuration(point.duration),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: 20,
                          height: maxSeconds == 0
                              ? 4
                              : (point.durationSeconds / maxSeconds * 120)
                                    .clamp(4, 120)
                                    .toDouble(),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          DateFormat.E(locale).format(point.day),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.commonRetry),
      ),
    );
  }
}
