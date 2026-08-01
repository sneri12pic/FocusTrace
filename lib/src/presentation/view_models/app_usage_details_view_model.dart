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

class AppUsageDetailsState {
  const AppUsageDetailsState({
    this.points = const <DailyUsagePoint>[],
    this.sessions = const <UsageSession>[],
    this.changeFromYesterdayPercent,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<DailyUsagePoint> points;
  final List<UsageSession> sessions;
  final double? changeFromYesterdayPercent;
  final bool isLoading;
  final String? errorMessage;
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

  Future<void> load() async {
    state = const AppUsageDetailsState(isLoading: true);
    final selectedDay = _day(_request.selectedDate);
    try {
      final historyFuture = _usageRepository.getUsageHistory(
        selectedDay.subtract(const Duration(days: 6)),
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

      final points = [
        for (var daysAgo = 6; daysAgo >= 0; daysAgo--)
          DailyUsagePoint(
            day: selectedDay.subtract(Duration(days: daysAgo)),
            durationSeconds:
                totalsByDay[selectedDay.subtract(Duration(days: daysAgo))] ?? 0,
          ),
      ];
      final current = points.last.durationSeconds;
      final previous = points[points.length - 2].durationSeconds;
      state = AppUsageDetailsState(
        points: points,
        sessions: sessions,
        changeFromYesterdayPercent: _changePercent(current, previous),
      );
    } catch (error) {
      state = AppUsageDetailsState(errorMessage: error.toString());
    }
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
