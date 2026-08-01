import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test(
    'historical Android summaries receive current labels and icons',
    () async {
      final icon = Uint8List.fromList(const [1, 2, 3]);
      final localDataSource = _HistoricalLocalDataSource()
        ..summaries = const [
          AppUsageSummary(
            appName: 'example.app',
            packageName: 'example.app',
            totalDurationSeconds: 600,
            percentageOfTotal: 0,
          ),
        ];
      final platformDataSource = _HistoricalPlatformDataSource()
        ..metadata = [
          AppUsageSummary(
            appName: 'Friendly Example',
            packageName: 'example.app',
            totalDurationSeconds: 0,
            percentageOfTotal: 0,
            iconBytes: icon,
          ),
        ];
      final repository = UsageRepositoryImpl(
        platform: UsagePlatform.android,
        localDataSource: localDataSource,
        platformDataSource: platformDataSource,
      );

      final result = await repository.getDailySummaries(DateTime(2026, 7, 18));

      expect(platformDataSource.requestedKeys, {'example.app'});
      expect(result.single.appName, 'Friendly Example');
      expect(result.single.iconBytes, same(icon));
      expect(result.single.percentageOfTotal, 1);
    },
  );

  test(
    'historical summaries keep their placeholder when an app is missing',
    () async {
      final localDataSource = _HistoricalLocalDataSource()
        ..summaries = const [
          AppUsageSummary(
            appName: 'Uninstalled',
            packageName: 'missing.app',
            totalDurationSeconds: 300,
            percentageOfTotal: 0,
          ),
        ];
      final repository = UsageRepositoryImpl(
        platform: UsagePlatform.android,
        localDataSource: localDataSource,
        platformDataSource: _HistoricalPlatformDataSource(),
      );

      final result = await repository.getDailySummaries(DateTime(2026, 7, 18));

      expect(result.single.iconBytes, isNull);
      expect(result.single.appName, 'Uninstalled');
    },
  );
}

class _HistoricalLocalDataSource implements FocusTraceLocalDataSource {
  List<AppUsageSummary> summaries = const [];

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async =>
      summaries;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoricalPlatformDataSource
    implements PlatformUsageDataSource, AppMetadataDataSource {
  List<AppUsageSummary> metadata = const [];
  Set<String> requestedKeys = const {};

  @override
  Future<List<AppUsageSummary>> getAppMetadata(Iterable<String> appKeys) async {
    requestedKeys = appKeys.toSet();
    return metadata;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
