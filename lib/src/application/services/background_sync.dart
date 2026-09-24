import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data/datasources/focus_trace_local_data_source.dart';
import '../../domain/models/sync_usage.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../presentation/providers.dart';

/// Wire values contain no domain errors, exception details or credentials.
Future<String> runBackgroundSync(SyncRepository? repository) async {
  if (repository == null) return 'success';
  final result = await repository.syncNow(requireEnabled: true);
  if (result.succeeded) return 'success';
  return switch (result.reason) {
    SyncFailureReason.offline || SyncFailureReason.temporary => 'retry',
    SyncFailureReason.notSignedIn || SyncFailureReason.sessionExpired ||
    SyncFailureReason.refused => 'success',
    _ => 'failure',
  };
}

Future<void> backgroundSyncEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(overrides: [
    localDataSourceProvider.overrideWithValue(
      SqfliteFocusTraceLocalDataSource(singleInstance: false),
    ),
  ]);
  var outcome = 'failure';
  try {
    final repository = container.read(syncRepositoryProvider);
    // Exercise the required database plugin without opening a connection or
    // reading credentials. A stalled plugin remains inside native startup time.
    await getDatabasesPath();
    // READY is not permission to sync. Native may cancel between receiving it
    // and replying. No gate acquisition/session access exists before true.
    final authorized = await const MethodChannel('focustrace/background_sync')
        .invokeMethod<bool>('ready');
    if (authorized == true) outcome = await runBackgroundSync(repository);
  } on Object {
    // Background failures never emit exception strings or retry unknown bugs.
  } finally {
    try {
      final local = container.read(localDataSourceProvider);
      if (local is SqfliteFocusTraceLocalDataSource) await local.close();
    } on Object {
      outcome = 'failure';
    }
    container.dispose();
  }
  // syncNow has returned through the native gate's release before this signal.
  await const MethodChannel('focustrace/background_sync')
      .invokeMethod<void>('complete', outcome);
}
