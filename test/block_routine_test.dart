import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test('routine JSON preserves its name, state, and unique apps', () {
    const routine = BlockRoutine(
      id: 'bedtime',
      name: 'Bedtime',
      dailyLimitMinutes: 180,
      isEnabled: true,
      apps: [
        RoutineApp(appKey: 'social', appName: 'Social'),
        RoutineApp(appKey: 'video', appName: 'Video', isIncludedInLimit: false),
      ],
    );

    final decoded = decodeBlockRoutines(encodeBlockRoutines([routine])).single;

    expect(decoded.id, 'bedtime');
    expect(decoded.name, 'Bedtime');
    expect(decoded.dailyLimitMinutes, 180);
    expect(decoded.isEnabled, isTrue);
    expect(decoded.apps.map((app) => app.appKey), ['social', 'video']);
    expect(decoded.apps.last.isIncludedInLimit, isFalse);
  });

  test('restriction payload preserves enabled routine groups', () {
    final payload = encodeRestrictionConfiguration(const [], const [
      BlockRoutine(
        id: 'focus',
        name: 'Focus',
        dailyLimitMinutes: 60,
        isEnabled: true,
        apps: [RoutineApp(appKey: 'social', appName: 'Social')],
      ),
      BlockRoutine(
        id: 'rest',
        name: 'Rest',
        isEnabled: false,
        apps: [RoutineApp(appKey: 'video', appName: 'Video')],
      ),
    ]);

    expect(payload, contains('"social"'));
    expect(payload, isNot(contains('"video"')));
    expect(payload, contains('"dailyLimitMinutes":60'));
    expect(payload, contains('"routines"'));
    expect(payload, isNot(contains('"routineBlocks"')));
  });

  test('legacy enabled routine migrates to no limit and disabled', () {
    final decoded = decodeBlockRoutines(
      '{"version":1,"routines":[{"id":"old","name":"Old",'
      '"isEnabled":true,"apps":[{"appKey":"social","appName":"Social"}]}]}',
    ).single;

    expect(decoded.dailyLimitMinutes, isNull);
    expect(decoded.isEnabled, isFalse);
    expect(decoded.apps.single.isIncludedInLimit, isTrue);
  });

  test('routine usage counts only included apps', () {
    const routine = BlockRoutine(
      id: 'focus',
      name: 'Focus',
      apps: [
        RoutineApp(appKey: 'social', appName: 'Social'),
        RoutineApp(appKey: 'music', appName: 'Music', isIncludedInLimit: false),
      ],
    );

    expect(routine.usageSeconds({'social': 120, 'music': 600}), 120);
  });

  test('invalid and empty routines are ignored while decoding', () {
    expect(decodeBlockRoutines('not json'), isEmpty);
    expect(
      decodeBlockRoutines(
        '{"routines":[{"id":"empty","name":"Empty","apps":[]}]}',
      ),
      isEmpty,
    );
  });
}
