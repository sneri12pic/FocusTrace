import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
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
