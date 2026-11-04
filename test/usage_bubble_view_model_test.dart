import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  group('category usage', () {
    AppUsageSummary app(String name, int seconds) => AppUsageSummary(
      appName: name,
      packageName: name,
      totalDurationSeconds: seconds,
      percentageOfTotal: 0,
    );

    test(
      'sorts by usage, adds up to the total and files fallbacks as Other',
      () {
        final viewModel = UsageBubbleViewModel();
        addTearDown(viewModel.dispose);
        final rows = viewModel.categoryUsageFor([
          app('YouTube', 600),
          app('TikTok', 300),
          app('Chrome', 1500),
          app('Unknown tool', 1000),
          app('Another tool', 500),
          app('Zero', 0),
        ]);
        expect(rows.map((row) => row.category), [
          UsageCategory.web,
          null,
          UsageCategory.entertainment,
        ]);
        expect(rows.map((row) => row.seconds), [1500, 1500, 900]);
        expect(rows.fold(0, (sum, row) => sum + row.seconds), 3900);
        expect(rows.fold(0.0, (sum, row) => sum + row.share), closeTo(1, 1e-9));
      },
    );

    test('an override moves all of an app, and chosen Activity stays', () {
      final viewModel = UsageBubbleViewModel();
      addTearDown(viewModel.dispose);
      final rows = viewModel.categoryUsageFor(
        [app('YouTube', 600), app('Unknown tool', 400), app('Chrome', 100)],
        categoryOverrides: const {
          'YouTube': UsageCategory.productivity,
          'Unknown tool': UsageCategory.activity,
        },
      );
      expect(rows.map((row) => row.category), [
        UsageCategory.productivity,
        UsageCategory.activity,
        UsageCategory.web,
      ]);
      expect(rows.map((row) => row.seconds), [600, 400, 100]);
    });

    test('no usage gives no rows', () {
      final viewModel = UsageBubbleViewModel();
      addTearDown(viewModel.dispose);
      expect(viewModel.categoryUsageFor(const []), isEmpty);
      expect(viewModel.categoryUsageFor([app('Zero', 0)]), isEmpty);
    });
  });

  test('near-limit ids start at 85 percent and exclude blocked apps', () {
    final viewModel = UsageBubbleViewModel();
    addTearDown(viewModel.dispose);
    final now = DateTime(2026, 7, 19, 12);
    const summaries = [
      AppUsageSummary(
        appName: 'Near',
        packageName: 'near.app',
        totalDurationSeconds: 510,
        percentageOfTotal: 0,
      ),
      AppUsageSummary(
        appName: 'Below',
        packageName: 'below.app',
        totalDurationSeconds: 509,
        percentageOfTotal: 0,
      ),
      AppUsageSummary(
        appName: 'At limit',
        packageName: 'limit.app',
        totalDurationSeconds: 600,
        percentageOfTotal: 0,
      ),
      AppUsageSummary(
        appName: 'Blocked',
        packageName: 'blocked.app',
        totalDurationSeconds: 510,
        percentageOfTotal: 0,
      ),
      AppUsageSummary(
        appName: 'No rule',
        packageName: 'none.app',
        totalDurationSeconds: 510,
        percentageOfTotal: 0,
      ),
    ];
    final rules = [
      for (final appKey in const [
        'near.app',
        'below.app',
        'limit.app',
        'blocked.app',
      ])
        RestrictionRule.dailyLimit(
          appKey: appKey,
          appName: appKey,
          limitMinutes: 10,
        ),
      RestrictionRule.blockNow(
        appKey: 'blocked.app',
        appName: 'Blocked',
        until: now.add(const Duration(hours: 1)),
      ),
    ];

    final nearLimitIds = viewModel.nearLimitItemIds(
      summaries: summaries,
      rules: rules,
      now: now,
    );

    expect(nearLimitIds, {'near.app'});
  });
}
