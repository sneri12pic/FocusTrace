import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/repositories/report_repository.dart';
import '../providers.dart';

final restrictionWeekProvider = StateProvider<bool>((ref) => true);
final restrictionInsightsProvider = Provider<AsyncValue<RestrictionInsights>>(
  (ref) => ref.watch(
    restrictionPeriodInsightsProvider(ref.watch(restrictionWeekProvider)),
  ),
);
final restrictionPeriodInsightsProvider =
    FutureProvider.family<RestrictionInsights, bool>((ref, week) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = week
          ? DateTime(now.year, now.month, now.day - now.weekday + 1)
          : today;
      final source = await ref
          .watch(reportRepositoryProvider)
          .loadSourceData(from, now);
      // Icons are filled in by the widget as installed-app metadata arrives;
      // waiting for every launchable app's icon here delayed the whole screen.
      return RestrictionInsights.fromSource(source, from, now, average: week);
    });

class RestrictionInsights {
  const RestrictionInsights({
    required this.apps,
    required this.recordedDays,
    required this.hours,
    this.peakHour,
    this.suggestedApp,
  });
  final List<AppUsageSummary> apps;
  final int recordedDays;
  final List<int> hours;
  final int? peakHour;
  final AppUsageSummary? suggestedApp;

  RestrictionInsights withApps(List<AppUsageSummary> value) =>
      RestrictionInsights(
        apps: value,
        recordedDays: recordedDays,
        hours: hours,
        peakHour: peakHour,
        suggestedApp: suggestedApp,
      );

  factory RestrictionInsights.fromSource(
    UsageReportSourceData source,
    DateTime from,
    DateTime until, {
    required bool average,
  }) {
    final days = <DateTime>{};
    final totals = <String, AppUsageSummary>{};
    for (final row in source.dailyUsage) {
      final day = DateTime(row.day.year, row.day.month, row.day.day);
      if (day.isBefore(from) || day.isAfter(until)) continue;
      days.add(day);
      final app = row.summary;
      totals[app.appKey] = app.copyWith(
        totalDurationSeconds:
            (totals[app.appKey]?.totalDurationSeconds ?? 0) +
            app.totalDurationSeconds,
      );
    }
    final apps = [
      for (final app in totals.values)
        app.copyWith(
          totalDurationSeconds: average && days.isNotEmpty
              ? (app.totalDurationSeconds / days.length).round()
              : app.totalDurationSeconds,
        ),
    ]..sort((a, b) => b.totalDurationSeconds.compareTo(a.totalDurationSeconds));
    final hours = List.filled(24, 0);
    final perApp = <String, List<int>>{};
    // Split actual intervals at local hour boundaries; do not distribute daily totals.
    for (final interval in source.intervals) {
      if (!totals.containsKey(interval.appKey)) continue;
      var start = interval.startedAt.isBefore(from) ? from : interval.startedAt;
      final end = interval.endedAt.isAfter(until) ? until : interval.endedAt;
      final appHours = perApp.putIfAbsent(
        interval.appKey,
        () => List.filled(24, 0),
      );
      while (start.isBefore(end)) {
        final boundary = start.add(
          Duration(
            minutes: 60 - start.minute,
            seconds: -start.second,
            milliseconds: -start.millisecond,
            microseconds: -start.microsecond,
          ),
        );
        final stop = boundary.isBefore(end) ? boundary : end;
        final seconds = stop.difference(start).inSeconds;
        hours[start.hour] += seconds;
        appHours[start.hour] += seconds;
        start = stop;
      }
    }
    int? peak;
    var best = 0;
    for (var h = 0; h < 24; h++) {
      final total = hours[h] + hours[(h + 1) % 24] + hours[(h + 2) % 24];
      if (total > best) {
        best = total;
        peak = h;
      }
    }
    // A few seconds of observed activity do not justify a recommendation.
    if (best < 15 * 60) peak = null;
    AppUsageSummary? suggested;
    if (peak != null) {
      var highest = 0;
      for (final entry in perApp.entries) {
        final score =
            entry.value[peak] +
            entry.value[(peak + 1) % 24] +
            entry.value[(peak + 2) % 24];
        if (score > highest) {
          highest = score;
          suggested = totals[entry.key];
        }
      }
    }
    return RestrictionInsights(
      apps: apps,
      recordedDays: days.length,
      hours: hours,
      peakHour: peak,
      suggestedApp: suggested,
    );
  }
}
