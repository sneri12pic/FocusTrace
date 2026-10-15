import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_details_chart.dart';
import '../../domain/models/usage_item.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../view_models/app_usage_details_view_model.dart';
import '../widgets/app_icon_avatar.dart';
import '../widgets/app_category_widgets.dart';
import '../widgets/trend_color.dart';
import '../widgets/usage_calendar.dart';
import '../widgets/usage_details_charts.dart';

class UsageDetailsScreen extends ConsumerWidget {
  const UsageDetailsScreen({required this.request, super.key});

  final AppUsageDetailsRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUsageDetailsViewModelProvider(request));
    final overrides =
        ref.watch(appCategoriesViewModelProvider).asData?.value ??
        const <String, UsageCategory>{};
    // Productivity apps are "good": more use reads as green, not red.
    final isGood =
        resolveUsageCategory(request.summary, overrides) ==
        UsageCategory.productivity;
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
            : Theme(
                // One card style for every surface on this screen: flat,
                // softly rounded, and flush with the badges' 16px gutter.
                data: Theme.of(context).copyWith(
                  cardTheme: CardThemeData(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _AppSummaryHeader(request: request, isGood: isGood),
                    const SizedBox(height: 12),
                    AppCategoryTag(request.summary),
                    const SizedBox(height: 12),
                    if (request.rank != null) ...[
                      _RankBadge(request: request),
                      const SizedBox(height: 8),
                    ],
                    _ComparisonBadge(
                      changePercent: state.changeFromYesterdayPercent,
                      isGood: isGood,
                    ),
                    const SizedBox(height: 16),
                    UsageDetailsCharts(
                      points: state.points,
                      period: state.period,
                      chart: state.chart,
                      isGood: isGood,
                      selector: _PeriodSelector(
                        selected: state.period,
                        onSelected: (period) => ref
                            .read(
                              appUsageDetailsViewModelProvider(
                                request,
                              ).notifier,
                            )
                            .selectPeriod(period),
                      ),
                      total: Text(
                        context.l10n.compactDuration(state.totalDuration),
                        key: const ValueKey('usage-period-total'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      onChartChanged: (chart) =>
                          _selectChart(context, ref, chart),
                    ),
                    const SizedBox(height: 8),
                    _CalendarSection(request: request, isGood: isGood),
                    if (request.platform == UsagePlatform.windows) ...[
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.sessionLongestTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
      ),
    );
  }

  Future<void> _selectChart(
    BuildContext context,
    WidgetRef ref,
    UsageDetailsChart chart,
  ) async {
    final saved = await ref
        .read(appUsageDetailsViewModelProvider(request).notifier)
        .selectChart(chart);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.usageDetailsChartSaveError)),
      );
    }
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

String _periodLabel(BuildContext context, UsageDetailsPeriod period) {
  return switch (period) {
    UsageDetailsPeriod.sevenDays => context.l10n.usageDetailsPeriodSevenDays,
    UsageDetailsPeriod.twoWeeks => context.l10n.usageDetailsPeriodTwoWeeks,
    UsageDetailsPeriod.month => context.l10n.usageDetailsPeriodMonth,
    UsageDetailsPeriod.year => context.l10n.usageDetailsPeriodYear,
  };
}

/// A tonal chip naming the active range; tapping it opens a rounded menu
/// with every range and a check on the current one.
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final UsageDetailsPeriod selected;
  final ValueChanged<UsageDetailsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w400,
    );
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(2),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      menuChildren: [
        for (final period in UsageDetailsPeriod.values)
          MenuItemButton(
            leadingIcon: Icon(
              Icons.check_rounded,
              size: 18,
              color: period == selected ? scheme.primary : Colors.transparent,
            ),
            onPressed: () {
              if (period != selected) onSelected(period);
            },
            child: Text(_periodLabel(context, period), style: labelStyle),
          ),
      ],
      builder: (context, controller, _) => ActionChip(
        key: const ValueKey('usage-period-dropdown'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        avatar: Icon(Icons.date_range_rounded, size: 18, color: scheme.primary),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_periodLabel(context, selected), style: labelStyle),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 18, color: scheme.primary),
          ],
        ),
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// The selected day's summary, with the shown month's stats beneath it.
class _AppSummaryHeader extends ConsumerWidget {
  const _AppSummaryHeader({required this.request, required this.isGood});

  final AppUsageDetailsRequest request;
  final bool isGood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = request.summary;
    final theme = Theme.of(context);
    final calendar = ref.watch(appUsageCalendarViewModelProvider(request));
    // Only the very first load hides the month; later loads keep the shown
    // month in place until the next one is ready.
    final showMonth =
        calendar.errorMessage == null &&
        !(calendar.isLoading &&
            calendar.days.isEmpty &&
            calendar.previousDays.isEmpty);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _daySummary(context, summary),
          ),
          if (showMonth)
            // A deeper tint marks the monthly half as supporting detail.
            ColoredBox(
              color: theme.colorScheme.surfaceContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      DateFormat.yMMMM(
                        Localizations.localeOf(context).toString(),
                      ).format(calendar.month),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  UsageMonthStats(state: calendar, isGood: isGood),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _daySummary(BuildContext context, AppUsageSummary summary) {
    return Row(
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 20, color: color),
              const SizedBox(width: 10),
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
  const _ComparisonBadge({required this.changePercent, required this.isGood});

  final double? changePercent;
  final bool isGood;

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
      isIncrease: isGood ? !isIncrease : isIncrease,
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                isUnavailable || isFlat
                    ? Icons.remove
                    : isIncrease
                    ? Icons.trending_up
                    : Icons.trending_down,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 10),
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

/// Month stats, the usage calendar, and the selected day's details.
class _CalendarSection extends ConsumerWidget {
  const _CalendarSection({required this.request, required this.isGood});

  final AppUsageDetailsRequest request;
  final bool isGood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUsageCalendarViewModelProvider(request));
    final viewModel = ref.read(
      appUsageCalendarViewModelProvider(request).notifier,
    );
    if (state.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _ErrorPanel(onRetry: viewModel.load),
      );
    }
    final selectedDay = state.selectedDay;
    final showDay =
        selectedDay != null &&
        selectedDay.year == state.month.year &&
        selectedDay.month == state.month.month;
    return Column(
      children: [
        UsageCalendar(
          state: state,
          isGood: isGood,
          onPreviousMonth: viewModel.showPreviousMonth,
          onNextMonth: viewModel.showNextMonth,
          onDaySelected: viewModel.selectDay,
        ),
        if (showDay) ...[
          const SizedBox(height: 12),
          UsageDayPanel(state: state, day: selectedDay, isGood: isGood),
        ],
      ],
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
