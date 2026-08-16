import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/usage_repository.dart';

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
  const DailyUsagePoint({required this.day, required this.durationSeconds});

  final DateTime day;
  final int durationSeconds;

  Duration get duration => Duration(seconds: durationSeconds);
}

enum UsageDetailsPeriod {
  sevenDays,
  twoWeeks,
  month,
  year;

  DateTime startDate(DateTime selectedDay) {
    return switch (this) {
      UsageDetailsPeriod.sevenDays => selectedDay.subtract(
        const Duration(days: 6),
      ),
      UsageDetailsPeriod.twoWeeks => selectedDay.subtract(
        const Duration(days: 13),
      ),
      UsageDetailsPeriod.month => selectedDay.subtract(
        const Duration(days: 29),
      ),
      UsageDetailsPeriod.year => DateTime(
        selectedDay.year,
        selectedDay.month - 11,
      ),
    };
  }
}

class AppUsageDetailsState {
  const AppUsageDetailsState({
    this.points = const <DailyUsagePoint>[],
    this.sessions = const <UsageSession>[],
    this.period = UsageDetailsPeriod.sevenDays,
    this.changeFromYesterdayPercent,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<DailyUsagePoint> points;
  final List<UsageSession> sessions;
  final UsageDetailsPeriod period;
  final double? changeFromYesterdayPercent;
  final bool isLoading;
  final String? errorMessage;

  int get totalDurationSeconds =>
      points.fold(0, (total, point) => total + point.durationSeconds);

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);
}

class AppUsageDetailsViewModel extends StateNotifier<AppUsageDetailsState> {
  AppUsageDetailsViewModel({
    required UsageRepository usageRepository,
    required AppUsageDetailsRequest request,
  }) : _usageRepository = usageRepository,
       _request = request,
       super(const AppUsageDetailsState(isLoading: true));

  final UsageRepository _usageRepository;
  final AppUsageDetailsRequest _request;

  Future<void> selectPeriod(UsageDetailsPeriod period) {
    if (period == state.period) {
      return Future<void>.value();
    }
    return load(period: period);
  }

  Future<void> load({UsageDetailsPeriod? period}) async {
    final selectedPeriod = period ?? state.period;
    state = AppUsageDetailsState(period: selectedPeriod, isLoading: true);
    final selectedDay = _day(_request.selectedDate);
    try {
      final historyFuture = _usageRepository.getUsageHistory(
        selectedPeriod.startDate(selectedDay),
        selectedDay.add(const Duration(days: 1)),
      );
      final sessionsFuture = _usageRepository.topSessionsForApp(
        _request.summary.appKey,
        selectedDay,
      );
      final history = await historyFuture;
      final sessions = await sessionsFuture;
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

      final points = _pointsFor(
        period: selectedPeriod,
        selectedDay: selectedDay,
        totalsByDay: totalsByDay,
      );
      final current = totalsByDay[selectedDay] ?? 0;
      final previous =
          totalsByDay[selectedDay.subtract(const Duration(days: 1))] ?? 0;
      state = AppUsageDetailsState(
        points: points,
        sessions: sessions,
        period: selectedPeriod,
        changeFromYesterdayPercent: _changePercent(current, previous),
      );
    } catch (error) {
      state = AppUsageDetailsState(
        period: selectedPeriod,
        errorMessage: error.toString(),
      );
    }
  }

  List<DailyUsagePoint> _pointsFor({
    required UsageDetailsPeriod period,
    required DateTime selectedDay,
    required Map<DateTime, int> totalsByDay,
  }) {
    final startDate = period.startDate(selectedDay);
    if (period == UsageDetailsPeriod.year) {
      return [
        for (var monthOffset = 0; monthOffset < 12; monthOffset++)
          DailyUsagePoint(
            day: DateTime(startDate.year, startDate.month + monthOffset),
            durationSeconds: totalsByDay.entries
                .where(
                  (entry) =>
                      entry.key.year ==
                          DateTime(
                            startDate.year,
                            startDate.month + monthOffset,
                          ).year &&
                      entry.key.month ==
                          DateTime(
                            startDate.year,
                            startDate.month + monthOffset,
                          ).month,
                )
                .fold(0, (total, entry) => total + entry.value),
          ),
      ];
    }

    final dayCount = selectedDay.difference(startDate).inDays + 1;
    return [
      for (var dayOffset = 0; dayOffset < dayCount; dayOffset++)
        DailyUsagePoint(
          day: startDate.add(Duration(days: dayOffset)),
          durationSeconds:
              totalsByDay[startDate.add(Duration(days: dayOffset))] ?? 0,
        ),
    ];
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
