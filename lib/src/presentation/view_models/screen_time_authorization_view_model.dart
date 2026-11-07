import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/screen_time_channel.dart';

/// Whether FocusTrace may use Screen Time (iOS). One authorization covers
/// shields, schedules and, later, usage reports.
class ScreenTimeAuthorizationViewModel
    extends StateNotifier<ScreenTimeAuthorizationStatus> {
  ScreenTimeAuthorizationViewModel({
    required ScreenTimeChannel channel,
    required bool isRequired,
  }) : _channel = channel,
       _isRequired = isRequired,
       super(
         isRequired
             ? ScreenTimeAuthorizationStatus.notDetermined
             : ScreenTimeAuthorizationStatus.approved,
       );

  final ScreenTimeChannel _channel;
  final bool _isRequired;

  bool get isApproved => state == ScreenTimeAuthorizationStatus.approved;

  Future<void> refresh() async {
    if (!_isRequired) return;
    try {
      final status = await _channel.authorizationStatus();
      if (mounted) state = status;
    } catch (error) {
      debugPrint('Screen Time status unavailable: $error');
    }
  }

  /// Asks iOS (once; afterwards iOS answers without a prompt) and returns
  /// whether FocusTrace may now block apps.
  Future<bool> request() async {
    if (!_isRequired) return true;
    try {
      final status = await _channel.requestAuthorization();
      if (mounted) state = status;
      return status == ScreenTimeAuthorizationStatus.approved;
    } catch (error) {
      debugPrint('Screen Time authorization failed: $error');
      return false;
    }
  }
}
