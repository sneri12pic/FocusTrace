import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'restriction_setup_form.dart';
import '../view_models/restriction_insights.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';

const _sheetColor = Color(0xFF0D111A);

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
    builder: (context) => Consumer(
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
        return RestrictionSetupForm(
          appKey: appKey,
          appName: appName,
          existing: existing,
          initial: initial,
          iconBytes: iconBytes ?? app?.iconBytes ?? installed?.iconBytes,
          averageSeconds: averageSeconds ?? app?.totalDurationSeconds,
        );
      },
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
