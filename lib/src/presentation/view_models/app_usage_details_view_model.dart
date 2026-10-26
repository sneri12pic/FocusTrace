import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/models/usage_details_chart.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/usage_repository.dart';
import '../../data/repositories/os_usage_history_repository.dart';

class AppUsageDetailsRequest {
  const AppUsageDetailsRequest({
    required this.summary,
    required this.selectedDate,
    required this.platform,
    this.rank,
    this.runnerUpName,
    this.leadSeconds,
  });

  final AppUsageSummary summary;
  final DateTime selectedDate;
  final UsagePlatform platform;

  /// 1-based place among the day's apps; only set for the top 3.
  final int? rank;

  /// The next-placed app's name and how far ahead this app is, when known.
  final String? runnerUpName;
  final int? leadSeconds;

  @override
  bool operator ==(Object other) {
    return other is AppUsageDetailsRequest &&
        other.summary == summary &&
        other.selectedDate == selectedDate &&
        other.platform == platform &&
        other.rank == rank &&
        other.runnerUpName == runnerUpName &&
        other.leadSeconds == leadSeconds;
  }

  @override
  int get hashCode => Object.hash(
    summary,
    selectedDate,
    platform,
    rank,
    runnerUpName,
    leadSeconds,
  );
}

class DailyUsagePoint {
  const DailyUsagePoint({
    required this.day,
    required this.durationSeconds,
    this.isApproximate = false,
  });

  final DateTime day;
  final int durationSeconds;

  /// Filled from Android's aggregated history, not precisely recorded.
  final bool isApproximate;

  Duration get duration => Duration(seconds: durationSeconds);
}

enum UsageDetailsPeriod {
  sevenDays,
  twoWeeks,
  month,
  year;

  DateTime startDate(DateTime selectedDay) {
    return switch (this) {
      // Calendar arithmetic: a Duration of days drifts off midnight across DST.
      UsageDetailsPeriod.sevenDays => _shiftDays(selectedDay, -6),
      UsageDetailsPeriod.twoWeeks => _shiftDays(selectedDay, -13),
      UsageDetailsPeriod.month => _shiftDays(selectedDay, -29),
      UsageDetailsPeriod.year => DateTime(
        selectedDay.year,
        selectedDay.month - 11,
      ),
    };
  }
}

DateTime _shiftDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

