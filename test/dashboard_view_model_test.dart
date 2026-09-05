import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test(
    'past Android history remains available without current usage access',
    () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final repository = _DashboardUsageRepository(hasUsageAccess: false)
        ..dailyResult = const [
          AppUsageSummary(
            appName: 'Yesterday app',
            packageName: 'example.yesterday',
            totalDurationSeconds: 600,
            percentageOfTotal: 1,
          ),
        ]
        ..allTimeResult = const [
          AppUsageSummary(
            appName: 'All-time leader',
            packageName: 'example.leader',
            totalDurationSeconds: 3600,
            percentageOfTotal: 1,
          ),
        ]
        ..historyResult = [
          DailyAppUsage(
            day: yesterday,
            summary: const AppUsageSummary(
              appName: 'Yesterday app',
              packageName: 'example.yesterday',
              totalDurationSeconds: 600,
              percentageOfTotal: 0,
            ),
          ),
          DailyAppUsage(
            day: yesterday.subtract(const Duration(days: 1)),
            summary: const AppUsageSummary(
              appName: 'Yesterday app',
              packageName: 'example.yesterday',
              totalDurationSeconds: 400,
              percentageOfTotal: 0,
            ),
          ),
        ];
      final viewModel = DashboardViewModel(
        usageRepository: repository,
        settingsRepository: _DashboardSettingsRepository(),
        platform: UsagePlatform.android,
      );

      await viewModel.previousDay();
      await _waitUntil(() => viewModel.state.trendsByAppKey.isNotEmpty);

      expect(viewModel.state.dayOffset, -1);
      expect(viewModel.state.hasUsageAccess, isFalse);
      expect(viewModel.state.summaries.single.appName, 'Yesterday app');
      expect(viewModel.state.allTimeTopApps.first.appName, 'All-time leader');
      expect(
        viewModel.state.trendsByAppKey['example.yesterday']?.dayChangePercent,
        50,
      );
    },
  );

  test('a slower day load cannot overwrite the latest selected day', () async {
    final firstResult = Completer<List<AppUsageSummary>>();
    final repository = _DashboardUsageRepository()
      ..dailyResults = [
        firstResult.future,
        Future.value(const [
          AppUsageSummary(
            appName: 'Latest selection',
            packageName: 'example.latest',
            totalDurationSeconds: 300,
            percentageOfTotal: 1,
          ),
        ]),
      ];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.windows,
    );

    final slowerLoad = viewModel.previousDay();
    await Future<void>.delayed(Duration.zero);
    await viewModel.previousDay();
    firstResult.complete(const [
      AppUsageSummary(
        appName: 'Stale selection',
        packageName: 'example.stale',
        totalDurationSeconds: 900,
        percentageOfTotal: 1,
      ),
    ]);
    await slowerLoad;

    expect(viewModel.state.dayOffset, -2);
    expect(viewModel.state.summaries.single.appName, 'Latest selection');
  });

  test('cached Android usage is visible while live usage refreshes', () async {
    final liveResult = Completer<List<AppUsageSummary>>();
    final repository = _DashboardUsageRepository()
      ..cachedResult = const [
        AppUsageSummary(
          appName: 'Cached app',
          packageName: 'example.cached',
          totalDurationSeconds: 300,
          percentageOfTotal: 1,
        ),
      ]
      ..todayResults = [liveResult.future];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
    );

    final load = viewModel.loadTodayUsage();
    await _waitUntil(
      () =>
          viewModel.state.summaries.isNotEmpty &&
          viewModel.state.summaries.first.appName == 'Cached app',
    );

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.isRefreshing, isTrue);
    expect(repository.todayCallCount, 1);

    liveResult.complete(const [
      AppUsageSummary(
        appName: 'Fresh app',
        packageName: 'example.fresh',
        totalDurationSeconds: 600,
        percentageOfTotal: 1,
      ),
    ]);
    await load;

    expect(viewModel.state.summaries.single.appName, 'Fresh app');
    expect(viewModel.state.isRefreshing, isFalse);
  });

  test(
    'cached metadata hydrates in parallel without changing cached usage',
    () async {
      final metadataResult = Completer<List<AppUsageSummary>>();
      final liveResult = Completer<List<AppUsageSummary>>();
      final repository = _MetadataDashboardUsageRepository()
        ..cachedResult = const [
          AppUsageSummary(
            appName: 'example.cached',
            packageName: 'example.cached',
            totalDurationSeconds: 300,
            percentageOfTotal: 1,
            launchCount: 4,
          ),
        ]
        ..metadataResults = [metadataResult.future]
        ..todayResults = [liveResult.future];
      final viewModel = DashboardViewModel(
        usageRepository: repository,
        settingsRepository: _DashboardSettingsRepository(),
        platform: UsagePlatform.android,
      );

      final load = viewModel.loadTodayUsage();
      await _waitUntil(
        () =>
            repository.metadataCallCount == 1 && repository.todayCallCount == 1,
      );

      expect(viewModel.state.summaries.single.iconBytes, isNull);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.isRefreshing, isTrue);

      metadataResult.complete([
        AppUsageSummary(
          appName: 'Cached app',
          packageName: 'example.cached',
          totalDurationSeconds: 0,
          percentageOfTotal: 0,
          iconBytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      ]);
      await _waitUntil(
        () => viewModel.state.summaries.single.iconBytes != null,
      );

      final hydrated = viewModel.state.summaries.single;
      expect(hydrated.appName, 'Cached app');
      expect(hydrated.totalDurationSeconds, 300);
      expect(hydrated.percentageOfTotal, 1);
      expect(hydrated.launchCount, 4);
      expect(viewModel.state.isRefreshing, isTrue);

      liveResult.complete(const [
        AppUsageSummary(
          appName: 'Fresh app',
          packageName: 'example.cached',
          totalDurationSeconds: 420,
          percentageOfTotal: 1,
        ),
      ]);
      await load;
      expect(viewModel.state.summaries.single.totalDurationSeconds, 420);
    },
  );

  test('metadata failure leaves cached fallback content visible', () async {
    final liveResult = Completer<List<AppUsageSummary>>();
    final repository = _MetadataDashboardUsageRepository()
      ..cachedResult = const [
        AppUsageSummary(
          appName: 'Fallback app',
          packageName: 'example.fallback',
          totalDurationSeconds: 300,
          percentageOfTotal: 1,
        ),
      ]
      ..metadataError = StateError('metadata failed')
      ..todayResults = [liveResult.future];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
    );

    final load = viewModel.loadTodayUsage();
    await _waitUntil(() => repository.metadataCallCount == 1);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.summaries.single.appName, 'Fallback app');
    expect(viewModel.state.summaries.single.iconBytes, isNull);
    expect(viewModel.state.errorMessage, isNull);
    expect(viewModel.state.refreshErrorMessage, isNull);

    liveResult.complete(const []);
    await load;
  });

  test('metadata from an obsolete dashboard generation is ignored', () async {
    final metadataResult = Completer<List<AppUsageSummary>>();
    final repository = _MetadataDashboardUsageRepository(hasUsageAccess: false)
      ..cachedResult = const [
        AppUsageSummary(
          appName: 'Today cache',
          packageName: 'example.today',
          totalDurationSeconds: 300,
          percentageOfTotal: 1,
        ),
      ]
      ..dailyResult = const [
        AppUsageSummary(
          appName: 'Yesterday',
          packageName: 'example.yesterday',
          totalDurationSeconds: 120,
          percentageOfTotal: 1,
        ),
      ]
      ..metadataResults = [metadataResult.future];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
    );

    await viewModel.loadTodayUsage();
    await viewModel.previousDay();
    metadataResult.complete([
      AppUsageSummary(
        appName: 'Too late',
        packageName: 'example.today',
        totalDurationSeconds: 0,
        percentageOfTotal: 0,
        iconBytes: Uint8List.fromList(const [9]),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.dayOffset, -1);
    expect(viewModel.state.summaries.single.appName, 'Yesterday');
  });

  test('metadata hydrates top ten before remaining cached apps', () async {
    final firstBatch = Completer<List<AppUsageSummary>>();
    final liveResult = Completer<List<AppUsageSummary>>();
    final cached = [
      for (var index = 0; index < 12; index++)
        AppUsageSummary(
          appName: 'App $index',
          packageName: 'example.$index',
          totalDurationSeconds: 120 - index,
          percentageOfTotal: 1 / 12,
        ),
    ];
    final repository = _MetadataDashboardUsageRepository()
      ..cachedResult = cached
      ..metadataResults = [firstBatch.future, Future.value(const [])]
      ..todayResults = [liveResult.future];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
    );

    final load = viewModel.loadTodayUsage();
    await _waitUntil(() => repository.metadataCallCount == 1);
    expect(repository.metadataRequests.single, cached.take(10).toList());

    firstBatch.complete(const []);
    await _waitUntil(() => repository.metadataCallCount == 2);
    expect(repository.metadataRequests[1], cached.skip(10).toList());

    liveResult.complete(const []);
    await load;
  });

  test(
    'no cached Android snapshot keeps initial loading until live data',
    () async {
      final liveResult = Completer<List<AppUsageSummary>>();
      final repository = _DashboardUsageRepository()
        ..todayResults = [liveResult.future];
      final viewModel = DashboardViewModel(
        usageRepository: repository,
        settingsRepository: _DashboardSettingsRepository(),
        platform: UsagePlatform.android,
      );

      final load = viewModel.loadTodayUsage();
      await _waitUntil(() => repository.todayCallCount == 1);

      expect(viewModel.state.summaries, isEmpty);
      expect(viewModel.state.isLoading, isTrue);
      expect(viewModel.state.isRefreshing, isFalse);

      liveResult.complete(const [
        AppUsageSummary(
          appName: 'Live app',
          packageName: 'example.live',
          totalDurationSeconds: 120,
          percentageOfTotal: 1,
        ),
      ]);
      await load;

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.summaries.single.appName, 'Live app');
    },
  );

  test('missing Usage Access leaves a valid cached snapshot visible', () async {
    final repository = _DashboardUsageRepository(hasUsageAccess: false)
      ..cachedResult = const [
        AppUsageSummary(
          appName: 'Cached app',
          packageName: 'example.cached',
          totalDurationSeconds: 300,
          percentageOfTotal: 1,
        ),
      ];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
    );

    await viewModel.loadTodayUsage();

    expect(viewModel.state.hasUsageAccess, isFalse);
    expect(viewModel.state.summaries.single.appName, 'Cached app');
    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.isRefreshing, isFalse);
    expect(repository.todayCallCount, 0);
  });

  test(
    'failed live refresh is non-destructive when cache is visible',
    () async {
      final repository = _DashboardUsageRepository()
        ..cachedResult = const [
          AppUsageSummary(
            appName: 'Cached app',
            packageName: 'example.cached',
            totalDurationSeconds: 300,
            percentageOfTotal: 1,
          ),
        ]
        ..todayError = StateError('live failed');
      final viewModel = DashboardViewModel(
        usageRepository: repository,
        settingsRepository: _DashboardSettingsRepository(),
        platform: UsagePlatform.android,
      );

      await viewModel.loadTodayUsage();

      expect(viewModel.state.summaries.single.appName, 'Cached app');
      expect(viewModel.state.errorMessage, isNull);
      expect(viewModel.state.refreshErrorMessage, contains('live failed'));
      expect(viewModel.state.isRefreshing, isFalse);
    },
  );

  test(
    'failed initial live load remains a destructive initial error',
    () async {
      final repository = _DashboardUsageRepository()
        ..todayError = StateError('live failed');
      final viewModel = DashboardViewModel(
        usageRepository: repository,
        settingsRepository: _DashboardSettingsRepository(),
        platform: UsagePlatform.android,
      );

      await viewModel.loadTodayUsage();

      expect(viewModel.state.summaries, isEmpty);
      expect(viewModel.state.errorMessage, contains('live failed'));
      expect(viewModel.state.refreshErrorMessage, isNull);
      expect(viewModel.state.isLoading, isFalse);
    },
  );

  test('silent refresh never clears an already populated graph', () async {
    final refreshed = Completer<List<AppUsageSummary>>();
    final repository = _DashboardUsageRepository()
      ..todayResults = [
        Future.value(const [
          AppUsageSummary(
            appName: 'Current app',
            packageName: 'example.current',
            totalDurationSeconds: 300,
            percentageOfTotal: 1,
          ),
        ]),
        refreshed.future,
      ];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
    );
    await viewModel.loadTodayUsage();

    final refresh = viewModel.refreshSilently();
    await _waitUntil(() => repository.todayCallCount == 2);

    expect(viewModel.state.summaries.single.appName, 'Current app');
    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.isRefreshing, isTrue);

    refreshed.complete(const [
      AppUsageSummary(
        appName: 'Updated app',
        packageName: 'example.updated',
        totalDurationSeconds: 360,
        percentageOfTotal: 1,
      ),
    ]);
    await refresh;

    expect(viewModel.state.summaries.single.appName, 'Updated app');
    expect(viewModel.state.isRefreshing, isFalse);
  });

  test('local-day change reads only the new day snapshot', () async {
    var now = DateTime(2026, 8, 27, 23, 59);
    final firstDay = DateTime(2026, 8, 27);
    final secondDay = DateTime(2026, 8, 28);
    final repository = _DashboardUsageRepository(hasUsageAccess: false)
      ..cachedResultsByDay[_dayKey(firstDay)] = const [
        AppUsageSummary(
          appName: 'First day',
          packageName: 'example.first',
          totalDurationSeconds: 300,
          percentageOfTotal: 1,
        ),
      ]
      ..cachedResultsByDay[_dayKey(secondDay)] = const [
        AppUsageSummary(
          appName: 'Second day',
          packageName: 'example.second',
          totalDurationSeconds: 60,
          percentageOfTotal: 1,
        ),
      ];
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
      clock: () => now,
    );

    await viewModel.loadTodayUsage();
    expect(viewModel.state.summaries.single.appName, 'First day');

    now = DateTime(2026, 8, 28);
    await viewModel.refreshSilently();

    expect(viewModel.state.summaries.single.appName, 'Second day');
    expect(repository.cachedDays, [firstDay, secondDay]);
  });

  test('auxiliary dashboard data does not delay fresh summaries', () async {
    final allTimeResult = Completer<List<AppUsageSummary>>();
    final historyResult = Completer<List<DailyAppUsage>>();
    final repository = _DashboardUsageRepository()
      ..todayResult = const [
        AppUsageSummary(
          appName: 'Live app',
          packageName: 'example.live',
          totalDurationSeconds: 120,
          percentageOfTotal: 1,
        ),
      ]
      ..allTimeFuture = allTimeResult.future
      ..historyFuture = historyResult.future;
    final viewModel = DashboardViewModel(
      usageRepository: repository,
      settingsRepository: _DashboardSettingsRepository(),
      platform: UsagePlatform.android,
    );

    await viewModel.loadTodayUsage();

    expect(viewModel.state.summaries.single.appName, 'Live app');
    expect(viewModel.state.allTimeTopApps, isEmpty);
    expect(viewModel.state.trendsByAppKey, isEmpty);

    allTimeResult.complete(const []);
    historyResult.complete(const []);
  });
}

