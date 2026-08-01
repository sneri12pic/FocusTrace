import 'package:flutter/material.dart';

import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';

class PermissionCard extends StatelessWidget {
  const PermissionCard({
    required this.platform,
    required this.hasUsageAccess,
    required this.onOpenSettings,
    required this.onRecheck,
    super.key,
  });

  final UsagePlatform platform;
  final bool hasUsageAccess;
  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (platform == UsagePlatform.windows) {
      return Card(
        elevation: 0,
        child: ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(context.l10n.permissionWindowsPrivacyTitle),
          subtitle: Text(context.l10n.trackingRunsWhileOpen),
          textColor: theme.colorScheme.onSurface,
        ),
      );
    }

    if (platform != UsagePlatform.android || hasUsageAccess) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.permissionUsageAccessRequiredTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.permissionUsageAccessRequiredBody),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(context.l10n.permissionOpenUsageAccessSettings),
                ),
                OutlinedButton.icon(
                  onPressed: onRecheck,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.commonRecheck),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
