import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'src/presentation/focus_trace_app.dart';
import 'src/application/services/background_sync.dart';

@pragma('vm:entry-point')
Future<void> backgroundSync() => backgroundSyncEntrypoint();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ProviderScope(child: FocusTraceApp()));
}
