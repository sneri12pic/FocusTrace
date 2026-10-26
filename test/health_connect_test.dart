import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/l10n/generated/app_localizations.dart';
import 'package:focustrace/src/data/datasources/health_connect_channel.dart';
import 'package:focustrace/src/domain/models/health_connect.dart';
import 'package:focustrace/src/presentation/providers.dart';
import 'package:focustrace/src/presentation/screens/health_connect_screen.dart';
import 'package:focustrace/src/presentation/view_models/health_connect_view_model.dart';

/// Stands in for the native bridge; [grant] decides what a permission
/// request returns.
class FakeHealthConnectChannel implements HealthConnectChannel {
  FakeHealthConnectChannel({
    this.current = const HealthConnectStatus(
      availability: HealthConnectAvailability.available,
    ),
    this.grant = true,
    this.items = const [],
  });

  HealthConnectStatus current;
  bool grant;
  bool fail = false;
  List<ImportedWorkout> items;
  final calls = <String>[];

  Future<HealthConnectStatus> _answer(String call) async {
    calls.add(call);
    if (fail) throw StateError('channel');
    return current;
  }

  HealthConnectStatus _with({bool? enabled, int? workoutCount}) =>
      HealthConnectStatus(
        availability: current.availability,
        enabled: enabled ?? current.enabled,
        readGranted: (enabled ?? current.enabled) || current.readGranted,
        backgroundSupported: current.backgroundSupported,
        workoutCount: workoutCount ?? current.workoutCount,
      );

  @override
  Future<HealthConnectStatus> status() => _answer('status');

  @override
  Future<HealthConnectStatus> enable() {
    if (grant) current = _with(enabled: true);
    return _answer('enable');
  }

  @override
  Future<HealthConnectStatus> disable() {
    current = _with(enabled: false);
    return _answer('disable');
  }

  @override
  Future<HealthConnectStatus> setAutoImport(bool enabled) =>
      _answer('setAutoImport');

  @override
  Future<HealthConnectStatus> importNow() => _answer('importNow');

  @override
  Future<HealthConnectStatus> clearImported() {
    items = const [];
    current = _with(workoutCount: 0);
    return _answer('clearImported');
  }

  @override
  Future<List<ImportedWorkout>> workouts() async => items;

  @override
  Future<void> openPermissionSettings() async => calls.add('openSettings');
}

ImportedWorkout _workout({String? title}) => ImportedWorkout(
  id: 'hc-1',
  sourcePackage: 'com.hevy',
  sourceName: 'Hevy',
  exerciseType: 70,
  category: WorkoutCategory.strength,
  title: title,
  start: DateTime(2026, 10, 25, 18),
  end: DateTime(2026, 10, 25, 19, 5),
);

void main() {
  test('status parses the native map and derived warnings', () {
    final status = HealthConnectStatus.fromMap({
      'sdkStatus': 'available',
      'enabled': true,
      'autoImport': true,
      'readGranted': false,
      'backgroundGranted': false,
      'lastSuccessMillis': 0,
      'lastOutcome': 'permissionMissing',
      'workoutCount': 3,
    });
    expect(status.availability, HealthConnectAvailability.available);
    expect(status.lastSuccess, isNull);
    expect(status.lastOutcome, HealthConnectOutcome.permissionMissing);
    expect(status.lastOutcome!.isSuccess, isFalse);
    expect(status.accessRevoked, isTrue);
    expect(status.autoImportBlocked, isTrue);
    expect(
      HealthConnectStatus.fromMap({'sdkStatus': 'nonsense'}).availability,
      HealthConnectAvailability.unavailable,
    );
    expect(WorkoutCategory.parse('unknown'), WorkoutCategory.other);
  });

  group('view model', () {
    test('a declined permission stays off and is remembered', () async {
      final channel = FakeHealthConnectChannel(grant: false);
      final viewModel = HealthConnectViewModel(channel);
      await viewModel.enable();
      expect(viewModel.state.status.enabled, isFalse);
      expect(viewModel.state.attemptedEnable, isTrue);
      expect(channel.calls, ['enable']);
    });

    test('turning on imports right away', () async {
      final channel = FakeHealthConnectChannel(items: [_workout()]);
      final viewModel = HealthConnectViewModel(channel);
      await viewModel.enable();
      expect(viewModel.state.status.enabled, isTrue);
      expect(channel.calls, ['enable', 'importNow']);
      expect(viewModel.state.workouts, hasLength(1));
    });

    test('a failing channel is reported without losing state', () async {
      final channel = FakeHealthConnectChannel(items: [_workout()]);
      final viewModel = HealthConnectViewModel(channel);
      await viewModel.load();
      channel.fail = true;
      await viewModel.importNow();
      expect(viewModel.state.hasError, isTrue);
      expect(viewModel.state.workouts, hasLength(1));
      expect(viewModel.state.isBusy, isFalse);
    });
  });

  group('screen', () {
    Future<FakeHealthConnectChannel> pump(
      WidgetTester tester,
      FakeHealthConnectChannel channel,
    ) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            healthConnectSupportedProvider.overrideWithValue(true),
            healthConnectChannelProvider.overrideWithValue(channel),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HealthConnectScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return channel;
    }

    testWidgets('off by default, with what is read explained', (tester) async {
      await pump(tester, FakeHealthConnectChannel());
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('health-connect-enabled')),
      );
      expect(toggle.value, isFalse);
      expect(find.text('What FocusTrace reads'), findsOneWidget);
      expect(find.byKey(const ValueKey('health-connect-auto')), findsNothing);
    });

    testWidgets('unavailable devices get no controls', (tester) async {
      await pump(
        tester,
        FakeHealthConnectChannel(current: const HealthConnectStatus()),
      );
      expect(find.textContaining('needs Android 9'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('health-connect-enabled')),
        findsNothing,
      );
    });

    testWidgets('revoked access asks to grant it again', (tester) async {
      await pump(
        tester,
        FakeHealthConnectChannel(
          current: const HealthConnectStatus(
            availability: HealthConnectAvailability.available,
            enabled: true,
            lastOutcome: HealthConnectOutcome.permissionMissing,
          ),
        ),
      );
      expect(find.text('Grant access'), findsOneWidget);
      expect(
        find.text(
          'Last check failed: access to exercise data is off in Health Connect',
        ),
        findsOneWidget,
      );
      final importButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('health-connect-import')),
      );
      expect(importButton.onPressed, isNull);
    });

    testWidgets('imported workouts show their source and can be deleted', (
      tester,
    ) async {
      final channel = await pump(
        tester,
        FakeHealthConnectChannel(
          current: const HealthConnectStatus(
            availability: HealthConnectAvailability.available,
            enabled: true,
            readGranted: true,
            lastOutcome: HealthConnectOutcome.noNew,
            workoutCount: 2,
          ),
          items: [
            _workout(title: 'Push day'),
            _workout(),
          ],
        ),
      );
      expect(find.text('Last check: no new workouts'), findsOneWidget);
      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Strength training'), findsOneWidget);
      expect(find.textContaining('from Hevy'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('health-connect-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(channel.calls.last, 'clearImported');
      expect(find.text('Push day'), findsNothing);
    });
  });
}
