import 'package:flutter_test/flutter_test.dart';

import 'package:focustrace/focus_trace.dart';

void main() {
  group('UsageRepositoryImpl.topSessionsForApp', () {
    final day = DateTime(2026, 1, 1);

    UsageSession session({
      required String id,
      required String processName,
      required int startHour,
      required int durationMinutes,
    }) {
      return UsageSession(
        id: id,
        platform: UsagePlatform.windows,
        appName: processName,
        processName: processName,
        startedAt: day.add(Duration(hours: startHour)),
        endedAt: day.add(Duration(hours: startHour, minutes: durationMinutes)),
        durationSeconds: durationMinutes * 60,
        createdAt: day,
      );
    }

    UsageRepositoryImpl repositoryWith(
      List<UsageSession> sessions, {
      UsagePlatform platform = UsagePlatform.windows,
    }) {
      return UsageRepositoryImpl(
        platform: platform,
        localDataSource: _InMemoryLocalDataSource(sessions),
        platformDataSource: const UnsupportedPlatformUsageDataSource(),
      );
    }

    test('returns the longest sessions first, capped at the limit', () async {
      final repository = repositoryWith([
        session(
          id: 'a1',
          processName: 'editor.exe',
          startHour: 9,
          durationMinutes: 10,
        ),
        session(
          id: 'a2',
          processName: 'editor.exe',
          startHour: 11,
          durationMinutes: 67,
        ),
        session(
          id: 'a3',
          processName: 'editor.exe',
          startHour: 13,
          durationMinutes: 25,
        ),
        session(
          id: 'a4',
          processName: 'editor.exe',
          startHour: 15,
          durationMinutes: 40,
        ),
        session(
          id: 'b1',
          processName: 'browser.exe',
          startHour: 10,
          durationMinutes: 90,
        ),
      ]);

      final top = await repository.topSessionsForApp('editor.exe', day);

      expect(top.map((session) => session.id), ['a2', 'a4', 'a3']);
    });

    test('returns fewer sessions when fewer exist', () async {
      final repository = repositoryWith([
        session(
          id: 'a1',
          processName: 'editor.exe',
          startHour: 9,
          durationMinutes: 10,
        ),
      ]);

      final top = await repository.topSessionsForApp('editor.exe', day);

      expect(top, hasLength(1));
      expect(top.single.id, 'a1');
    });

    test('returns nothing on platforms without local sessions', () async {
      final repository = repositoryWith([
        session(
          id: 'a1',
          processName: 'editor.exe',
          startHour: 9,
          durationMinutes: 10,
        ),
      ], platform: UsagePlatform.android);

      final top = await repository.topSessionsForApp('editor.exe', day);

      expect(top, isEmpty);
    });
  });
}

class _InMemoryLocalDataSource implements FocusTraceLocalDataSource {
  _InMemoryLocalDataSource(this._sessions);

  final List<UsageSession> _sessions;
  final Map<String, String> _settings = {};

  @override
  Future<void> insertSession(UsageSession session) async {
    _sessions.add(session);
  }

  @override
  Future<void> insertSessions(List<UsageSession> sessions) async {
    _sessions.addAll(sessions);
  }

  @override
  Future<List<UsageSession>> getSessionsForDate(DateTime date) async {
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    return _sessions.where((session) => session.overlaps(from, to)).toList();
  }

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
  Future<String?> readSetting(String key) async => _settings[key];

  @override
  Future<void> writeSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<void> clearAllData() async {
    _sessions.clear();
    _settings.clear();
  }
}
