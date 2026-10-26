import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/health_connect_channel.dart';
import '../../domain/models/health_connect.dart';

class HealthConnectViewState {
  const HealthConnectViewState({
    this.status = const HealthConnectStatus(),
    this.workouts = const <ImportedWorkout>[],
    this.isLoading = true,
    this.isBusy = false,
    this.hasError = false,
    this.attemptedEnable = false,
  });

  final HealthConnectStatus status;
  final List<ImportedWorkout> workouts;
  final bool isLoading;

  /// A request or import is running; controls are disabled meanwhile.
  final bool isBusy;

  /// The platform call itself failed (not an import outcome).
  final bool hasError;

  /// Turning on was tried at least once, so a still-off integration means
  /// the permission was declined.
  final bool attemptedEnable;
}

/// Shared by Settings and onboarding, so both use the same permission flow.
class HealthConnectViewModel extends StateNotifier<HealthConnectViewState> {
  HealthConnectViewModel(this._channel) : super(const HealthConnectViewState());

  final HealthConnectChannel _channel;

  Future<void> load() => _run(_channel.status);

  Future<void> enable() => _run(attemptedEnable: true, () async {
    final status = await _channel.enable();
    // The first import starts right away so the user sees it working.
    return status.enabled ? _channel.importNow() : status;
  });

  Future<void> disable() => _run(_channel.disable);

  Future<void> setAutoImport(bool enabled) =>
      _run(() => _channel.setAutoImport(enabled));

  Future<void> importNow() => _run(_channel.importNow);

  Future<void> deleteImported() => _run(_channel.clearImported);

  Future<void> openPermissionSettings() => _channel.openPermissionSettings();

  Future<void> _run(
    Future<HealthConnectStatus> Function() action, {
    bool attemptedEnable = false,
  }) async {
    if (state.isBusy) return;
    final attempted = state.attemptedEnable || attemptedEnable;
    state = HealthConnectViewState(
      status: state.status,
      workouts: state.workouts,
      isLoading: state.isLoading,
      isBusy: true,
      attemptedEnable: attempted,
    );
    try {
      final status = await action();
      final workouts = await _channel.workouts();
      if (!mounted) return;
      state = HealthConnectViewState(
        status: status,
        workouts: workouts,
        isLoading: false,
        attemptedEnable: attempted,
      );
    } catch (_) {
      if (!mounted) return;
      state = HealthConnectViewState(
        status: state.status,
        workouts: state.workouts,
        isLoading: false,
        hasError: true,
        attemptedEnable: attempted,
      );
    }
  }
}
