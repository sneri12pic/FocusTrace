import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test('limits survive storage and malformed rows are dropped', () {
    const limits = [
      PreferredLimit(category: UsageCategory.web, minutes: 30),
      PreferredLimit(appKey: 'com.app', appName: 'App', minutes: 45),
    ];

    final restored = decodePreferredLimits(encodePreferredLimits(limits));

    expect(restored.first.category, UsageCategory.web);
    expect(restored.last.appKey, 'com.app');
    expect(restored.last.appName, 'App');
    expect(restored.last.minutes, 45);
    expect(
      decodePreferredLimits('[{"minutes":0,"appKey":"a"},{"minutes":5},7]'),
      isEmpty,
    );
    expect(decodePreferredLimits('not json'), isEmpty);
  });

  test('blocker payload expands categories without excluded apps', () {
    const app = AppUsageSummary(
      appName: 'YouTube',
      packageName: 'yt',
      totalDurationSeconds: 0,
      percentageOfTotal: 0,
    );
    final payload = preferredLimitsForBlocker(
      const [
        PreferredLimit(category: UsageCategory.entertainment, minutes: 30),
        PreferredLimit(category: UsageCategory.web, minutes: 20),
        PreferredLimit(appKey: 'solo', minutes: 10),
      ],
      installedApps: [
        app,
        app.copyWith(packageName: 'hidden'),
        app.copyWith(packageName: 'moved'),
        app.copyWith(appName: 'Notes', packageName: 'notes'),
      ],
      categoryOverrides: const {
        'moved': UsageCategory.productivity,
        'notes': UsageCategory.entertainment,
      },
      excludedApps: const ['hidden'],
    );

    expect(payload, [
      {
        'limitMinutes': 30,
        'apps': ['yt', 'notes'],
      },
      {
        'limitMinutes': 10,
        'apps': ['solo'],
      },
    ]);
    expect(
      jsonDecode(
        encodeRestrictionConfiguration(
          const [],
          const [],
          preferredLimits: payload,
        ),
      )['preferredLimits'],
      payload,
    );
  });
}
