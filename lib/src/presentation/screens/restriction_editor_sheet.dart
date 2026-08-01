import 'package:flutter/material.dart';
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
}) {
  return showModalBottomSheet<RestrictionRule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _sheetColor,
    builder: (context) => _RestrictionEditorSheet(
      appKey: appKey,
      appName: appName,
      existing: existing,
    ),
  );
}

/// Full "restrict an app" flow: editor sheet, save, then permission prompts.
Future<void> createRestrictionForApp(
  BuildContext context,
  WidgetRef ref, {
  required String appKey,
  required String appName,
}) async {
  final rule = await showRestrictionEditor(
    context,
    appKey: appKey,
    appName: appName,
  );
  if (rule == null || !context.mounted) {
    return;
  }
  await ref.read(restrictionsViewModelProvider.notifier).saveRule(rule);
  if (context.mounted) {
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

class _RestrictionEditorSheet extends StatefulWidget {
  const _RestrictionEditorSheet({
    required this.appKey,
    required this.appName,
    this.existing,
  });

  final String appKey;
  final String appName;
  final RestrictionRule? existing;

  @override
  State<_RestrictionEditorSheet> createState() =>
      _RestrictionEditorSheetState();
}

class _RestrictionEditorSheetState extends State<_RestrictionEditorSheet> {
  late RestrictionRuleType _type =
      widget.existing?.type ?? RestrictionRuleType.blockNow;
  late Duration _blockNowDuration =
      _durationFromExisting() ?? const Duration(hours: 1);
  late double _limitMinutes = (widget.existing?.limitMinutes ?? 60)
      .clamp(5, 480)
      .toDouble();
  late TimeOfDay _start = _timeOfDayFromMinute(
    widget.existing?.startMinute ?? 22 * 60,
  );
  late TimeOfDay _end = _timeOfDayFromMinute(
    widget.existing?.endMinute ?? 7 * 60,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          18,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.appKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<RestrictionRuleType>(
              segments: [
                ButtonSegment(
                  value: RestrictionRuleType.blockNow,
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: Text(context.l10n.restrictionEditorTypeNow),
                ),
                ButtonSegment(
                  value: RestrictionRuleType.dailyLimit,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(context.l10n.restrictionEditorTypeLimit),
                ),
                ButtonSegment(
                  value: RestrictionRuleType.schedule,
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text(context.l10n.restrictionEditorTypeSchedule),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.single);
              },
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: switch (_type) {
                RestrictionRuleType.blockNow => _BlockNowEditor(
                  duration: _blockNowDuration,
                  onChanged: (duration) {
                    setState(() => _blockNowDuration = duration);
                  },
                ),
                RestrictionRuleType.dailyLimit => _DailyLimitEditor(
                  value: _limitMinutes,
                  onChanged: (value) {
                    setState(() => _limitMinutes = value);
                  },
                ),
                RestrictionRuleType.schedule => _ScheduleEditor(
                  start: _start,
                  end: _end,
                  onPickStart: () => _pickTime(isStart: true),
                  onPickEnd: () => _pickTime(isStart: false),
                ),
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_buildRule()),
              icon: const Icon(Icons.save_outlined),
              label: Text(context.l10n.restrictionEditorSaveRule),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  RestrictionRule _buildRule() {
    switch (_type) {
      case RestrictionRuleType.blockNow:
        return RestrictionRule.blockNow(
          appKey: widget.appKey,
          appName: widget.appName,
          until: DateTime.now().add(_blockNowDuration),
        );
      case RestrictionRuleType.dailyLimit:
        return RestrictionRule.dailyLimit(
          appKey: widget.appKey,
          appName: widget.appName,
          limitMinutes: _limitMinutes.round(),
        );
      case RestrictionRuleType.schedule:
        return RestrictionRule.schedule(
          appKey: widget.appKey,
          appName: widget.appName,
          startMinute: _minuteFromTimeOfDay(_start),
          endMinute: _minuteFromTimeOfDay(_end),
        );
    }
  }

  Duration? _durationFromExisting() {
    final untilMs = widget.existing?.untilMs;
    if (untilMs == null) {
      return null;
    }
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      untilMs,
    ).difference(DateTime.now());
    if (remaining.isNegative) {
      return null;
    }
    return remaining;
  }
}

class _BlockNowEditor extends StatelessWidget {
  const _BlockNowEditor({required this.duration, required this.onChanged});

  final Duration duration;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final untilTomorrow = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
    ).difference(DateTime.now());
    final presets = <({String label, Duration duration})>[
      (
        label: context.l10n.compactDuration(const Duration(minutes: 30)),
        duration: const Duration(minutes: 30),
      ),
      (
        label: context.l10n.compactDuration(const Duration(hours: 1)),
        duration: const Duration(hours: 1),
      ),
      (
        label: context.l10n.compactDuration(const Duration(hours: 2)),
        duration: const Duration(hours: 2),
      ),
      (label: context.l10n.restrictionEditorTomorrow, duration: untilTomorrow),
    ];
    return Wrap(
      key: const ValueKey('blockNow'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in presets)
          ChoiceChip(
            label: Text(preset.label),
            selected: _sameMinute(duration, preset.duration),
            onSelected: (_) => onChanged(preset.duration),
          ),
      ],
    );
  }

  bool _sameMinute(Duration first, Duration second) {
    return first.inMinutes == second.inMinutes;
  }
}

class _DailyLimitEditor extends StatelessWidget {
  const _DailyLimitEditor({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final formattedDuration = context.l10n.compactDuration(
      Duration(minutes: value.round()),
    );
    return Column(
      key: const ValueKey('dailyLimit'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.restrictionEditorDailyLimitPerDay(formattedDuration)),
        Slider(
          value: value.clamp(5, 480),
          min: 5,
          max: 480,
          divisions: 95,
          label: formattedDuration,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor({
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('schedule'),
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickStart,
            icon: const Icon(Icons.play_arrow_outlined),
            label: Text(start.format(context)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickEnd,
            icon: const Icon(Icons.stop_outlined),
            label: Text(end.format(context)),
          ),
        ),
      ],
    );
  }
}

TimeOfDay _timeOfDayFromMinute(int minute) {
  return TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
}

int _minuteFromTimeOfDay(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}
