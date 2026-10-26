import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'restriction_setup_form.dart';
import '../view_models/restriction_insights.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../widgets/usage_calendar.dart';

const _sheetColor = Color(0xFF0D111A);

/// Days of history behind the schedule dial.
const scheduleUsageDays = 7;

/// This app's usage per quarter-hour over the last [scheduleUsageDays] days,
/// summed, so the schedule dial shows when it is usually used.
final appScheduleUsageProvider = FutureProvider.autoDispose
    .family<List<int>, String>((ref, appKey) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = DateTime(
        today.year,
        today.month,
        today.day - scheduleUsageDays + 1,
      );
      final source = await ref
          .watch(reportRepositoryProvider)
          .loadSourceData(from, now);
      final intervals = [
        for (final interval in source.intervals)
          if (interval.appKey == appKey) interval,
      ];
      final total = List.filled(24 * 4, 0);
      for (var d = 0; d < scheduleUsageDays; d++) {
        final day = DateTime(from.year, from.month, from.day + d);
        final slots = usageBySlot(day, intervals);
        for (var i = 0; i < total.length; i++) {
          total[i] += slots[i];
        }
      }
      return total;
    });

Future<RestrictionRule?> showRestrictionEditor(
  BuildContext context, {
  required String appKey,
  required String appName,
  RestrictionRule? existing,
  RestrictionRule? initial,
  Uint8List? iconBytes,
  int? averageSeconds,
}) {
  return showModalBottomSheet<RestrictionRule>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _sheetColor,
    // Slides up over part of the screen; drag the handle, the header, or the
    // content from its top down to close it.
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, scrollController) => Consumer(
        builder: (context, ref, _) {
          final weekly = ref
              .watch(restrictionPeriodInsightsProvider(true))
              .asData
              ?.value;
          final app = weekly?.apps.where((a) => a.appKey == appKey).firstOrNull;
          final installed = ref
              .watch(installedAppsProvider)
              .valueOrNull
              ?.where((a) => a.appKey == appKey)
              .firstOrNull;
          final scheduleUsage = ref
              .watch(appScheduleUsageProvider(appKey))
              .asData
              ?.value;
          return RestrictionSetupForm(
            appKey: appKey,
            appName: appName,
            existing: existing,
            initial: initial,
            iconBytes: iconBytes ?? app?.iconBytes ?? installed?.iconBytes,
            averageSeconds: averageSeconds ?? app?.totalDurationSeconds,
            scrollController: scrollController,
            scheduleUsage: scheduleUsage,
          );
        },
      ),
    ),
  );
}

/// Full "restrict an app" flow: editor sheet, save, then permission prompts.
Future<void> createRestrictionForApp(
  BuildContext context,
  WidgetRef ref, {
  required String appKey,
  required String appName,
  RestrictionRule? initial,
}) async {
  final existing = ref
      .read(restrictionsViewModelProvider)
      .rules
      .where(
        (r) =>
            r.appKey == appKey && (initial == null || r.type == initial.type),
      )
      .firstOrNull;
  final prefill = initial == null
      ? null
      : existing?.copyWith(
              startMinute: initial.startMinute,
              endMinute: initial.endMinute,
            ) ??
            initial;
  final rule = await showRestrictionEditor(
    context,
    appKey: appKey,
    appName: appName,
    existing: existing,
    initial: prefill,
  );
  if (rule == null || !context.mounted) {
    return;
  }
  await ref
      .read(restrictionsViewModelProvider.notifier)
      .saveRule(rule, replacing: existing);
  if (context.mounted) await showRestrictionResult(context, ref);
  if (context.mounted &&
      ref.read(restrictionsViewModelProvider).errorMessage == null) {
    await promptRestrictionPermissionsIfNeeded(context, ref);
  }
}

Future<void> promptRestrictionPermissionsIfNeeded(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(restrictionsViewModelProvider);
  if (state.platform != UsagePlatform.android) {
    return;
  }

  final viewModel = ref.read(restrictionsViewModelProvider.notifier);
  if (!state.hasOverlayPermission && context.mounted) {
    final openSettings =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.restrictionEditorAllowFullScreenTitle),
            content: Text(context.l10n.restrictionEditorAllowFullScreenBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.restrictionEditorLater),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.restrictionEditorOpenSettings),
              ),
            ],
          ),
        ) ??
        false;
    if (openSettings) {
      await viewModel.openOverlaySettings();
    }
  }
  await viewModel.requestNotificationsPermission();
}

Future<void> showRestrictionResult(BuildContext context, WidgetRef ref) async {
  final error = ref.read(restrictionsViewModelProvider).errorMessage;
  if (error == null || !context.mounted) return;
  final message = restrictionErrorText(context, error);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmRestrictionChange(
  BuildContext context, {
  String? body,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.rxChangeTitle),
        content: Text(body ?? context.l10n.rxChangeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.rxConfirm),
          ),
        ],
      ),
    ) ??
    false;

String restrictionErrorText(BuildContext context, String error) {
  final l = context.l10n;
  return error.contains('restriction:hard')
      ? l.rxHardLocked
      : error.contains('restriction:cooldown')
      ? l.rxCooldown
      : l.rxUnavailable;
}
