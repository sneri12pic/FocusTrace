import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  test('routine JSON preserves its name, state, and unique apps', () {
    const routine = BlockRoutine(
      id: 'bedtime',
      name: 'Bedtime',
      isEnabled: false,
      apps: [
        RoutineApp(appKey: 'social', appName: 'Social'),
        RoutineApp(appKey: 'video', appName: 'Video'),
      ],
    );

    final decoded = decodeBlockRoutines(encodeBlockRoutines([routine])).single;

    expect(decoded.id, 'bedtime');
    expect(decoded.name, 'Bedtime');
    expect(decoded.isEnabled, isFalse);
    expect(decoded.apps.map((app) => app.appKey), ['social', 'video']);
  });

  test('restriction payload includes only apps from enabled routines', () {
    final payload = encodeRestrictionConfiguration(const [], const [
      BlockRoutine(
        id: 'focus',
        name: 'Focus',
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
