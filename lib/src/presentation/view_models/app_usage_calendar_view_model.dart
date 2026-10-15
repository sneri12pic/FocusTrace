import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_interval.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/repositories/report_repository.dart';
import '../../data/repositories/os_usage_history_repository.dart';
import 'app_usage_details_view_model.dart';

class CalendarDayUsage {
  const CalendarDayUsage({this.durationSeconds = 0, this.launchCount = 0});

  final int durationSeconds;
  final int launchCount;

  CalendarDayUsage operator +(CalendarDayUsage other) => CalendarDayUsage(
    durationSeconds: durationSeconds + other.durationSeconds,
    launchCount: launchCount + other.launchCount,
  );
}

class AppUsageCalendarState {
  const AppUsageCalendarState({
    required this.month,
    required this.today,
    this.days = const <DateTime, CalendarDayUsage>{},
    this.previousDays = const <DateTime, CalendarDayUsage>{},
    this.intervals = const <AppUsageInterval>[],
    this.approximateDays = const <DateTime>{},
    this.approximateMonthSeconds,
    this.previousApproximateMonthSeconds,
    this.selectedDay,
    this.isLoading = false,
    this.errorMessage,
  });

  /// First day of the shown calendar month.
  final DateTime month;
  final DateTime today;

  /// This app's usage per day in [month] and in the month before it.
  final Map<DateTime, CalendarDayUsage> days;
  final Map<DateTime, CalendarDayUsage> previousDays;

  /// This app's foreground intervals that start in [month].
  final List<AppUsageInterval> intervals;

  /// Days in [days] filled from Android's aggregated history.
  final Set<DateTime> approximateDays;

  /// Android's monthly total, used only when a month has no daily data.
  final int? approximateMonthSeconds;
  final int? previousApproximateMonthSeconds;
  final DateTime? selectedDay;
  final bool isLoading;
  final String? errorMessage;

  DateTime get previousMonth => DateTime(month.year, month.month - 1);

  bool get canShowNextMonth =>
      !DateTime(month.year, month.month + 1).isAfter(today);

  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  /// Days of [month] that have happened, so averages ignore the future.
  int get elapsedDays => today.year == month.year && today.month == month.month
      ? today.day
      : daysInMonth;

  CalendarDayUsage dayUsage(DateTime day) =>
      days[day] ?? const CalendarDayUsage();

  bool isApproximateDay(DateTime day) => approximateDays.contains(day);

  bool get _usesMonthTotal => days.isEmpty && approximateMonthSeconds != null;

  /// True when any month figure leans on Android's aggregated history.
  bool get isMonthApproximate => approximateDays.isNotEmpty || _usesMonthTotal;

  CalendarDayUsage get monthTotal => _usesMonthTotal
      ? CalendarDayUsage(durationSeconds: approximateMonthSeconds!)
      : _sum(days.values);

  int get _previousLength => DateTime(month.year, month.month, 0).day;

  /// The previous month's first [elapsedDays] days, so a month in progress
  /// is compared with the same stretch of the month before. A month known
  /// only as Android's monthly total is prorated.
  CalendarDayUsage get previousSameSpan {
    final previousMonthSeconds = previousApproximateMonthSeconds;
    if (previousDays.isEmpty && previousMonthSeconds != null) {
      return CalendarDayUsage(
        durationSeconds:
            previousMonthSeconds *
            math.min(elapsedDays, _previousLength) ~/
            _previousLength,
      );
    }
    return _sum(
      previousDays.entries
          .where((entry) => entry.key.day <= elapsedDays)
          .map((entry) => entry.value),
    );
  }

  bool get hasPreviousMonth =>
      previousDays.isNotEmpty || previousApproximateMonthSeconds != null;

  int get averagePerDaySeconds => monthTotal.durationSeconds ~/ elapsedDays;

  int get previousAveragePerDaySeconds {
    final previousMonthSeconds = previousApproximateMonthSeconds;
    final seconds = previousDays.isEmpty && previousMonthSeconds != null
        ? previousMonthSeconds
        : _sum(previousDays.values).durationSeconds;
    return seconds ~/ _previousLength;
  }

  int get busiestDaySeconds => days.values.fold(
    0,
    (busiest, day) => math.max(busiest, day.durationSeconds),
  );

