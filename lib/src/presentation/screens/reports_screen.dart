import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/restriction_event.dart';
import '../../domain/models/usage_report.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsViewModelProvider);
    final viewModel = ref.read(reportsViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reportsTitle)),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          key: const ValueKey('reports-scroll-view'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _PeriodSelector(
              selected: state.period,
              onSelected: viewModel.selectPeriod,
            ),
            const SizedBox(height: 16),
            if (state.isLoading && state.report == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage != null)
              _MessageCard(
                icon: Icons.error_outline,
                text: context.l10n.commonUnexpectedError,
              )
            else if (state.report case final report?) ...[
              _RangeLabel(report: report),
              const SizedBox(height: 12),
              if (report.isEmpty)
                _MessageCard(
                  icon: Icons.insights_outlined,
                  text: context.l10n.reportsEmpty,
                )
              else ...[
                _SummaryCards(report: report),
                const SizedBox(height: 12),
                _TimeOfDayCard(report: report),
                const SizedBox(height: 12),
                _HabitCard(report: report),
                const SizedBox(height: 12),
                if (report.topApps.isNotEmpty) ...[
                  _TopAppsCard(report: report),
                  const SizedBox(height: 12),
                ],
                _RestrictionActivityCard(report: report),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final UsageReportPeriod selected;
  final ValueChanged<UsageReportPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UsageReportPeriod>(
      key: const ValueKey('report-period-selector'),
      segments: [
        ButtonSegment(
          value: UsageReportPeriod.weekly,
          label: Text(context.l10n.reportsWeekly),
        ),
        ButtonSegment(
          value: UsageReportPeriod.monthly,
          label: Text(context.l10n.reportsMonthly),
        ),
        ButtonSegment(
          value: UsageReportPeriod.yearly,
          label: Text(context.l10n.reportsYearly),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSelected(selection.single),
    );
  }
}

class _RangeLabel extends StatelessWidget {
  const _RangeLabel({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat.yMMMd(locale);
    final lastDay = report.toExclusive.subtract(const Duration(days: 1));
    return Text(
      '${formatter.format(report.fromInclusive)} – ${formatter.format(lastDay)}',
      style: Theme.of(context).textTheme.titleSmall,
      textAlign: TextAlign.center,
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: context.l10n.reportsTotalUsage,
            value: context.l10n.compactDuration(
              Duration(seconds: report.totalDurationSeconds),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: context.l10n.reportsDailyAverage,
            value: context.l10n.compactDuration(
              Duration(seconds: report.averageDailyDurationSeconds),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: context.l10n.reportsActiveDays,
            value: '${report.activeDays}',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOfDayCard extends StatelessWidget {
  const _TimeOfDayCard({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    final values = report.hourlyDurationSeconds.sublist(4);
    final maxValue = values.fold<int>(0, math.max);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.reportsTimeOfDayTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < values.length; index++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: maxValue == 0
                                      ? 0
                                      : values[index] / maxValue,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3),
                                      ),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              index % 4 == 0 ? '${index + 4}' : '',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
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

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    final peakHour = report.peakUsageHour;
    final firstUseMinute = report.averageFirstUseMinute;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(context.l10n.reportsHabitTitle),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(context.l10n.reportsPeakTime),
              trailing: Text(
                peakHour == null
                    ? '—'
                    : '${_clockHour(peakHour)}–${_clockHour(peakHour + 1)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: Text(context.l10n.reportsFirstUse),
              trailing: Text(
                firstUseMinute == null ? '—' : _clockMinute(firstUseMinute),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.apps_outlined),
              title: Text(context.l10n.reportsFirstApp),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  report.mostCommonFirstAppName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timeline_outlined),
              title: Text(context.l10n.reportsConsistency),
              trailing: Text(
                report.firstUseVariationMinutes == null
                    ? '—'
                    : context.l10n.reportsVariationMinutes(
                        report.firstUseVariationMinutes!,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                context.l10n.reportsWakeHeuristic,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(context.l10n.reportsTopApps),
            for (var index = 0; index < report.topApps.length; index++)
              ListTile(
                dense: true,
                leading: Text('#${index + 1}'),
                title: Text(report.topApps[index].appName),
                trailing: Text(
                  context.l10n.compactDuration(
                    report.topApps[index].totalDuration,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestrictionActivityCard extends StatelessWidget {
  const _RestrictionActivityCard({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(context.l10n.reportsRestrictionsTitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _EventCount(
                      label: context.l10n.reportsBlockedAttempts,
                      count: report.blockedCount,
                    ),
                  ),
                  Expanded(
                    child: _EventCount(
                      label: context.l10n.reportsManualUnblocks,
                      count: report.unblockedCount,
                    ),
                  ),
                ],
              ),
            ),
            for (final event in report.restrictionEvents.take(5))
              ListTile(
                dense: true,
                leading: Icon(
                  event.type == RestrictionEventType.blocked
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined,
                ),
                title: Text(event.appName),
                subtitle: Text(
                  event.type == RestrictionEventType.blocked
                      ? context.l10n.reportsBlocked
                      : context.l10n.reportsUnblocked,
                ),
                trailing: Text(
                  DateFormat.MMMd(
                    Localizations.localeOf(context).toString(),
                  ).add_Hm().format(event.occurredAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCount extends StatelessWidget {
  const _EventCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _clockHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

String _clockMinute(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
