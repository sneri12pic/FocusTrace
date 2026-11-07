import 'package:flutter/services.dart';

/// App keys of rules whose apps were chosen in Apple's picker. The rest of the
/// key is the id of the stored, opaque `FamilyActivitySelection`.
const iosSelectionKeyPrefix = 'ios-sel:';

bool isIosSelectionKey(String appKey) =>
    appKey.startsWith(iosSelectionKeyPrefix);

/// The selection id inside an `ios-sel:<id>` app key, or null.
String? iosSelectionId(String appKey) => isIosSelectionKey(appKey)
    ? appKey.substring(iosSelectionKeyPrefix.length)
    : null;

enum ScreenTimeAuthorizationStatus { notDetermined, denied, approved }

/// What Flutter may know about a picker selection: its id and how much it
/// holds. Names and icons stay inside iOS (see the selection icons view).
class ScreenTimeSelection {
  const ScreenTimeSelection({
    required this.selectionId,
    this.appCount = 0,
    this.categoryCount = 0,
    this.webDomainCount = 0,
  });

  final String selectionId;
  final int appCount;
  final int categoryCount;
  final int webDomainCount;

  String get appKey => '$iosSelectionKeyPrefix$selectionId';

  static ScreenTimeSelection? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = value['selectionId'];
    if (id is! String || id.isEmpty) return null;
    int count(String key) => (value[key] as num?)?.toInt() ?? 0;
    return ScreenTimeSelection(
      selectionId: id,
      appCount: count('appCount'),
      categoryCount: count('categoryCount'),
      webDomainCount: count('webDomainCount'),
    );
  }
}

/// Dart side of the iOS `focustrace/screen_time` channel (Runner's
/// FocusTraceChannels.swift).
class ScreenTimeChannel {
  const ScreenTimeChannel({
    MethodChannel channel = const MethodChannel('focustrace/screen_time'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<ScreenTimeAuthorizationStatus> authorizationStatus() async =>
      _status(await _channel.invokeMethod<String>('authorizationStatus'));

  /// Shows Apple's Screen Time prompt (individual authorization) when it has
  /// not been answered yet, and returns the resulting status.
  Future<ScreenTimeAuthorizationStatus> requestAuthorization() async =>
      _status(await _channel.invokeMethod<String>('requestAuthorization'));

  /// Presents Apple's app picker. Returns null when cancelled. With
  /// [selectionId], edits that stored selection instead of creating one.
  Future<ScreenTimeSelection?> pickSelection({
    String? selectionId,
    required String doneLabel,
    required String cancelLabel,
  }) async => ScreenTimeSelection.fromMap(
    await _channel.invokeMethod<Object?>('pickSelection', {
      if (selectionId != null) 'selectionId': selectionId,
      'doneLabel': doneLabel,
      'cancelLabel': cancelLabel,
    }),
  );

  Future<ScreenTimeSelection?> selectionSummary(String selectionId) async =>
      ScreenTimeSelection.fromMap(
        await _channel.invokeMethod<Object?>('selectionSummary', {
          'selectionId': selectionId,
        }),
      );

  /// The block screen's texts, from the app's ARB files.
  Future<void> setShieldStrings(Map<String, String> strings) =>
      _channel.invokeMethod<void>('setShieldStrings', {'strings': strings});

  static ScreenTimeAuthorizationStatus _status(String? value) =>
      ScreenTimeAuthorizationStatus.values.asNameMap()[value] ??
      ScreenTimeAuthorizationStatus.notDetermined;
}