class AppUsageDetailsState {
  const AppUsageDetailsState({
    this.points = const <DailyUsagePoint>[],
    this.sessions = const <UsageSession>[],
    this.period = UsageDetailsPeriod.sevenDays,
    this.chart = UsageDetailsChart.bars,
    this.changeFromYesterdayPercent,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<DailyUsagePoint> points;
  final List<UsageSession> sessions;
  final UsageDetailsPeriod period;
  final UsageDetailsChart chart;
  final double? changeFromYesterdayPercent;
  final bool isLoading;
  final String? errorMessage;

  bool get hasApproximate => points.any((point) => point.isApproximate);

  int get totalDurationSeconds =>
      points.fold(0, (total, point) => total + point.durationSeconds);

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);

  AppUsageDetailsState withChart(UsageDetailsChart chart) {
    return AppUsageDetailsState(
      points: points,
      sessions: sessions,
      period: period,
      chart: chart,
      changeFromYesterdayPercent: changeFromYesterdayPercent,
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AppUsageDetailsViewModel extends StateNotifier<AppUsageDetailsState> {
  AppUsageDetailsViewModel({
    required UsageRepository usageRepository,
    required SettingsRepository settingsRepository,
    required AppUsageDetailsRequest request,
    OsUsageHistoryRepository? osHistory,
  }) : _usageRepository = usageRepository,
       _settingsRepository = settingsRepository,
       _request = request,
       _osHistory = osHistory,
       super(const AppUsageDetailsState(isLoading: true));

  final UsageRepository _usageRepository;
  final SettingsRepository _settingsRepository;
  final AppUsageDetailsRequest _request;
  final OsUsageHistoryRepository? _osHistory;
  bool _chartLoaded = false;
  int _loadGeneration = 0;
  Future<void> _pendingChartSave = Future<void>.value();

  Future<bool> selectChart(UsageDetailsChart chart) async {
    _chartLoaded = true;
    state = state.withChart(chart);
    // Preserve the final swipe even when storage writes finish at different speeds.
    final save = _pendingChartSave.then(
      (_) => _settingsRepository.setUsageDetailsChart(chart),
    );
    _pendingChartSave = save.catchError((Object _) {});
    try {
      await save;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> selectPeriod(UsageDetailsPeriod period) {
    if (period == state.period) {
      return Future<void>.value();
    }
    return load(period: period);
  }

  Future<void> load({UsageDetailsPeriod? period}) async {
    final generation = ++_loadGeneration;
    final selectedPeriod = period ?? state.period;
    state = AppUsageDetailsState(
      period: selectedPeriod,
      chart: state.chart,
      isLoading: true,
    );
    final selectedDay = _day(_request.selectedDate);
    try {
      final historyFuture = _usageRepository.getUsageHistory(
        selectedPeriod.startDate(selectedDay),
        _shiftDays(selectedDay, 1),
      );
      final sessionsFuture = _usageRepository.topSessionsForApp(
        _request.summary.appKey,
        selectedDay,
      );
      final preferenceFuture = _chartLoaded
          ? Future<UsageDetailsChart>.value(state.chart)
          : _settingsRepository.usageDetailsChart().catchError(
              (Object _) => UsageDetailsChart.bars,
            );
      final (history, sessions, savedChart, approximate) = await (
        historyFuture,
        sessionsFuture,
        preferenceFuture,
        _approximateHistory(selectedPeriod, selectedDay),
      ).wait;
      if (!mounted || generation != _loadGeneration) return;
      final chart = _chartLoaded ? state.chart : savedChart;
      _chartLoaded = true;
      final totalsByDay = <DateTime, int>{};
      for (final entry in history) {
        if (entry.summary.appKey != _request.summary.appKey) {
          continue;
        }
        final day = _day(entry.day);
        totalsByDay.update(
          day,
          (total) => total + entry.summary.totalDurationSeconds,
          ifAbsent: () => entry.summary.totalDurationSeconds,
        );
      }
      // The selected list row is the freshest value and can be newer than the
      // best-effort SQLite snapshot.
      totalsByDay[selectedDay] = _request.summary.totalDurationSeconds;

      // Yesterday's comparison uses recorded usage only.
      final current = totalsByDay[selectedDay] ?? 0;
      final previous = totalsByDay[_shiftDays(selectedDay, -1)] ?? 0;
      // A day with no rows for any app was not recorded, so Android's
      // aggregated total may stand in for it. A recorded day where this app
      // has no row really was zero.
      final recordedDays = {
        for (final entry in history) _day(entry.day),
        selectedDay,
      };
      final approximateDays = <DateTime>{};
      approximate.days.forEach((day, seconds) {
        if (!recordedDays.contains(day)) {
          totalsByDay[day] = seconds;
          approximateDays.add(day);
        }
      });
      final points = _pointsFor(
        period: selectedPeriod,
        selectedDay: selectedDay,
        totalsByDay: totalsByDay,
        recordedDays: recordedDays,
        approximateDays: approximateDays,
        approximateMonths: approximate.months,
      );
      state = AppUsageDetailsState(
        points: points,
        sessions: sessions,
        period: selectedPeriod,
        chart: chart,
        changeFromYesterdayPercent: _changePercent(current, previous),
      );
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = AppUsageDetailsState(
        period: selectedPeriod,
        chart: state.chart,
        errorMessage: error.toString(),
      );
    }
  }

  /// Android's aggregated totals for this app over [period], empty when no
  /// history repository is available. Monthly buckets matter only for a year.
  Future<({Map<DateTime, int> days, Map<DateTime, int> months})>
  _approximateHistory(UsageDetailsPeriod period, DateTime selectedDay) async {
    final osHistory = _osHistory;
    if (osHistory == null) {
      return (days: <DateTime, int>{}, months: <DateTime, int>{});
    }
    await osHistory.importOnce();
    final from = period.startDate(selectedDay);
    final to = _shiftDays(selectedDay, 1);
    final appKey = _request.summary.appKey;
    final (days, months) = await (
      osHistory.dailySeconds(appKey, from, to),
      period == UsageDetailsPeriod.year
          ? osHistory.monthlySeconds(appKey, from, to)
          : Future.value(<DateTime, int>{}),
    ).wait;
    return (days: days, months: months);
  }

  List<DailyUsagePoint> _pointsFor({
    required UsageDetailsPeriod period,
    required DateTime selectedDay,
    required Map<DateTime, int> totalsByDay,
    required Set<DateTime> recordedDays,
    required Set<DateTime> approximateDays,
    required Map<DateTime, int> approximateMonths,
  }) {
    final startDate = period.startDate(selectedDay);
    if (period == UsageDetailsPeriod.year) {
      return [
        for (var monthOffset = 0; monthOffset < 12; monthOffset++)
          _monthPoint(
            DateTime(startDate.year, startDate.month + monthOffset),
            totalsByDay: totalsByDay,
            recordedDays: recordedDays,
            approximateDays: approximateDays,
            approximateMonths: approximateMonths,
          ),
      ];
    }

    return [
      for (
        var day = startDate;
        !day.isAfter(selectedDay);
        day = _shiftDays(day, 1)
      )
        DailyUsagePoint(
          day: day,
          durationSeconds: totalsByDay[day] ?? 0,
          isApproximate: approximateDays.contains(day),
        ),
    ];
  }

  DailyUsagePoint _monthPoint(
    DateTime month, {
    required Map<DateTime, int> totalsByDay,
    required Set<DateTime> recordedDays,
    required Set<DateTime> approximateDays,
    required Map<DateTime, int> approximateMonths,
  }) {
    bool inMonth(DateTime day) =>
        day.year == month.year && day.month == month.month;
    final seconds = totalsByDay.entries
        .where((entry) => inMonth(entry.key))
        .fold(0, (total, entry) => total + entry.value);
    final monthSeconds = approximateMonths[month];
    // A month with no recorded or daily-approximated days falls back to
    // Android's monthly total; partial months are never topped up with it.
    if (seconds == 0 &&
        monthSeconds != null &&
        !recordedDays.any(inMonth) &&
        !approximateDays.any(inMonth)) {
      return DailyUsagePoint(
        day: month,
        durationSeconds: monthSeconds,
        isApproximate: true,
      );
    }
    return DailyUsagePoint(
      day: month,
      durationSeconds: seconds,
      isApproximate: approximateDays.any(inMonth),
    );
  }

  double? _changePercent(int current, int previous) {
    // No yesterday usage means there is nothing to compare against.
    if (previous == 0) {
      return null;
    }
    return (current - previous) / previous * 100;
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
