import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/usage_aggregation_service.dart';
import '../../application/services/usage_trend_service.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/usage_repository.dart';

class DashboardState {
  const DashboardState({
    required this.platform,
    required this.summaries,
    required this.totalDurationSeconds,
    required this.hasUsageAccess,
    this.allTimeTopApps = const <AppUsageSummary>[],
    this.trendsByAppKey = const <String, UsageTrend>{},
    this.dayOffset = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  factory DashboardState.initial(UsagePlatform platform) {
    return DashboardState(
      platform: platform,
      summaries: const <AppUsageSummary>[],
      totalDurationSeconds: 0,
      hasUsageAccess: platform != UsagePlatform.android,
      isLoading: true,
    );
  }

  final UsagePlatform platform;
  final List<AppUsageSummary> summaries;
  final int totalDurationSeconds;
  final bool hasUsageAccess;
  final List<AppUsageSummary> allTimeTopApps;
  final Map<String, UsageTrend> trendsByAppKey;

  /// 0 = today, -1 = yesterday, and so on.
  final int dayOffset;
  final bool isLoading;
  final String? errorMessage;

  bool get isToday => dayOffset == 0;

  DateTime get selectedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + dayOffset);
  }

  DashboardState copyWith({
    List<AppUsageSummary>? summaries,
    int? totalDurationSeconds,
    bool? hasUsageAccess,
    List<AppUsageSummary>? allTimeTopApps,
    Map<String, UsageTrend>? trendsByAppKey,
    int? dayOffset,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      platform: platform,
      summaries: summaries ?? this.summaries,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      hasUsageAccess: hasUsageAccess ?? this.hasUsageAccess,
      allTimeTopApps: allTimeTopApps ?? this.allTimeTopApps,
      trendsByAppKey: trendsByAppKey ?? this.trendsByAppKey,
      dayOffset: dayOffset ?? this.dayOffset,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel({
    required UsageRepository usageRepository,
    required SettingsRepository settingsRepository,
    required UsagePlatform platform,
    UsageAggregationService aggregationService =
        const UsageAggregationService(),
    UsageTrendService trendService = const UsageTrendService(),
  }) : _usageRepository = usageRepository,
       _settingsRepository = settingsRepository,
       _aggregationService = aggregationService,
       _trendService = trendService,
       super(DashboardState.initial(platform));

  final UsageRepository _usageRepository;
  final SettingsRepository _settingsRepository;
  final UsageAggregationService _aggregationService;
  final UsageTrendService _trendService;
  int _loadGeneration = 0;

  Future<void> loadTodayUsage({bool showLoading = true}) async {
    // ponytail: showLoading=false skips the spinner so the 5s auto-refresh
    // doesn't flicker the dashboard while tracking.
    if (showLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    final generation = ++_loadGeneration;
    final dayOffset = state.dayOffset;
    final isToday = dayOffset == 0;
    final now = DateTime.now();
    final selectedDate = DateTime(now.year, now.month, now.day + dayOffset);
    try {
      final hasAccess = await _usageRepository.hasUsageAccess();
      if (generation != _loadGeneration) {
        return;
      }
      if (state.platform == UsagePlatform.android && isToday && !hasAccess) {
        final excludedApps = await _settingsRepository.excludedApps();
        final allTimeTopApps = await _loadAllTimeTopApps(excludedApps);
        if (generation != _loadGeneration) {
          return;
        }
        state = state.copyWith(
          summaries: const <AppUsageSummary>[],
          totalDurationSeconds: 0,
          hasUsageAccess: false,
          allTimeTopApps: allTimeTopApps,
          trendsByAppKey: const <String, UsageTrend>{},
          isLoading: false,
        );
        return;
      }

      final rawSummaries = isToday
          ? await _usageRepository.getTodaySummaries()
          : await _usageRepository.getDailySummaries(selectedDate);
      final excludedApps = await _settingsRepository.excludedApps();
      final summaries = _applyFilters(
        rawSummaries,
        excludedApps,
        isToday
            ? await _settingsRepository.hiddenAppsForToday()
            : const <String>{},
      );
      final allTimeTopApps = await _loadAllTimeTopApps(excludedApps);
      final trendsByAppKey = await _loadUsageTrends(selectedDate, summaries);
      if (generation != _loadGeneration) {
        return;
      }
      state = state.copyWith(
        summaries: summaries,
        totalDurationSeconds: _aggregationService.totalDurationSeconds(
          summaries,
        ),
        hasUsageAccess: hasAccess,
        allTimeTopApps: allTimeTopApps,
        trendsByAppKey: trendsByAppKey,
        isLoading: false,
      );
    } catch (error) {
      if (generation == _loadGeneration) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      }
    }
  }

  Future<void> refresh() => loadTodayUsage();

  Future<void> refreshSilently() {
    // Past-day snapshots don't change; only live "today" needs the tick.
    if (!state.isToday) {
      return Future.value();
    }
    return loadTodayUsage(showLoading: false);
  }

  Future<void> previousDay() => _selectDayOffset(state.dayOffset - 1);

  Future<void> nextDay() {
    if (state.isToday) {
      return Future.value();
    }
    return _selectDayOffset(state.dayOffset + 1);
  }

  Future<void> _selectDayOffset(int offset) {
    state = state.copyWith(dayOffset: offset);
    return loadTodayUsage();
  }

  Future<void> checkPermission() async {
    final hasAccess = await _usageRepository.hasUsageAccess();
    state = state.copyWith(hasUsageAccess: hasAccess);
    if (hasAccess && state.isToday) {
      await loadTodayUsage();
    }
  }

  Future<void> openPermissionSettings() async {
    await _usageRepository.openUsageAccessSettings();
  }

  Future<void> clearData() async {
    await _usageRepository.clearAllData();
    await loadTodayUsage();
  }

  /// Hides [summary] from today's stats only (persisted local hide list).
  Future<void> hideAppForToday(AppUsageSummary summary) async {
    await _settingsRepository.hideAppForToday(summary.appKey);
    await refreshSilently();
  }

  /// Permanently excludes [summary] from tracking and displayed stats.
  Future<void> excludeApp(AppUsageSummary summary) async {
    await _settingsRepository.addExcludedApp(summary.appKey);
    await refreshSilently();
  }

  Future<List<UsageSession>> topSessionsForApp(AppUsageSummary summary) {
    return _usageRepository.topSessionsForApp(
      summary.appKey,
      state.selectedDate,
    );
  }

  List<AppUsageSummary> _applyFilters(
    List<AppUsageSummary> summaries,
    List<String> excludedApps,
    Set<String> hiddenAppsToday,
  ) {
    final visible = summaries
        .where(
          (summary) =>
              !excludedApps.contains(summary.appKey) &&
              !hiddenAppsToday.contains(summary.appKey),
        )
        .toList();
    if (visible.length == summaries.length) {
      return summaries;
    }

    // Recompute shares so percentages reflect only the visible apps.
    return _aggregationService.withPercentages(visible);
  }

  Future<List<AppUsageSummary>> _loadAllTimeTopApps(
    List<String> excludedApps,
  ) async {
    try {
      final visible = _applyFilters(
        await _usageRepository.getAllTimeSummaries(),
        excludedApps,
        const <String>{},
      );
      return visible.take(3).toList();
    } catch (_) {
      // This insight is best-effort and must not block the daily dashboard.
      return const <AppUsageSummary>[];
    }
  }

  Future<Map<String, UsageTrend>> _loadUsageTrends(
    DateTime throughDay,
    List<AppUsageSummary> summaries,
  ) async {
    if (summaries.isEmpty) {
      return const <String, UsageTrend>{};
    }
    try {
      final history = await _usageRepository.getUsageHistory(
        throughDay.subtract(const Duration(days: 59)),
        throughDay.add(const Duration(days: 1)),
      );
      return _trendService.calculate(
        history: history,
        throughDay: throughDay,
        appKeys: summaries.map((summary) => summary.appKey),
      );
    } catch (_) {
      // Trend badges are auxiliary and never block daily usage.
      return const <String, UsageTrend>{};
    }
  }
}