  AppUsageInterval? get longestInterval => intervals.isEmpty
      ? null
      : intervals.reduce(
          (longest, interval) =>
              interval.durationSeconds > longest.durationSeconds
              ? interval
              : longest,
        );

  /// Intervals overlapping [day], clipped to it.
  List<AppUsageInterval> intervalsOn(DateTime day) {
    final end = DateTime(day.year, day.month, day.day + 1);
    return [
      for (final interval in intervals)
        if (interval.startedAt.isBefore(end) && interval.endedAt.isAfter(day))
          AppUsageInterval(
            id: interval.id,
            appKey: interval.appKey,
            appName: interval.appName,
            startedAt: interval.startedAt.isBefore(day)
                ? day
                : interval.startedAt,
            endedAt: interval.endedAt.isAfter(end) ? end : interval.endedAt,
          ),
    ];
  }

  AppUsageCalendarState copyWith({DateTime? selectedDay, bool? isLoading}) {
    return AppUsageCalendarState(
      month: month,
      today: today,
      days: days,
      previousDays: previousDays,
      intervals: intervals,
      approximateDays: approximateDays,
      approximateMonthSeconds: approximateMonthSeconds,
      previousApproximateMonthSeconds: previousApproximateMonthSeconds,
      selectedDay: selectedDay ?? this.selectedDay,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  static CalendarDayUsage _sum(Iterable<CalendarDayUsage> values) =>
      values.fold(const CalendarDayUsage(), (total, day) => total + day);
}

/// One month of this app's usage, as loaded from the report source.
class _MonthData {
  const _MonthData(
    this.days,
    this.intervals, {
    this.approximateDays = const <DateTime>{},
    this.approximateMonthSeconds,
  });

  final Map<DateTime, CalendarDayUsage> days;
  final List<AppUsageInterval> intervals;
  final Set<DateTime> approximateDays;
  final int? approximateMonthSeconds;
}

class AppUsageCalendarViewModel extends StateNotifier<AppUsageCalendarState> {
  AppUsageCalendarViewModel({
    required ReportRepository reportRepository,
    required AppUsageDetailsRequest request,
    OsUsageHistoryRepository? osHistory,
    DateTime Function() clock = DateTime.now,
  }) : _reportRepository = reportRepository,
       _request = request,
       _osHistory = osHistory,
       super(
         AppUsageCalendarState(
           month: DateTime(
             request.selectedDate.year,
             request.selectedDate.month,
           ),
           today: _day(clock()),
           selectedDay: _day(request.selectedDate),
           isLoading: true,
         ),
       );

  final ReportRepository _reportRepository;
  final AppUsageDetailsRequest _request;
  final OsUsageHistoryRepository? _osHistory;
  int _loadGeneration = 0;

  // Each month reconciles history once per screen, which is the slow part.
  // ponytail: per-screen memory cache; months are few and the screen is
  // short-lived, so there is no eviction.
  final _requests = <DateTime, Future<_MonthData>>{};
  final _loaded = <DateTime, _MonthData>{};

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: _day(day));
  }

  Future<void> showPreviousMonth() => load(month: state.previousMonth);

  Future<void> showNextMonth() {
    if (!state.canShowNextMonth) return Future<void>.value();
    return load(month: DateTime(state.month.year, state.month.month + 1));
  }

  Future<void> load({DateTime? month}) async {
    final generation = ++_loadGeneration;
    final shownMonth = month ?? state.month;
    final previousMonth = DateTime(shownMonth.year, shownMonth.month - 1);
    final current = _loaded[shownMonth];
    final previous = _loaded[previousMonth];
    if (current != null && previous != null) {
      _show(shownMonth, current, previous);
    } else {
      // Keep the current month on screen until the new one is ready, so the
      // cards don't collapse into a spinner and jump back.
      state = state.errorMessage == null
          ? state.copyWith(isLoading: true)
          : AppUsageCalendarState(
              month: shownMonth,
              today: state.today,
              selectedDay: state.selectedDay,
              isLoading: true,
            );
      try {
        final (current, previous) = await (
          _monthData(shownMonth),
          _monthData(previousMonth),
        ).wait;
        if (!mounted || generation != _loadGeneration) return;
        _show(shownMonth, current, previous);
      } catch (error) {
        if (!mounted || generation != _loadGeneration) return;
        state = AppUsageCalendarState(
          month: shownMonth,
          today: state.today,
          selectedDay: state.selectedDay,
          errorMessage: error.toString(),
        );
        return;
      }
    }
    // Warm the month before so the next "previous" tap is instant.
    unawaited(
      _monthData(
        DateTime(shownMonth.year, shownMonth.month - 2),
      ).then((_) {}, onError: (Object _) {}),
    );
  }

