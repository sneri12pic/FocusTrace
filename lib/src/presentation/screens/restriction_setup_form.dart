import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/restriction_rule.dart';
import '../localization/app_localizations_x.dart';
import '../widgets/app_category_widgets.dart';
import '../widgets/app_icon_avatar.dart';
import '../widgets/trend_color.dart';
import '../widgets/usage_calendar.dart';
import 'restriction_editor_sheet.dart';

class RestrictionSetupForm extends StatefulWidget {
  const RestrictionSetupForm({
    super.key,
    required this.appKey,
    required this.appName,
    this.existing,
    this.initial,
    this.iconBytes,
    this.averageSeconds,
    this.scrollController,
    this.scheduleUsage,
  });
  final String appKey, appName;
  final RestrictionRule? existing, initial;
  final Uint8List? iconBytes;
  final int? averageSeconds;

  /// The sheet's controller, so pulling down from the top drags it closed.
  final ScrollController? scrollController;

  /// This app's recent usage per quarter-hour, drawn under the schedule.
  final List<int>? scheduleUsage;
  @override
  State<RestrictionSetupForm> createState() => _RestrictionSetupFormState();
}

class _RestrictionSetupFormState extends State<RestrictionSetupForm> {
  RestrictionRule? get seed => widget.initial ?? widget.existing;
  late RestrictionRuleType type = seed?.type ?? RestrictionRuleType.dailyLimit;
  late RestrictionDifficulty difficulty =
      seed?.difficulty ?? RestrictionDifficulty.easy;
  late int minutes = seed?.limitMinutes ?? 90;
  late int blockMinutes = seed?.untilMs == null
      ? 60
      : ((seed!.untilMs! - DateTime.now().millisecondsSinceEpoch) / 60000)
            .ceil()
            .clamp(1, 1440);
  late int start = seed?.startMinute ?? 21 * 60;
  late int end = seed?.endMinute ?? 7 * 60;
  late Set<int> days = {
    ...(seed?.weekdays ?? [1, 2, 3, 4, 5, 6, 7]),
  };
  bool blockDurationChanged = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final muted = TextStyle(color: colors.onSurfaceVariant);
    final duration = type == RestrictionRuleType.dailyLimit
        ? minutes
        : blockMinutes;
    final presets = type == RestrictionRuleType.dailyLimit
        ? const [15, 30, 60, 120, 180]
        : const [15, 30, 60, 120, 240];
    final green = trendColor(theme, isFlat: false, isIncrease: false);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          AppIconAvatar(
            appName: widget.appName,
            iconBytes: widget.iconBytes,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: l.rxRestrict(widget.appName),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // The app's category, shown and changeable here too.
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: AppCategoryTag(
                    AppUsageSummary(
                      appName: widget.appName,
                      packageName: widget.appKey,
                      totalDurationSeconds: 0,
                      percentageOfTotal: 0,
                    ),
                  ),
                ),
                if (widget.averageSeconds != null)
                  Text(
                    l.rxAverageApp(
                      l.compactDuration(
                        Duration(seconds: widget.averageSeconds!),
                      ),
                    ),
                    style: muted,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
    // Sized by the draggable sheet around it.
    return SizedBox.expand(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // One header: the app, its average, and Close. Large text lets it
            // scroll away with the content instead of taking the whole sheet.
            if (!largeText) header,
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('restriction-editor-scroll-view'),
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (largeText) header,
                    _Choice<RestrictionRuleType>(
                      selected: type,
                      onSelected: (t) => setState(() => type = t),
                      options: [
                        (
                          RestrictionRuleType.dailyLimit,
                          Icons.hourglass_bottom_rounded,
                          l.rxDailyLimit,
                        ),
                        (
                          RestrictionRuleType.schedule,
                          Icons.calendar_month_outlined,
                          l.restrictionEditorTypeSchedule,
                        ),
                        (
                          RestrictionRuleType.blockNow,
                          Icons.block,
                          l.rxBlockNow,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (type != RestrictionRuleType.schedule) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip:
                                        '−${l.compactDuration(const Duration(minutes: 5))}',
                                    onPressed: duration <= 1
                                        ? null
                                        : () => setDuration(
                                            (duration - 5).clamp(1, 1440),
                                          ),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      key: const ValueKey(
                                        'restriction-duration',
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: editDuration,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: _DurationText(
                                          l.compactDuration(
                                            Duration(minutes: duration),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        '+${l.compactDuration(const Duration(minutes: 5))}',
                                    onPressed: duration >= 1440
                                        ? null
                                        : () => setDuration(
                                            (duration + 5).clamp(1, 1440),
                                          ),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: editDuration,
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text(l.rxEditDuration),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final preset in presets)
                            ChoiceChip(
                              label: Text(
                                l.compactDuration(Duration(minutes: preset)),
                              ),
                              selected: duration == preset,
                              showCheckmark: false,
                              onSelected: (_) => setDuration(preset),
                            ),
                        ],
                      ),
                      if (type == RestrictionRuleType.dailyLimit &&
                          widget.averageSeconds != null &&
                          widget.averageSeconds! > minutes * 60)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: green,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  l.rxBelowAverage(
                                    l.compactDuration(
                                      Duration(
                                        seconds:
                                            widget.averageSeconds! -
                                            minutes * 60,
                                      ),
                                    ),
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (type == RestrictionRuleType.blockNow)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            l.rxEndsAt(
                              TimeOfDay.fromDateTime(
                                DateTime.now().add(
                                  Duration(minutes: blockMinutes),
                                ),
                              ).format(context),
                            ),
                            textAlign: TextAlign.center,
                            style: muted,
                          ),
                        ),
                    ] else ...[
                      // The time frame is picked on the dial, over when this
                      // app is usually used; there is no manual time entry.
                      ScheduleRangeDial(
                        startMinute: start,
                        endMinute: end,
                        slotSeconds: widget.scheduleUsage,
                        slotCapacitySeconds: scheduleUsageDays * 15 * 60,
                        onChanged: (from, to) => setState(() {
                          start = from;
                          end = to;
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l.rxScheduleDialHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.merge(muted),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(l.rxRepeat, style: titleStyle),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var day = 1; day <= 7; day++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: _DayToggle(
                                  label: MaterialLocalizations.of(
                                    context,
                                  ).narrowWeekdays[day % 7],
                                  name: DateFormat.EEEE(
                                    Localizations.localeOf(context).toString(),
                                  ).dateSymbols.WEEKDAYS[day % 7],
                                  selected: days.contains(day),
                                  onTap: () => setState(() {
                                    days.contains(day)
                                        ? days.remove(day)
                                        : days.add(day);
                                  }),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (start == end || days.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l.rxScheduleInvalid,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1),
                    ),
                    Text(l.rxDifficulty, style: titleStyle),
                    const SizedBox(height: 10),
                    _Choice<RestrictionDifficulty>(
                      accents: {
                        for (final d in RestrictionDifficulty.values)
                          d: difficultyColor(theme, d.index),
                      },
                      selected: difficulty,
                      onSelected: (d) => setState(() => difficulty = d),
                      options: [
                        (RestrictionDifficulty.easy, null, l.rxEasy),
                        (RestrictionDifficulty.moderate, null, l.rxModerate),
                        (RestrictionDifficulty.hard, null, l.rxHard),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // One explanation, for the selected difficulty only.
                    Container(
                      key: const ValueKey('restriction-difficulty-explanation'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            switch (difficulty) {
                              RestrictionDifficulty.easy =>
                                Icons.lock_open_outlined,
                              RestrictionDifficulty.moderate =>
                                Icons.timer_outlined,
                              RestrictionDifficulty.hard => Icons.lock_outline,
                            },
                            size: 20,
                            color: difficultyColor(theme, difficulty.index),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    l.rxEasyHint,
                                    l.rxModerateHint,
                                    l.rxHardHint,
                                  ][difficulty.index],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    l.rxEasyExplain,
                                    l.rxModerateExplain,
                                    l.rxHardExplain,
                                  ][difficulty.index],
                                  style: theme.textTheme.bodySmall?.merge(
                                    muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      type == RestrictionRuleType.schedule &&
                          (start == end || days.isEmpty)
                      ? null
                      : submit,
                  child: Text(
                    widget.existing != null
                        ? l.rxSaveChanges
                        : switch (type) {
                            RestrictionRuleType.dailyLimit => l.rxSetLimit,
                            RestrictionRuleType.schedule => l.rxSetSchedule,
                            RestrictionRuleType.blockNow => l.rxStartBlock,
                          },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay time(int value) => TimeOfDay(hour: value ~/ 60, minute: value % 60);
  void setDuration(int value) => setState(() {
    if (type == RestrictionRuleType.dailyLimit) {
      minutes = value;
    } else {
      blockMinutes = value;
      blockDurationChanged = true;
    }
  });
  Future<void> editDuration() async {
    final current = type == RestrictionRuleType.dailyLimit
        ? minutes
        : blockMinutes;
    final hours = TextEditingController(text: '${current ~/ 60}');
    final mins = TextEditingController(text: '${current % 60}');
    String? error;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final l = context.l10n;
          void confirm() {
            final total =
                (int.tryParse(hours.text) ?? 0) * 60 +
                (int.tryParse(mins.text) ?? 0);
            if (total < 1 || total > 1440) {
              setDialogState(
                () => error =
                    '${l.compactDuration(const Duration(minutes: 1))}'
                    ' – ${l.compactDuration(const Duration(hours: 24))}',
              );
            } else {
              Navigator.pop(context, total);
            }
          }

          Widget field(TextEditingController c, String label, bool first) =>
              Expanded(
                child: TextField(
                  controller: c,
                  autofocus: first,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  // Two short numbers: no drag handles over the digits.
                  enableInteractiveSelection: false,
                  textInputAction: first
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: first ? null : (_) => confirm(),
                  onTap: () => c.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: c.text.length,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(first ? 2 : 4),
                  ],
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: InputDecoration(
                    labelText: label,
                    floatingLabelAlignment: FloatingLabelAlignment.center,
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
          return AlertDialog(
            title: Text(
              type == RestrictionRuleType.dailyLimit
                  ? l.rxDailyLimit
                  : l.rxBlockNow,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    field(hours, l.rxHoursField, true),
                    const SizedBox(width: 12),
                    field(mins, l.rxMinutesField, false),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonCancel),
              ),
              FilledButton(onPressed: confirm, child: Text(l.rxConfirm)),
            ],
          );
        },
      ),
    );
    // Not disposed: the dialog's exit animation still reads them.
    if (value != null && mounted) setDuration(value);
  }

  Future<void> submit() async {
    if (widget.existing != null && !await confirmRestrictionChange(context)) {
      return;
    }
    if (!mounted) return;
    if (difficulty == RestrictionDifficulty.hard) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.rxHard),
          content: Text(context.l10n.rxHardConfirm),
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
      );
      if (accepted != true || !mounted) return;
    }
    final until =
        !blockDurationChanged &&
            widget.existing?.type == RestrictionRuleType.blockNow
        ? widget.existing!.untilMs
        : DateTime.now()
              .add(Duration(minutes: blockMinutes))
              .millisecondsSinceEpoch;
    Navigator.pop(
      context,
      RestrictionRule(
        appKey: widget.appKey,
        appName: widget.appName,
        type: type,
        limitMinutes: type == RestrictionRuleType.dailyLimit ? minutes : null,
        untilMs: type == RestrictionRuleType.blockNow ? until : null,
        startMinute: type == RestrictionRuleType.schedule ? start : null,
        endMinute: type == RestrictionRuleType.schedule ? end : null,
        difficulty: difficulty,
        weekdays: days.toList()..sort(),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String label, name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: name,
      selected: selected,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: name,
        child: AspectRatio(
          aspectRatio: 1,
          child: Material(
            shape: CircleBorder(
              side: BorderSide(
                color: selected ? colors.primary : colors.outlineVariant,
              ),
            ),
            color: selected ? colors.primary : Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? colors.onPrimary : colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A duration with large numbers and small unit letters ("1 h 30 min"
/// style), whatever the locale's compact format is.
class _DurationText extends StatelessWidget {
  const _DurationText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final unit = theme.textTheme.titleLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final match in RegExp(r'\d+|\D+').allMatches(text))
            RegExp(r'^\d').hasMatch(match[0]!)
                ? TextSpan(text: match[0], style: number)
                // A thin space keeps the unit from touching its number.
                : TextSpan(text: ' ${match[0]!.trim()} ', style: unit),
        ],
      ),
      textAlign: TextAlign.center,
      semanticsLabel: text,
    );
  }
}

/// A compact one-of-N selector: equal segments in a row, or full-width rows
/// stacked when large text would otherwise clip the labels.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.accents,
  });

  final List<(T, IconData?, String)> options;

  /// A colour per option for its selected state; the theme accent otherwise.
  final Map<T, Color>? accents;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    // Narrow segments drop their icons so labels stay on one line.
    final showIcons =
        stacked ||
        (MediaQuery.sizeOf(context).width - 40 - 16) / options.length >= 112;
    Widget option((T, IconData?, String) o) {
      final (value, icon, label) = o;
      final isSelected = value == selected;
      final accent = accents?[value] ?? colors.primary;
      final color = isSelected ? accent : colors.onSurfaceVariant;
      return Semantics(
        selected: isSelected,
        button: true,
        child: Material(
          color: isSelected
              ? accent.withValues(alpha: .14)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? accent : colors.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: stacked
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    if (icon != null && showIcons) ...[
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? accent : colors.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: option(o),
            ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: option(options[i])),
          ],
        ],
      ),
    );
  }
}
