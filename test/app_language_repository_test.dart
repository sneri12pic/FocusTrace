import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test('app language repository reads and writes locale tags', () async {
    final dataSource = _MemoryLocalDataSource()
      ..settings['app_language'] = 'pt_BR';
    final repository = AppLanguageRepositoryImpl(dataSource);

    expect(await repository.appLanguage(), AppLanguage.portugueseBrazil);

    await repository.setAppLanguage(AppLanguage.japanese);
    expect(dataSource.settings['app_language'], 'ja');

    await repository.setAppLanguage(AppLanguage.system);
    expect(dataSource.settings['app_language'], 'system');
  });
}

class _MemoryLocalDataSource implements FocusTraceLocalDataSource {
  final Map<String, String> settings = {};

  @override
  Future<void> clearAllData() async {
    settings.clear();
  }

  @override
  Future<List<UsageSession>> getSessionsForDate(DateTime date) async =>
      const [];

  @override
  Future<void> saveDailySummaries(
    DateTime day,
    List<AppUsageSummary> summaries,
  ) async {}

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async =>
      const [];

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() async => const [];

  @override
  Future<List<DailyAppUsage>> getUsageHistory(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) async => const [];

  @override
  Future<void> insertSession(UsageSession session) async {}

  @override
  Future<void> insertSessions(List<UsageSession> sessions) async {}

  @override
  Future<String?> readSetting(String key) async => settings[key];

  @override
  Future<void> writeSetting(String key, String value) async {
    settings[key] = value;
  }
}
