import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

/// The configuration Dart syncs to iOS. `tool/ios/kit_tests` (run by the
/// `ios-build` CI job) decodes this same file in FocusTraceKit and checks that
/// re-encoding it in Swift yields the same JSON, so a change on either side
/// breaks a test instead of iOS enforcement.
const fixturePath = 'test/fixtures/ios_restriction_configuration.json';

final fixtureRules = [
  const RestrictionRule(
    appKey: 'ios-sel:0f8fad5b-d9cb-469f-a165-70867728950e',
    appName: 'Social',
    type: RestrictionRuleType.blockNow,
    untilMs: 1793995200000,
    difficulty: RestrictionDifficulty.easy,
  ),
  const RestrictionRule(
    appKey: 'ios-sel:7c9e6679-7425-40de-944b-e07fc1f90ae7',
    appName: 'Evenings',
    type: RestrictionRuleType.schedule,
    startMinute: 22 * 60,
    endMinute: 7 * 60,
    difficulty: RestrictionDifficulty.moderate,
    weekdays: [1, 2, 3, 4, 5],
  ),
  const RestrictionRule(
    appKey: 'ios-sel:7c9e6679-7425-40de-944b-e07fc1f90ae7',
    appName: 'Evenings',
    type: RestrictionRuleType.blockNow,
    untilMs: 1793998800000,
    difficulty: RestrictionDifficulty.hard,
  ),
  const RestrictionRule(
    appKey: 'com.example.video',
    appName: 'Video',
    type: RestrictionRuleType.dailyLimit,
    limitMinutes: 45,
  ),
  const RestrictionRule(
    appKey: 'ios-sel:3b241101-e2bb-4255-8caf-4136c566a962',
    appName: 'Games',
    type: RestrictionRuleType.dailyLimit,
    limitMinutes: 30,
    difficulty: RestrictionDifficulty.moderate,
  ),
];

final fixtureRoutines = [
  const BlockRoutine(
    id: 'routine-1',
    name: 'Study',
    dailyLimitMinutes: 60,
    isEnabled: true,
    apps: [
      RoutineApp(appKey: 'com.example.chat', appName: 'Chat'),
      RoutineApp(
        appKey: 'com.example.game',
        appName: 'Game',
        isIncludedInLimit: false,
        limitMinutes: 15,
      ),
    ],
  ),
  // A routine over picked selections: its included apps share 90 minutes,
  // Games is also capped alone, Evenings only has its own cap.
  const BlockRoutine(
    id: 'routine-2',
    name: 'Downtime',
    dailyLimitMinutes: 90,
    isEnabled: true,
    apps: [
      RoutineApp(
        appKey: 'ios-sel:0f8fad5b-d9cb-469f-a165-70867728950e',
        appName: 'Social',
      ),
      RoutineApp(
        appKey: 'ios-sel:3b241101-e2bb-4255-8caf-4136c566a962',
        appName: 'Games',
        limitMinutes: 20,
      ),
      RoutineApp(
        appKey: 'ios-sel:7c9e6679-7425-40de-944b-e07fc1f90ae7',
        appName: 'Evenings',
        isIncludedInLimit: false,
        limitMinutes: 10,
      ),
    ],
  ),
  // Disabled routines are not sent.
  const BlockRoutine(
    id: 'routine-3',
    name: 'Paused',
    dailyLimitMinutes: 30,
    apps: [
      RoutineApp(
        appKey: 'ios-sel:0f8fad5b-d9cb-469f-a165-70867728950e',
        appName: 'Social',
      ),
    ],
  ),
];

void main() {
  test('the iOS fixture is what Dart sends through syncRestrictions', () {
    final encoded = encodeRestrictionConfiguration(
      fixtureRules,
      fixtureRoutines,
    );
    final fixture = File(fixturePath).readAsStringSync();
    expect(jsonDecode(fixture), jsonDecode(encoded));
  });

  test('Dart decodes the fixture back to the same rules', () {
    final rules = decodeRules(File(fixturePath).readAsStringSync());
    expect(encodeRules(rules), encodeRules(fixtureRules));
  });
}
