import 'package:flutter/material.dart';

import '../../domain/models/tracking_status.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';

class TrackingStatusBanner extends StatelessWidget {
  const TrackingStatusBanner({required this.status, super.key});

  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = status.errorMessage != null;
    final color = isError
        ? theme.colorScheme.errorContainer
        : status.isTracking
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isError
        ? theme.colorScheme.onErrorContainer
        : status.isTracking
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : status.isTracking
                ? Icons.play_circle
                : Icons.info_outline,
            color: textColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isError ? context.l10n.trackingError : _labelFor(context, status),
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, TrackingStatus status) {
    if (status.platform == UsagePlatform.windows) {
      return status.isTracking
          ? context.l10n.trackingWindowsRunning
          : context.l10n.trackingWindowsIdle;
    }
    if (status.platform == UsagePlatform.android) {
      return context.l10n.trackingAndroidUsageAccess;
    }
    return context.l10n.trackingUnsupportedPlatform;
  }
}
