import 'package:flutter/cupertino.dart'
    show CupertinoTimerPicker, CupertinoTimerPickerMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/preferred_limit.dart';
import '../../domain/models/usage_item.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../screens/restriction_editor_sheet.dart';
import 'app_category_widgets.dart';
import 'app_icon_avatar.dart';
import 'routine_app_picker.dart';

/// Lists preferred usage times and adds, edits or removes them. Shared by
/// onboarding and Settings, and saved as soon as the user confirms.
class PreferredLimitsEditor extends ConsumerWidget {
  const PreferredLimitsEditor({super.key});

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final taken = ref
        .read(restrictionsViewModelProvider)
        .preferredLimits
        .map((limit) => limit.category)
        .toSet();
    final category = await showDialog<UsageCategory>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.preferredUsageAddCategory),
        children: [
          for (final category in UsageCategory.values)
            if (!taken.contains(category))
              SimpleDialogOption(
                key: ValueKey('preferred-category-${category.name}'),
                onPressed: () => Navigator.of(context).pop(category),
                child: Row(
                  children: [
                    CategoryIcon(category, size: 24),
                    const SizedBox(width: 14),
                    Text(context.l10n.usageCategoryLabel(category)),
                  ],
                ),
              ),
        ],
      ),
    );
    if (category != null && context.mounted) {
      await _edit(
        context,
        ref,
        PreferredLimit(category: category, minutes: 60),
      );
    }
  }

  Future<void> _addApp(BuildContext context, WidgetRef ref) async {
    final apps =
        ref.read(installedAppsProvider).valueOrNull ??
        const <AppUsageSummary>[];
    final app = await showModalBottomSheet<AppUsageSummary>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: RoutineAppPicker(
          apps: apps,
          selected: const {},
          onChanged: (keys) => Navigator.of(
            context,
          ).pop(apps.firstWhere((app) => app.appKey == keys.first)),
        ),
      ),
    );
    if (app != null && context.mounted) {
      await _edit(
        context,
        ref,
        PreferredLimit(appKey: app.appKey, appName: app.appName, minutes: 60),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    PreferredLimit limit,
  ) async {
    final minutes = await showPreferredMinutesSheet(
      context,
      title: _name(context, limit),
      minutes: limit.minutes,
    );
    if (minutes == null || !context.mounted) return;
    await ref
        .read(restrictionsViewModelProvider.notifier)
        .savePreferredLimit(limit.withMinutes(minutes));
    if (context.mounted &&
        ref.read(restrictionsViewModelProvider).errorMessage == null) {
      await promptRestrictionPermissionsIfNeeded(context, ref);
    }
  }

  String _name(BuildContext context, PreferredLimit limit) =>
      limit.appName ??
      (limit.category == null
          ? limit.appKey ?? ''
          : context.l10n.usageCategoryLabel(limit.category!));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(restrictionsViewModelProvider);
    final installed =
        ref.watch(installedAppsProvider).valueOrNull ??
        const <AppUsageSummary>[];
    final isBusy = state.isSaving || state.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final limit in state.preferredLimits)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: limit.category != null
                  ? CategoryIcon(limit.category!, size: 28)
                  : AppIconAvatar(
                      appName: _name(context, limit),
                      iconBytes: installed
                          .where((app) => app.appKey == limit.appKey)
                          .firstOrNull
                          ?.iconBytes,
                    ),
              title: Text(
                _name(context, limit),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l.preferredUsagePerDay(
                  l.compactDuration(Duration(minutes: limit.minutes)),
                ),
              ),
              onTap: isBusy ? null : () => _edit(context, ref, limit),
              trailing: IconButton(
                tooltip: l.preferredUsageRemove,
                icon: const Icon(Icons.close),
                onPressed: isBusy
                    ? null
                    : () => ref
                          .read(restrictionsViewModelProvider.notifier)
                          .removePreferredLimit(limit),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('preferred-add-category'),
                onPressed: isBusy ? null : () => _addCategory(context, ref),
                icon: const Icon(Icons.category_outlined),
                label: Text(l.preferredUsageAddCategory),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('preferred-add-app'),
                onPressed: isBusy ? null : () => _addApp(context, ref),
                icon: const Icon(Icons.apps),
                label: Text(l.preferredUsageAddApp),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Picks a daily time to the minute; resolves to null when dismissed.
Future<int?> showPreferredMinutesSheet(
  BuildContext context, {
  required String title,
  required int minutes,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _MinutesSheet(title: title, minutes: minutes),
);

class _MinutesSheet extends StatefulWidget {
  const _MinutesSheet({required this.title, required this.minutes});

  final String title;
  final int minutes;

  @override
  State<_MinutesSheet> createState() => _MinutesSheetState();
}

class _MinutesSheetState extends State<_MinutesSheet> {
  static const _presets = [15, 30, 60, 120];

  // The wheels show at most 23h 59m.
  late int _minutes = widget.minutes.clamp(1, 24 * 60 - 1);

  // The wheels only read their start value, so a preset rebuilds them.
  var _presetsTapped = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.preferredUsagePerDay(
              l.compactDuration(Duration(minutes: _minutes)),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  key: ValueKey('preferred-preset-$preset'),
                  label: Text(l.compactDuration(Duration(minutes: preset))),
                  selected: _minutes == preset,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _minutes = preset;
                    _presetsTapped++;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: CupertinoTimerPicker(
              key: ValueKey(_presetsTapped),
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: Duration(minutes: _minutes),
              onTimerDurationChanged: (value) =>
                  setState(() => _minutes = value.inMinutes),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('preferred-save'),
            onPressed: _minutes > 0
                ? () => Navigator.of(context).pop(_minutes)
                : null,
            child: Text(l.settingsSave),
          ),
        ],
      ),
    );
  }
}
