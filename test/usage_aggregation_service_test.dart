import 'package:flutter_test/flutter_test.dart';

import 'package:focustrace/focus_trace.dart';

void main() {
  group('UsageAggregationService', () {
    test('groups sessions by app and calculates percentages', () {
      final service = UsageAggregationService();
      final day = DateTime.utc(2026, 1, 1);

      final summaries = service.summarizeSessions(
        [
          UsageSession(
            id: 'a1',
            platform: UsagePlatform.windows,
            appName: 'Editor',
            processName: 'editor.exe',
            startedAt: day.add(const Duration(hours: 9)),
            endedAt: day.add(const Duration(hours: 10)),
            durationSeconds: 3600,
            createdAt: day,
          ),
          UsageSession(
            id: 'b1',
            platform: UsagePlatform.windows,
            appName: 'Browser',
            processName: 'browser.exe',
            startedAt: day.add(const Duration(hours: 11)),
            endedAt: day.add(const Duration(hours: 11, minutes: 30)),
            durationSeconds: 1800,
            createdAt: day,
          ),
          UsageSession(
            id: 'a2',
            platform: UsagePlatform.windows,
            appName: 'Editor',
            processName: 'editor.exe',
            startedAt: day.add(const Duration(hours: 12)),
            endedAt: day.add(const Duration(hours: 12, minutes: 30)),
            durationSeconds: 1800,
            createdAt: day,
          ),
        ],
        from: day,
        to: day.add(const Duration(days: 1)),
      );

      expect(summaries, hasLength(2));
      expect(summaries.first.processName, 'editor.exe');
      expect(summaries.first.totalDurationSeconds, 5400);
      expect(summaries.first.launchCount, 2);
      expect(summaries.first.percentageOfTotal, closeTo(0.75, 0.001));
      expect(summaries.last.processName, 'browser.exe');
    });

    test('clips sessions to the requested window', () {
      final service = UsageAggregationService();
      final day = DateTime.utc(2026, 1, 1);

      final summaries = service.summarizeSessions(
        [
          UsageSession(
            id: 'a1',
            platform: UsagePlatform.windows,
            appName: 'Editor',
            processName: 'editor.exe',
            startedAt: day.subtract(const Duration(minutes: 30)),
            endedAt: day.add(const Duration(minutes: 30)),
            durationSeconds: 3600,
            createdAt: day,
          ),
        ],
        from: day,
        to: day.add(const Duration(hours: 1)),
      );

      expect(summaries.single.totalDurationSeconds, 1800);
    });
  });
}
