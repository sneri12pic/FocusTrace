import 'dart:async';

import 'package:flutter/foundation.dart';

/// Debug-only timing markers for the physical-device dashboard benchmark.
///
/// The comma-separated log format is intentionally stable so baseline and
/// post-change captures use the same measurement definitions.
class DashboardPerformance {
  DashboardPerformance._();

  static const logTag = 'FocusTraceDashboardPerf';
  static final Object _liveFetchRunKey = Object();
  static final Object _iconFetchRunKey = Object();
  static _DashboardRun? _activeRun;

  static int? get currentPlatformFetchRunId {
    if (!kDebugMode) {
      return null;
    }
    final run =
        Zone.current[_iconFetchRunKey] as _DashboardRun? ??
        Zone.current[_liveFetchRunKey] as _DashboardRun?;
    return run?.id;
  }

  static void dashboardOpened() {
    if (!kDebugMode) {
      return;
    }
    final run = _DashboardRun(
      id: DateTime.now().microsecondsSinceEpoch,
      stopwatch: Stopwatch()..start(),
    );
    _activeRun = run;
    _mark('dashboard_open', run: run);
  }

  static void viewModelInitialized() => _mark('view_model_init');

  static Future<T> traceLiveUsageFetch<T>(Future<T> Function() fetch) {
    if (!kDebugMode) {
      return fetch();
    }
    final run = _activeRun;
    return runZoned(
      fetch,
      zoneValues: <Object, Object?>{_liveFetchRunKey: run},
    );
  }

  static Future<T> traceIconHydrationFetch<T>(Future<T> Function() fetch) {
    if (!kDebugMode) {
      return fetch();
    }
    final run = _activeRun;
    return runZoned(
      fetch,
      zoneValues: <Object, Object?>{_iconFetchRunKey: run},
    );
  }

  static void liveUsageAvailable() {
    final run = Zone.current[_liveFetchRunKey] as _DashboardRun?;
    _mark('live_usage_available', run: run);
  }

  static void livePlatformCallStarted() {
    final run = Zone.current[_liveFetchRunKey] as _DashboardRun?;
    _mark('live_platform_call_start', run: run);
  }

  static void firstNonEmptyState() => _mark('first_non_empty_state');

  static void cachedStatePublished({
    required Iterable<String> topKeys,
    required Iterable<String> realIconKeys,
  }) {
    if (!kDebugMode) {
      return;
    }
    final run = _activeRun;
    if (run == null) {
      return;
    }
    run.cachedTopKeys = topKeys.take(10).toSet();
    final realKeys = realIconKeys.toSet();
    _mark(
      'cached_state_published',
      run: run,
      details: <String, Object?>{
        'top_count': run.cachedTopKeys.length,
        'real_icon_count': run.cachedTopKeys.intersection(realKeys).length,
      },
    );
  }

  static void iconHydrationStarted({
    required String source,
    required int requestedCount,
  }) => _mark(
    'icon_hydration_start',
    details: <String, Object?>{
      'source': source,
      'requested_count': requestedCount,
    },
  );

  static void iconHydrationCompleted({
    required String source,
    required Iterable<String> availableIconKeys,
  }) {
    if (!kDebugMode) {
      return;
    }
    final run = _activeRun;
    if (run == null) {
      return;
    }
    final availableKeys = availableIconKeys.toSet();
    run.availableTopIconKeys = run.cachedTopKeys.intersection(availableKeys);
    _mark(
      'icon_hydration_complete',
      run: run,
      details: <String, Object?>{
        'source': source,
        'available_top_count': run.availableTopIconKeys!.length,
      },
    );
  }

  static void bubbleFrame({
    required Iterable<String> topKeys,
    required Iterable<String> realIconKeys,
  }) {
    if (!kDebugMode) {
      return;
    }
    final run = _activeRun;
    if (run == null) {
      return;
    }
    final visibleKeys = topKeys.take(10).toSet();
    final realKeys = realIconKeys.toSet();
    if (!run.events.contains('first_bubble_frame')) {
      _mark('first_bubble_frame', run: run);
      _mark(
        'initial_graph_icon_state',
        run: run,
        details: <String, Object?>{
          'top_count': visibleKeys.length,
          'real_icon_count': visibleKeys.intersection(realKeys).length,
        },
      );
    }
    final availableKeys = run.availableTopIconKeys;
    if (availableKeys != null && realKeys.containsAll(availableKeys)) {
      _mark(
        'first_all_available_icons_frame',
        run: run,
        details: <String, Object?>{
          'available_top_count': availableKeys.length,
          'real_icon_count': visibleKeys.intersection(realKeys).length,
        },
      );
    }
  }

  static void entranceAnimationComplete() =>
      _mark('entrance_animation_complete');

  static void _mark(
    String event, {
    _DashboardRun? run,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!kDebugMode) {
      return;
    }
    final target = run ?? _activeRun;
    if (target == null || !target.events.add(event)) {
      return;
    }
    final suffix = details.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(',');
    debugPrint(
      '$logTag,$event,${target.id},${target.stopwatch.elapsedMicroseconds}'
      '${suffix.isEmpty ? '' : ',$suffix'}',
    );
  }
}

class _DashboardRun {
  _DashboardRun({required this.id, required this.stopwatch});

  final int id;
  final Stopwatch stopwatch;
  final Set<String> events = <String>{};
  Set<String> cachedTopKeys = <String>{};
  Set<String>? availableTopIconKeys;
}
