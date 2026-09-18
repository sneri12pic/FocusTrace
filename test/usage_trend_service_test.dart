import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  group('UsageTrendChange.compare', () {
    UsageTrendChange compare(
      int current,
      int previous, {
      bool covered = true,
    }) => UsageTrendChange.compare(
      currentSeconds: current,
      previousSeconds: previous,
      previousWindowCovered: covered,
    );

    test('normal increase keeps the genuine percentage', () {
      final change = compare(150, 100);
      expect(change.state, UsageTrendState.change);
      expect(change.percent, 50);
      expect(change.displayMagnitude, 50);
      expect(change.exceedsDisplayCap, isFalse);
    });

    test('normal decrease', () {
      final change = compare(250, 1000);
      expect(change.state, UsageTrendState.change);
      expect(change.percent, -75);
      expect(change.displayMagnitude, 75);
    });

    test('dropping to zero is exactly -100%', () {
      final change = compare(0, 600);
      expect(change.percent, -100);
      expect(change.displayMagnitude, 100);
    });

    test('decrease from a tiny baseline is still a bounded percentage', () {
      final change = compare(0, 5);
      expect(change.state, UsageTrendState.change);
      expect(change.percent, -100);
    });

    test('unchanged usage is neutral', () {
      expect(compare(600, 600).state, UsageTrendState.unchanged);
    });

    test('zero to zero is unchanged, not New or a division', () {
      final change = compare(0, 0);
      expect(change.state, UsageTrendState.unchanged);
      expect(change.percent, isNull);
    });

    test('previous zero and current positive is New', () {
      final change = compare(1, 0);
      expect(change.state, UsageTrendState.newUsage);
      expect(change.percent, isNull);
    });

    test('a baseline under a minute is not meaningful for an increase', () {
      // 28 s -> 112 h is the "+1459129%" shape.
      expect(compare(405315, 28).state, UsageTrendState.newUsage);
      expect(compare(59, 0).state, UsageTrendState.newUsage);
    });

    test('huge valid increase keeps the raw value but caps the display', () {
      final change = compare(86400, 60);
      expect(change.state, UsageTrendState.change);
      expect(change.percent, 143900);
      expect(change.displayMagnitude, UsageTrendChange.maxDisplayPercent);
      expect(change.exceedsDisplayCap, isTrue);
    });

    test('exactly the cap is not marked as exceeding it', () {
      final atCap = compare(1099, 100);
      expect(atCap.percent, closeTo(999, 1e-9));
      expect(atCap.exceedsDisplayCap, isFalse);
      expect(compare(1100, 100).exceedsDisplayCap, isTrue);
    });

    test('uncovered previous window is unavailable whatever the values', () {
      expect(
        compare(150, 100, covered: false).state,
        UsageTrendState.unavailable,
      );
      expect(compare(0, 0, covered: false).state, UsageTrendState.unavailable);
      expect(compare(10, 0, covered: false).percent, isNull);
    });
  });

  group('UsageTrendService', () {
    const service = UsageTrendService();
    final throughDay = DateTime(2026, 7, 19);
    DateTime ago(int days) => throughDay.subtract(Duration(days: days));
    // Another app's row at the oldest loaded day proves 60 days of coverage.
    final coverage = _usage(ago(59), 60, app: 'filler.app');

    test('calculates rolling day, week, and month changes per app', () {
      final trend = service.calculate(
        history: [
          coverage,
          _usage(throughDay, 150),
          _usage(ago(1), 100),
          _usage(ago(7), 500),
          _usage(ago(30), 500),
        ],
        throughDay: throughDay,
        appKeys: const ['example.app'],
      )['example.app']!;

      expect(trend.day.percent, 50);
      expect(trend.week.percent, -50);
      expect(trend.month.percent, 50);
    });

    test('day, week and month share the same New and unchanged semantics', () {
      final trends = service.calculate(
        history: [
          coverage,
          _usage(throughDay, 3600),
          _usage(throughDay, 60, app: 'flat.app'),
          _usage(ago(1), 60, app: 'flat.app'),
          _usage(ago(7), 60, app: 'flat.app'),
          _usage(ago(29), 60, app: 'flat.app'),
          _usage(ago(30), 60, app: 'flat.app'),
          _usage(ago(40), 60, app: 'flat.app'),
          _usage(ago(50), 60, app: 'flat.app'),
          _usage(ago(59), 60, app: 'flat.app'),
        ],
        throughDay: throughDay,
        appKeys: const ['example.app', 'flat.app', 'empty.app'],
      );

      final newApp = trends['example.app']!;
      expect(
        [newApp.day, newApp.week, newApp.month].map((c) => c.state),
        everyElement(UsageTrendState.newUsage),
      );
      final flat = trends['flat.app']!;
      expect(flat.day.state, UsageTrendState.unchanged);
      expect(flat.week.state, UsageTrendState.change);
      expect(flat.month.state, UsageTrendState.unchanged);
      final empty = trends['empty.app']!;
      expect(
        [empty.day, empty.week, empty.month].map((c) => c.state),
        everyElement(UsageTrendState.unchanged),
      );
    });

    test('a partly recorded previous window is unavailable, not a percent', () {
      // History starts 13 days ago: D and W can be compared, M cannot.
      final trend = service.calculate(
        history: [
          _usage(throughDay, 36000),
          _usage(ago(1), 3600),
          _usage(ago(8), 3600),
          _usage(ago(13), 3600),
        ],
        throughDay: throughDay,
        appKeys: const ['example.app'],
      )['example.app']!;

      expect(trend.day.state, UsageTrendState.change);
      expect(trend.week.state, UsageTrendState.change);
      expect(trend.month.state, UsageTrendState.unavailable);
      expect(trend.month.percent, isNull);
    });

    test('no history at all shows no badge', () {
      final trends = service.calculate(
        history: [_usage(throughDay, 60)],
        throughDay: throughDay,
        appKeys: const ['example.app', 'empty.app'],
      );

      expect(trends['example.app']!.hasData, isFalse);
      expect(trends['empty.app']!.hasData, isFalse);
    });
  });
}

DailyAppUsage _usage(DateTime day, int seconds, {String app = 'example.app'}) {
  return DailyAppUsage(
    day: day,
    summary: AppUsageSummary(
      appName: 'Example',
      packageName: app,
      totalDurationSeconds: seconds,
      percentageOfTotal: 0,
    ),
  );
}