  /// The selected day moved into [month] (same day number, clamped to the
  /// month and to today), so the day panel never disappears and shifts the
  /// screen.
  DateTime _selectionIn(DateTime month) {
    final selected = state.selectedDay;
    if (selected != null &&
        selected.year == month.year &&
        selected.month == month.month) {
      return selected;
    }
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = DateTime(
      month.year,
      month.month,
      math.min(selected?.day ?? 1, lastDay),
    );
    return day.isAfter(state.today) ? state.today : day;
  }

  void _show(DateTime month, _MonthData current, _MonthData previous) {
    state = AppUsageCalendarState(
      month: month,
      today: state.today,
      days: current.days,
      previousDays: previous.days,
      intervals: current.intervals,
      approximateDays: current.approximateDays,
      approximateMonthSeconds: current.approximateMonthSeconds,
      previousApproximateMonthSeconds: previous.approximateMonthSeconds,
      selectedDay: _selectionIn(month),
    );
  }

  Future<_MonthData> _monthData(DateTime month) {
    return _requests[month] ??= _fetch(month).then(
      (data) => _loaded[month] = data,
      onError: (Object error, StackTrace stackTrace) {
        _requests.remove(month); // Let a retry fetch again.
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<_MonthData> _fetch(DateTime month) async {
    final nextMonth = DateTime(month.year, month.month + 1);
    // The report source is what Reports reads: it reconciles the month and
    // returns the persisted foreground intervals alongside daily totals.
    final source = await _reportRepository.loadSourceData(month, nextMonth);
    final appKey = _request.summary.appKey;
    final days = _byDay(source.dailyUsage, appKey);
    final requestDay = _day(_request.selectedDate);
    if (!requestDay.isBefore(month) && requestDay.isBefore(nextMonth)) {
      // The selected list row is fresher than the stored snapshot.
      days[requestDay] = CalendarDayUsage(
        durationSeconds: _request.summary.totalDurationSeconds,
        launchCount: _request.summary.launchCount,
      );
    }
    final intervals = [
      for (final interval in source.intervals)
        if (interval.appKey == appKey &&
            interval.endedAt.isAfter(month) &&
            interval.startedAt.isBefore(nextMonth))
          interval,
    ];
    final osHistory = _osHistory;
    if (osHistory == null) return _MonthData(days, intervals);
    await osHistory.importOnce();
    final (approximate, monthly) = await (
      osHistory.dailySeconds(appKey, month, nextMonth),
      osHistory.monthlySeconds(appKey, month, nextMonth),
    ).wait;
    // A day with no rows for any app was not recorded, so Android's total may
    // stand in for it. A recorded day without this app really was zero.
    final recordedDays = {
      for (final entry in source.dailyUsage) _day(entry.day),
      if (!requestDay.isBefore(month) && requestDay.isBefore(nextMonth))
        requestDay,
    };
    final approximateDays = <DateTime>{};
    approximate.forEach((day, seconds) {
      if (!recordedDays.contains(day)) {
        days[day] = CalendarDayUsage(durationSeconds: seconds);
        approximateDays.add(day);
      }
    });
    return _MonthData(
      days,
      intervals,
      approximateDays: approximateDays,
      approximateMonthSeconds: recordedDays.isEmpty ? monthly[month] : null,
    );
  }

  static Map<DateTime, CalendarDayUsage> _byDay(
    List<DailyAppUsage> history,
    String appKey,
  ) {
    final days = <DateTime, CalendarDayUsage>{};
    for (final entry in history) {
      if (entry.summary.appKey != appKey) continue;
      final usage = CalendarDayUsage(
        durationSeconds: entry.summary.totalDurationSeconds,
        launchCount: entry.summary.launchCount,
      );
      days.update(
        _day(entry.day),
        (total) => total + usage,
        ifAbsent: () => usage,
      );
    }
    return days;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
