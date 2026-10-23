import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/restriction_rule.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../screens/restriction_editor_sheet.dart';
import '../view_models/restriction_insights.dart';
import 'app_icon_avatar.dart';

/// Icons for usage rows: installed-app metadata first, then dashboard rows.
Map<String, Uint8List> _icons(WidgetRef ref) => {
  for (final app
      in ref.watch(installedAppsProvider).valueOrNull ??
          const <AppUsageSummary>[])
    if (app.iconBytes != null) app.appKey: app.iconBytes!,
  for (final app in ref.watch(dashboardViewModelProvider).summaries)
    if (app.iconBytes != null) app.appKey: app.iconBytes!,
};

/// "Choose apps to limit": one route to every app (the search field) plus the
/// three most-used apps of the selected period.
class ChooseAppsSection extends ConsumerWidget {
  const ChooseAppsSection({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(restrictionWeekProvider);
    final insights = ref.watch(restrictionInsightsProvider);
    final rules = ref.watch(restrictionsViewModelProvider).rules;
    final icons = _icons(ref);
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.rxChooseApps,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        // Looks like a search field; opens the full, filterable app picker.
        Material(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            key: const ValueKey('restriction-search-all'),
            borderRadius: BorderRadius.circular(12),
            onTap: onSearch,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.rxSearchAll, style: muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (value, label) in [
              (false, l.dashboardDayToday),
              (true, l.rxWeek),
            ])
              Expanded(
                child: _Tab(
                  label: label,
                  selected: week == value,
                  onTap: () =>
                      ref.read(restrictionWeekProvider.notifier).state = value,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        insights.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  ref.invalidate(restrictionPeriodInsightsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l.rxRetry),
            ),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Today is a running total; This week is an average over the
              // days that were actually recorded.
              Text(
                week
                    ? (data.recordedDays > 0
                          ? l.rxAverage(data.recordedDays)
                          : '')
                    : l.rxTodayUsage,
                style: theme.textTheme.bodySmall?.merge(muted),
              ),
              if (data.apps.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.rxNoUsage, style: muted),
                ),
              for (final app in data.apps.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AppIconAvatar(
                        appName: app.appName,
                        iconBytes: app.iconBytes ?? icons[app.appKey],
                        size: 40,
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
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              week
                                  ? l.rxPerDay(
                                      l.compactDuration(app.totalDuration),
                                    )
                                  : l.compactDuration(app.totalDuration),
                              style: theme.textTheme.bodyMedium?.merge(muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => createRestrictionForApp(
                          context,
                          ref,
                          appKey: app.appKey,
                          appName: app.appName,
                        ),
                        child: Text(
                          rules.any((r) => r.appKey == app.appKey)
                              ? l.rxEdit
                              : '+ ${l.rxLimit}',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: selected ? 2 : 1,
                color: selected ? colors.primary : colors.outlineVariant,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hourly usage for the selected period, its busiest three-hour window and
/// an editable schedule suggestion for that window.
class BusiestHoursCard extends ConsumerWidget {
  const BusiestHoursCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(restrictionInsightsProvider).asData?.value;
    if (data == null) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Compact hours ("9 PM", or "21" on a 24-hour clock).
    final hourFormat = MediaQuery.alwaysUse24HourFormatOf(context)
        ? DateFormat.H(Localizations.localeOf(context).toString())
        : DateFormat.j(Localizations.localeOf(context).toString());
    String hourLabel(int hour) => hourFormat.format(DateTime(2000, 1, 1, hour));
    final peak = data.peakHour;
    final max = data.hours.fold(0, math.max);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flex(
              direction: MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? Axis.vertical
                  : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  flex: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 0 : 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      l.rxBusiest,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (peak != null && data.suggestedApp != null)
                  TextButton.icon(
                    onPressed: () {
                      final app = data.suggestedApp!;
                      createRestrictionForApp(
                        context,
                        ref,
                        appKey: app.appKey,
                        appName: app.appName,
                        initial: RestrictionRule.schedule(
                          appKey: app.appKey,
                          appName: app.appName,
                          startMinute: peak * 60,
                          endMinute: ((peak + 3) % 24) * 60,
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: Text(l.rxPlanBlock),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: peak == null
                  ? Text(l.rxNoInsights, style: TextStyle(color: muted))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${hourLabel(peak)} – ${hourLabel((peak + 3) % 24)}',
                          semanticsLabel: l.rxPeak(
                            hourLabel(peak),
                            hourLabel((peak + 3) % 24),
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var hour = 0; hour < 24; hour++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    child: Tooltip(
                                      message:
                                          '${hourLabel(hour)}: ${l.compactDuration(Duration(seconds: data.hours[hour]))}',
                                      child: Container(
                                        height: math.max(
                                          4,
                                          48 *
                                              data.hours[hour] /
                                              math.max(1, max),
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          color: (hour - peak + 24) % 24 < 3
                                              ? theme.colorScheme.primary
                                              : theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // A label every six hours, centred under its own bar.
                        Row(
                          children: [
                            for (var hour = 0; hour < 24; hour++)
                              Expanded(
                                child: SizedBox(
                                  height: MediaQuery.textScalerOf(
                                    context,
                                  ).scale(16),
                                  child: hour % 6 == 0
                                      ? OverflowBox(
                                          maxWidth: 56,
                                          alignment: hour == 0
                                              ? AlignmentDirectional.centerStart
                                              : Alignment.center,
                                          child: Text(
                                            hourLabel(hour),
                                            maxLines: 1,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(color: muted),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                          ],
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