class _DashboardUsageRepository implements UsageRepository {
  _DashboardUsageRepository({bool hasUsageAccess = true})
    : _hasUsageAccess = hasUsageAccess;

  final bool _hasUsageAccess;
  List<AppUsageSummary> dailyResult = const [];
  List<AppUsageSummary> cachedResult = const [];
  final Map<String, List<AppUsageSummary>> cachedResultsByDay = {};
  final List<DateTime> cachedDays = [];
  List<AppUsageSummary> todayResult = const [];
  List<Future<List<AppUsageSummary>>> todayResults = const [];
  Object? todayError;
  List<AppUsageSummary> allTimeResult = const [];
  List<DailyAppUsage> historyResult = const [];
  Future<List<AppUsageSummary>>? allTimeFuture;
  Future<List<DailyAppUsage>>? historyFuture;
  List<Future<List<AppUsageSummary>>> dailyResults = const [];
  int _dailyCallCount = 0;
  int todayCallCount = 0;

  @override
  Future<bool> hasUsageAccess() async => _hasUsageAccess;

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) {
    if (_dailyCallCount < dailyResults.length) {
      return dailyResults[_dailyCallCount++];
    }
    return Future.value(dailyResult);
  }

  @override
  Future<List<AppUsageSummary>> getCachedTodaySummaries(DateTime day) async {
    cachedDays.add(DateTime(day.year, day.month, day.day));
    return cachedResultsByDay[_dayKey(day)] ?? cachedResult;
  }

  @override
  Future<List<AppUsageSummary>> getTodaySummaries() {
    final index = todayCallCount++;
    if (todayError case final error?) {
      return Future<List<AppUsageSummary>>.error(error);
    }
    if (index < todayResults.length) {
      return todayResults[index];
    }
    return Future.value(todayResult);
  }

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() =>
      allTimeFuture ?? Future.value(allTimeResult);

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) => historyFuture ?? Future.value(historyResult);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MetadataDashboardUsageRepository extends _DashboardUsageRepository
    implements AppMetadataRepository {
  _MetadataDashboardUsageRepository({super.hasUsageAccess});

  List<Future<List<AppUsageSummary>>> metadataResults = const [];
  Object? metadataError;
  int metadataCallCount = 0;
  final List<List<AppUsageSummary>> metadataRequests = [];

  @override
  Future<List<AppUsageSummary>> hydrateAppMetadata(
    List<AppUsageSummary> summaries,
  ) {
    metadataRequests.add(summaries);
    final index = metadataCallCount++;
    if (metadataError case final error?) {
      return Future<List<AppUsageSummary>>.error(error);
    }
    if (index < metadataResults.length) {
      return metadataResults[index];
    }
    return Future.value(summaries);
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

class _DashboardSettingsRepository implements SettingsRepository {
  @override
  Future<List<String>> excludedApps() async => const [];

  @override
  Future<Set<String>> hiddenAppsForToday() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
