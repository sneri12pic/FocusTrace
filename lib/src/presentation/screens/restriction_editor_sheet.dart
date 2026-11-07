import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'restriction_setup_form.dart';
import '../view_models/restriction_insights.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/screen_time_channel.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/platform_capabilities.dart';
import '../../domain/models/restriction_rule.dart';
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
            allowDailyLimit: ref
                .watch(platformCapabilitiesProvider)
                .dailyLimits,
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

/// iOS: choose apps in Apple's picker, name the group, then the usual editor.
/// The rule's app key is `ios-sel:<id>` of the stored selection.
Future<void> createIosRestriction(BuildContext context, WidgetRef ref) async {
  final picked = await pickIosAppGroup(context, ref);
  if (picked == null || !context.mounted) return;
  await createRestrictionForApp(
    context,
    ref,
    appKey: picked.appKey,
    appName: picked.appName,
  );
}

/// iOS: authorizes Screen Time if needed, shows Apple's picker and asks for a
/// name. Returns the named group (`ios-sel:<id>` key, no usage), or null.
/// Routines use it to add apps no rule has picked yet.
Future<AppUsageSummary?> pickIosAppGroup(
  BuildContext context,
  WidgetRef ref,
) async {
  final l = context.l10n;
  final authorization = ref.read(screenTimeAuthorizationProvider.notifier);
  if (!authorization.isApproved && !await authorization.request()) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.rxScreenTimeNeededBody)));
    }
    return null;
  }
  if (!context.mounted) return null;
  await syncShieldStrings(context, ref);
  if (!context.mounted) return null;
  final ScreenTimeSelection? selection;
  try {
    selection = await ref
        .read(screenTimeChannelProvider)
        .pickSelection(doneLabel: l.rxPickerDone, cancelLabel: l.commonCancel);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.rxUnavailable)));
    }
    return null;
  }
  if (selection == null || !context.mounted) return null;
  final name = await showSelectionNameDialog(context, selection);
  if (name == null) return null;
  return AppUsageSummary(
    appName: name,
    packageName: selection.appKey,
    totalDurationSeconds: 0,
    percentageOfTotal: 0,
  );
}

/// Asks for the name the rule is shown under: iOS never tells FocusTrace
/// which apps were picked.
Future<String?> showSelectionNameDialog(
  BuildContext context,
  ScreenTimeSelection selection,
) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l = context.l10n;
      return StatefulBuilder(
        builder: (context, setState) {
          final name = controller.text.trim();
          void submit() {
            if (name.isNotEmpty) Navigator.pop(context, name);
          }

          return AlertDialog(
            title: Text(l.rxNameAppsTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.rxSelectionCount(
                    selection.appCount +
                        selection.categoryCount +
                        selection.webDomainCount,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('selection-name-field'),
                  controller: controller,
                  autofocus: true,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: l.rxNameAppsHint),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                key: const ValueKey('selection-name-confirm'),
                onPressed: name.isEmpty ? null : submit,
                child: Text(l.rxConfirm),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Texts of the iOS usage reports (ReportStrings in
/// ios/FocusTraceKit/UsageReportModels.swift), keyed `report.<name>`.
/// Durations are sent as templates with `{h}` / `{m}` so Swift formats them
/// as `compactDuration` does.
Map<String, String> reportStrings(BuildContext context) {
  final l = context.l10n;
  // Sentinels no translation contains, replaced by the Swift placeholders.
  const hours = 9876;
  const minutes = 5432;
  String template(String text) =>
      text.replaceAll('$hours', '{h}').replaceAll('$minutes', '{m}');
  return {
    'report.locale': Localizations.localeOf(context).toLanguageTag(),
    'report.totalTime': l.usageCalendarTotalTime,
    'report.currentList': l.usageBubblesCurrentList,
    'report.all': l.appCategoryAll,
    'report.timeline': l.usageCalendarTimeline,
    'report.totalUsage': l.reportsTotalUsage,
    'report.dailyAverage': l.reportsDailyAverage,
    'report.activeDays': l.reportsActiveDays,
    'report.topApps': l.reportsTopApps,
    'report.peakTime': l.reportsPeakTime,
    'report.pickups': l.iosReportPickups,
    'report.notifications': l.iosReportNotifications,
    'report.tapHour': l.iosReportTapHour,
    'report.moreApps': l.iosReportMoreApps('{count}'),
    'report.noData': l.iosReportNoData,
    'report.groupApps': l.iosReportGroupApps,
    'report.durationLessThanMinute': l.durationLessThanOneMinute,
    'report.durationM': template(l.durationMinutesShort(minutes)),
    'report.durationH': template(l.durationHoursShort(hours)),
    'report.durationHM': template(l.durationHoursMinutesShort(hours, minutes)),
  };
}

/// Pushes the block screen's and usage reports' texts to iOS in the app's
/// language.
Future<void> syncShieldStrings(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  const time = '{time}';
  const name = '{name}';
  try {
    await ref.read(screenTimeChannelProvider).setShieldStrings({
      'blockNowUntil': l.shieldBlockNowUntil(time),
      'scheduleUntil': l.shieldScheduleUntil(time),
      'dailyLimit': l.shieldDailyLimit,
      'restricted': l.shieldRestricted,
      'leave': l.shieldLeave,
      'unblockInApp': l.shieldUnblockInApp,
      'notificationBody': l.shieldNotificationBody(name),
      'routineShared': l.routineReasonShared(name),
      'routineApp': l.routineReasonApp(name),
      'limitWarningTitle': l.shieldLimitWarningTitle(name),
      'routineWarningTitle': l.shieldRoutineWarningTitle(name),
      'nudgeTitle': l.shieldNudgeTitle,
      'nudgeReached': l.shieldNudgeReached,
      // Texts with a number, pluralized here for every count the monitor
      // can need (UsageEvents.swift): warnings and nudges come at most five
      // minutes ahead, over-limit nudges every 10 minutes for 2 hours.
      for (var minutes = 1; minutes <= 5; minutes++) ...{
        'limitWarningBody.$minutes': l.shieldLimitWarningBody(minutes),
        'nudgeLeft.$minutes': l.shieldNudgeMinutesLeft(minutes),
      },
      for (var minutes = 10; minutes <= 120; minutes += 10)
        'nudgeOver.$minutes': l.shieldNudgeMinutesOver(minutes),
      // The usage report extension reads its texts from the same map.
      ...reportStrings(context),
    });
  } catch (error) {
    // The shield falls back to English.
    debugPrint('Shield strings not sent: $error');
  }
}

Future<void> promptRestrictionPermissionsIfNeeded(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(restrictionsViewModelProvider);
  final capabilities = PlatformCapabilities.forPlatform(state.platform);
  final viewModel = ref.read(restrictionsViewModelProvider.notifier);
  if (capabilities.overlayPermission &&
      !state.hasOverlayPermission &&
      context.mounted) {
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
  if (capabilities.notificationsPermission) {
    await viewModel.requestNotificationsPermission();
  }
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
