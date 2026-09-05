import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/usage_aggregation_service.dart';
import '../../application/services/usage_trend_service.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/daily_app_usage.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/usage_repository.dart';
import '../../performance/dashboard_performance.dart';

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
    this.isRefreshing = false,
    this.errorMessage,
    this.refreshErrorMessage,
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
  final bool isRefreshing;
  final String? errorMessage;
  final String? refreshErrorMessage;

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
    bool? isRefreshing,
    String? errorMessage,
    String? refreshErrorMessage,
    bool clearError = false,
    bool clearRefreshError = false,
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
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      refreshErrorMessage: clearRefreshError
          ? null
          : refreshErrorMessage ?? this.refreshErrorMessage,
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
    DateTime Function() clock = DateTime.now,
  }) : _usageRepository = usageRepository,
       _settingsRepository = settingsRepository,
       _aggregationService = aggregationService,
       _trendService = trendService,
       _clock = clock,
       super(DashboardState.initial(platform)) {
    DashboardPerformance.viewModelInitialized();
  }

  final UsageRepository _usageRepository;
  final SettingsRepository _settingsRepository;
  final UsageAggregationService _aggregationService;
  final UsageTrendService _trendService;
  final DateTime Function() _clock;
  int _loadGeneration = 0;
  int _auxiliaryGeneration = 0;
  DateTime? _summariesDay;
  bool _disposed = false;

  Future<void> loadTodayUsage({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    final dayOffset = state.dayOffset;
    final isToday = dayOffset == 0;
    final now = _clock();
    final selectedDate = DateTime(now.year, now.month, now.day + dayOffset);
    final hasCurrentSummaries =
        _summariesDay != null && _sameDay(_summariesDay!, selectedDate);
    if (!hasCurrentSummaries) {
      _summariesDay = null;
      state = state.copyWith(
        summaries: const <AppUsageSummary>[],
        totalDurationSeconds: 0,
        trendsByAppKey: const <String, UsageTrend>{},
        isLoading: true,
        isRefreshing: false,
        clearError: true,
        clearRefreshError: true,
      );
    } else {
      // Populated content remains visible during manual and silent refreshes.
      state = state.copyWith(
        isLoading: false,
        isRefreshing: true,
        clearError: true,
        clearRefreshError: true,
      );
    }

    try {
      if (state.platform == UsagePlatform.android && isToday) {
        await _loadAndroidToday(
          generation: generation,
          dayOffset: dayOffset,
          selectedDate: selectedDate,
          hasCurrentSummaries: hasCurrentSummaries,
        );
      } else {
        await _loadSingleSourceDay(
          generation: generation,
          dayOffset: dayOffset,
          selectedDate: selectedDate,
          isToday: isToday,
        );
      }
    } catch (error) {
      _publishLoadFailure(generation, dayOffset, selectedDate, error);
    }
  }

  Future<void> _loadAndroidToday({
    required int generation,
    required int dayOffset,
    required DateTime selectedDate,
    required bool hasCurrentSummaries,
  }) async {
    final accessFuture = _usageRepository.hasUsageAccess();
    final excludedAppsFuture = _settingsRepository.excludedApps();
    final hiddenAppsFuture = _settingsRepository.hiddenAppsForToday();

    if (!hasCurrentSummaries) {
      try {
        final cached = _applyFilters(
          await _usageRepository.getCachedTodaySummaries(selectedDate),
          await excludedAppsFuture,
          await hiddenAppsFuture,
        );
        if (!_isCurrentRequest(generation, dayOffset, selectedDate)) {
          return;
        }
        if (cached.isNotEmpty) {
          _publishSummaries(
            generation: generation,
            dayOffset: dayOffset,
            selectedDate: selectedDate,
            summaries: cached,
            excludedApps: await excludedAppsFuture,
            hasUsageAccess: state.hasUsageAccess,
            isRefreshing: true,
            loadAuxiliary: false,
          );
          DashboardPerformance.cachedStatePublished(
            topKeys: cached.map((summary) => summary.appKey),
            realIconKeys: cached
                .where((summary) => summary.iconBytes != null)
                .map((summary) => summary.appKey),
          );
          _startCachedMetadataHydration(
            generation: generation,
            dayOffset: dayOffset,
            selectedDate: selectedDate,
            cached: cached,
          );
        }
      } catch (_) {
        // A missing/corrupt snapshot must not prevent the authoritative read.
      }
    }

    final excludedApps = await excludedAppsFuture;
    final hiddenApps = await hiddenAppsFuture;

    final hasAccess = await accessFuture;
    if (!_isCurrentRequest(generation, dayOffset, selectedDate)) {
      return;
    }
    if (!hasAccess) {
      state = state.copyWith(
        hasUsageAccess: false,
        isLoading: false,
        isRefreshing: false,
      );
      _startAuxiliaryLoads(
        generation,
        dayOffset,
        selectedDate,
        excludedApps,
        state.summaries,
      );
      return;
    }

    state = state.copyWith(
      hasUsageAccess: true,
      isLoading: state.summaries.isEmpty,
      isRefreshing: state.summaries.isNotEmpty,
    );
    try {
      final fresh = _applyFilters(
        await DashboardPerformance.traceLiveUsageFetch(
          _usageRepository.getTodaySummaries,
        ),
        excludedApps,
        hiddenApps,
      );
      if (!_isCurrentRequest(generation, dayOffset, selectedDate)) {
        return;
      }
      _publishSummaries(
        generation: generation,
        dayOffset: dayOffset,
        selectedDate: selectedDate,
        summaries: fresh,
        excludedApps: excludedApps,
        hasUsageAccess: true,
        isRefreshing: false,
        loadAuxiliary: true,
      );
    } catch (error) {
      _publishLoadFailure(generation, dayOffset, selectedDate, error);
      if (state.summaries.isNotEmpty) {
        _startAuxiliaryLoads(
          generation,
          dayOffset,
          selectedDate,
          excludedApps,
          state.summaries,
        );
      }
    }
  }

  void _startCachedMetadataHydration({
    required int generation,
    required int dayOffset,
    required DateTime selectedDate,
    required List<AppUsageSummary> cached,
  }) {
    if (_usageRepository is! AppMetadataRepository) {
      return;
    }
    final repository = _usageRepository as AppMetadataRepository;
    final top = cached.take(10).toList(growable: false);
    final remaining = cached.skip(10).toList(growable: false);
    DashboardPerformance.iconHydrationStarted(
      source: 'metadata',
      requestedCount: top.length,
    );
    unawaited(() async {
      try {
        final hydratedTop = await DashboardPerformance.traceIconHydrationFetch(
          () => repository.hydrateAppMetadata(top),
        );
        if (!_isCurrentRequest(generation, dayOffset, selectedDate)) {
          return;
        }
        DashboardPerformance.iconHydrationCompleted(
          source: 'metadata',
          availableIconKeys: hydratedTop
              .where((summary) => summary.iconBytes != null)
              .map((summary) => summary.appKey),
        );
        _mergeMetadataIntoVisible(hydratedTop);

        if (remaining.isEmpty ||
            !_isCurrentRequest(generation, dayOffset, selectedDate)) {
          return;
        }
        final hydratedRemaining = await repository.hydrateAppMetadata(
          remaining,
        );
        if (_isCurrentRequest(generation, dayOffset, selectedDate)) {
          _mergeMetadataIntoVisible(hydratedRemaining);
        }
      } catch (_) {
        if (_isCurrentRequest(generation, dayOffset, selectedDate)) {
          DashboardPerformance.iconHydrationCompleted(
            source: 'metadata_error',
            availableIconKeys: const <String>[],
          );
        }
        // Metadata is decorative. Existing fallback icons remain visible.
      }
    }());
  }

  void _mergeMetadataIntoVisible(List<AppUsageSummary> metadata) {
    if (metadata.isEmpty || state.summaries.isEmpty) {
      return;
    }
    final byKey = {for (final summary in metadata) summary.appKey: summary};
    var changed = false;
    final enriched = state.summaries
        .map((summary) {
          final current = byKey[summary.appKey];
          if (current == null) {
            return summary;
          }
          final appName = current.appName.isEmpty
              ? summary.appName
              : current.appName;
          final iconBytes = current.iconBytes ?? summary.iconBytes;
          if (appName == summary.appName &&
              identical(iconBytes, summary.iconBytes)) {
            return summary;
          }
          changed = true;
          return summary.copyWith(appName: appName, iconBytes: iconBytes);
        })
        .toList(growable: false);
    if (changed) {
      state = state.copyWith(summaries: enriched);
    }
  }

  Future<void> _loadSingleSourceDay({
    required int generation,
    required int dayOffset,
    required DateTime selectedDate,
    required bool isToday,
  }) async {
    final hasAccessFuture = _usageRepository.hasUsageAccess();
    final excludedAppsFuture = _settingsRepository.excludedApps();
    final hiddenAppsFuture = isToday
        ? _settingsRepository.hiddenAppsForToday()
        : Future<Set<String>>.value(const <String>{});
    final rawSummaries = isToday
        ? await _usageRepository.getTodaySummaries()
        : await _usageRepository.getDailySummaries(selectedDate);
    final excludedApps = await excludedAppsFuture;
    final summaries = _applyFilters(
      rawSummaries,
      excludedApps,
      await hiddenAppsFuture,
    );
    final hasAccess = await hasAccessFuture;
    if (!_isCurrentRequest(generation, dayOffset, selectedDate)) {
      return;
    }
    _publishSummaries(
      generation: generation,
      dayOffset: dayOffset,
      selectedDate: selectedDate,
      summaries: summaries,
      excludedApps: excludedApps,
      hasUsageAccess: hasAccess,
      isRefreshing: false,
      loadAuxiliary: true,
    );
  }

  void _publishSummaries({
    required int generation,
    required int dayOffset,
    required DateTime selectedDate,
    required List<AppUsageSummary> summaries,
    required List<String> excludedApps,
    required bool hasUsageAccess,
    required bool isRefreshing,
    required bool loadAuxiliary,
  }) {
    if (!_isCurrentRequest(generation, dayOffset, selectedDate)) {
      return;
    }
    _summariesDay = selectedDate;
    state = state.copyWith(
      summaries: summaries,
      totalDurationSeconds: _aggregationService.totalDurationSeconds(summaries),
      hasUsageAccess: hasUsageAccess,
      trendsByAppKey: const <String, UsageTrend>{},
      isLoading: false,
      isRefreshing: isRefreshing,
      clearError: true,
      clearRefreshError: true,
    );
    if (summaries.isNotEmpty) {
      DashboardPerformance.firstNonEmptyState();
    }
    if (!loadAuxiliary) {
      return;
    }
    _startAuxiliaryLoads(
      generation,
      dayOffset,
      selectedDate,
      excludedApps,
      summaries,
    );
  }

  void _startAuxiliaryLoads(
    int generation,
    int dayOffset,
    DateTime selectedDate,
    List<String> excludedApps,
    List<AppUsageSummary> summaries,
  ) {
    final auxiliaryGeneration = ++_auxiliaryGeneration;
    _loadAllTimeTopAppsIndependently(
      generation,
      auxiliaryGeneration,
      dayOffset,
      selectedDate,
      excludedApps,
    );
    _loadUsageTrendsIndependently(
      generation,
      auxiliaryGeneration,
      dayOffset,
      selectedDate,
      summaries,
    );
  }

  void _loadAllTimeTopAppsIndependently(
    int generation,
    int auxiliaryGeneration,
    int dayOffset,
    DateTime selectedDate,
    List<String> excludedApps,
  ) {
    unawaited(() async {
      final allTimeTopApps = await _loadAllTimeTopApps(excludedApps);
      if (auxiliaryGeneration == _auxiliaryGeneration &&
          _isCurrentRequest(generation, dayOffset, selectedDate)) {
        state = state.copyWith(allTimeTopApps: allTimeTopApps);
      }
    }());
  }

  void _loadUsageTrendsIndependently(
    int generation,
    int auxiliaryGeneration,
    int dayOffset,
    DateTime selectedDate,
    List<AppUsageSummary> summaries,
  ) {
    unawaited(() async {
      final trends = await _loadUsageTrends(selectedDate, summaries);
      if (auxiliaryGeneration == _auxiliaryGeneration &&
          _isCurrentRequest(generation, dayOffset, selectedDate)) {
        state = state.copyWith(trendsByAppKey: trends);
      }
    }());
  }

  void _publishLoadFailure(
    int generation,
    int dayOffset,
    DateTime selectedDate,
    Object error,
  ) {
    if (!_isCurrentRequest(generation, dayOffset, selectedDate)) {
      return;
    }
    final hasVisibleSummaries =
        state.summaries.isNotEmpty &&
        _summariesDay != null &&
        _sameDay(_summariesDay!, selectedDate);
    state = state.copyWith(
      isLoading: false,
      isRefreshing: false,
      errorMessage: hasVisibleSummaries ? null : error.toString(),
      refreshErrorMessage: hasVisibleSummaries ? error.toString() : null,
      clearError: hasVisibleSummaries,
      clearRefreshError: !hasVisibleSummaries,
    );
  }

  bool _isCurrentRequest(int generation, int dayOffset, DateTime selectedDate) {
    if (_disposed ||
        generation != _loadGeneration ||
        state.dayOffset != dayOffset) {
      return false;
    }
    if (dayOffset == 0 && !_sameDay(selectedDate, _clock())) {
      unawaited(loadTodayUsage());
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _auxiliaryGeneration++;
    super.dispose();
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
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
    _summariesDay = null;
    state = state.copyWith(
      dayOffset: offset,
      summaries: const <AppUsageSummary>[],
      totalDurationSeconds: 0,
      trendsByAppKey: const <String, UsageTrend>{},
      isLoading: true,
      isRefreshing: false,
      clearError: true,
      clearRefreshError: true,
    );
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
