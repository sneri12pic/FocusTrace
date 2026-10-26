import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  group('blockNow', () {
    test('blocks before expiry and not at or after expiry', () {
      final until = DateTime(2026, 7, 4, 14);
      final rule = RestrictionRule.blockNow(
        appKey: 'app',
        appName: 'App',
        until: until,
      );

      expect(rule.blocksAt(DateTime(2026, 7, 4, 13, 59), 0), isTrue);
      expect(rule.blocksAt(until, 0), isFalse);
      expect(rule.blocksAt(DateTime(2026, 7, 4, 14, 1), 0), isFalse);
    });
  });

  group('schedule', () {
    test('crossing midnight blocks inside the window', () {
      final rule = RestrictionRule.schedule(
        appKey: 'app',
        appName: 'App',
        startMinute: 22 * 60,
        endMinute: 7 * 60,
      );

      expect(rule.blocksAt(DateTime(2026, 7, 4, 21, 59), 0), isFalse);
      expect(rule.blocksAt(DateTime(2026, 7, 4, 22), 0), isTrue);
      expect(rule.blocksAt(DateTime(2026, 7, 4, 23, 30), 0), isTrue);
      expect(rule.blocksAt(DateTime(2026, 7, 5, 3), 0), isTrue);
      expect(rule.blocksAt(DateTime(2026, 7, 5, 6, 59), 0), isTrue);
      expect(rule.blocksAt(DateTime(2026, 7, 5, 7), 0), isFalse);
      expect(rule.blocksAt(DateTime(2026, 7, 5, 12), 0), isFalse);
    });

    test('non-crossing schedule blocks inside the window only', () {
      final rule = RestrictionRule.schedule(
        appKey: 'app',
        appName: 'App',
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      );

      expect(rule.blocksAt(DateTime(2026, 7, 4, 8, 59), 0), isFalse);
      expect(rule.blocksAt(DateTime(2026, 7, 4, 9), 0), isTrue);
      expect(rule.blocksAt(DateTime(2026, 7, 4, 12), 0), isTrue);
      expect(rule.blocksAt(DateTime(2026, 7, 4, 16, 59), 0), isTrue);
      expect(rule.blocksAt(DateTime(2026, 7, 4, 17), 0), isFalse);
    });
  });

  test('dailyLimit blocks at limit, not one second before', () {
    final rule = RestrictionRule.dailyLimit(
      appKey: 'app',
      appName: 'App',
      limitMinutes: 60,
    );

    expect(rule.blocksAt(DateTime(2026, 7, 4, 12), 60 * 60 - 1), isFalse);
    expect(rule.blocksAt(DateTime(2026, 7, 4, 12), 60 * 60), isTrue);
  });

  test('JSON round trip preserves rules and garbage decodes to empty', () {
    final rules = [
      RestrictionRule.blockNow(
        appKey: 'one',
        appName: 'One',
        until: DateTime(2026, 7, 4, 14),
      ),
      RestrictionRule.dailyLimit(
        appKey: 'two',
        appName: 'Two',
        limitMinutes: 45,
      ),
      RestrictionRule.schedule(
        appKey: 'three',
        appName: 'Three',
        startMinute: 22 * 60,
        endMinute: 7 * 60,
      ),
    ];

    final decoded = decodeRules(encodeRules(rules));

    expect(
      decoded.map((rule) => rule.toJson()),
      rules.map((rule) => rule.toJson()),
    );
    expect(decodeRules('not json'), isEmpty);
  });

  test('pruning removes expired blockNow rules', () {
    final pruned = pruneExpiredBlockNowRules([
      RestrictionRule.blockNow(
        appKey: 'expired',
        appName: 'Expired',
        until: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      RestrictionRule.dailyLimit(
        appKey: 'limit',
        appName: 'Limit',
        limitMinutes: 30,
      ),
    ]);

    expect(pruned.map((rule) => rule.appKey), ['limit']);
  });

  test('any matching rule wins', () {
    final rules = [
      RestrictionRule.dailyLimit(
        appKey: 'app',
        appName: 'App',
        limitMinutes: 60,
      ),
      RestrictionRule.schedule(
        appKey: 'app',
        appName: 'App',
        startMinute: 22 * 60,
        endMinute: 7 * 60,
      ),
    ];

    expect(
      isAppBlocked(
        appKey: 'app',
        rules: rules,
        now: DateTime(2026, 7, 4, 22),
        usageSecondsToday: 0,
      ),
      isTrue,
    );
  });

  test('rules group under their category in category order', () {
    final tiktok = RestrictionRule.dailyLimit(
      appKey: 'com.zhiliaoapp.musically',
      appName: 'TikTok',
      limitMinutes: 60,
    );
    final slack = RestrictionRule.schedule(
      appKey: 'com.Slack',
      appName: 'Slack',
      startMinute: 0,
      endMinute: 60,
    );
    final notes = RestrictionRule.dailyLimit(
      appKey: 'com.example.notes',
      appName: 'Notes',
      limitMinutes: 30,
    );
    final groups = groupRulesByCategory(
      [slack, tiktok, notes],
      const {},
      {'com.example.notes': UsageCategory.productivity},
    );
    expect(groups.map((group) => group.key), [
      UsageCategory.entertainment,
      UsageCategory.productivity,
      UsageCategory.communication,
    ]);
    expect(groups.first.value, [tiktok]);
    expect(groups[1].value, [notes]);
  });
}
