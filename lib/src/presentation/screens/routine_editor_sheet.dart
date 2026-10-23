import 'package:flutter/material.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/block_routine.dart';
import '../../domain/models/usage_item.dart';
import '../localization/app_localizations_x.dart';
import '../widgets/app_category_widgets.dart';
import '../widgets/routine_app_picker.dart';

Future<BlockRoutine?> showRoutineEditor(
  BuildContext context, {
  required List<AppUsageSummary> apps,
  BlockRoutine? existing,
}) {
  return showModalBottomSheet<BlockRoutine>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0D111A),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _RoutineEditor(apps: apps, existing: existing),
    ),
  );
}

class _RoutineEditor extends StatefulWidget {
  const _RoutineEditor({required this.apps, this.existing});

  final List<AppUsageSummary> apps;
  final BlockRoutine? existing;

  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  late final TextEditingController _nameController;
  late final Map<String, RoutineApp> _selectedApps;
  late final List<AppUsageSummary> _candidates;
  bool _hasDailyLimit = false;
  int _dailyLimitMinutes = 180;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name);
    _selectedApps = {
      for (final app in widget.existing?.apps ?? const <RoutineApp>[])
        app.appKey: app,
    };
    _candidates = _buildCandidates();
    _hasDailyLimit = widget.existing?.dailyLimitMinutes != null;
    _dailyLimitMinutes = widget.existing?.dailyLimitMinutes ?? 180;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _nameController.text.trim().isNotEmpty && _selectedApps.isNotEmpty;
    final namePrompt =
        _selectedApps.isNotEmpty && _nameController.text.trim().isEmpty;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? context.l10n.routineEditorNewTitle
                        : context.l10n.routineEditorEditTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameController,
              autofocus: widget.existing == null,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.l10n.routineEditorName,
                // A gentle, warm nudge once apps are chosen: a hint, never
                // the saved name and never an error.
                hintText: namePrompt ? context.l10n.routineNamePrompt : null,
                hintStyle: TextStyle(color: UsageCategory.entertainment.color),
                floatingLabelBehavior: namePrompt
                    ? FloatingLabelBehavior.always
                    : FloatingLabelBehavior.auto,
                prefixIcon: Icon(
                  Icons.bookmark_outline,
                  color: namePrompt ? UsageCategory.entertainment.color : null,
                ),
                border: _roundedBorder(),
                enabledBorder: _roundedBorder(
                  color: namePrompt ? UsageCategory.entertainment.color : null,
                ),
                focusedBorder: _roundedBorder(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(context.l10n.routineDailyLimit),
            subtitle: Text(
              _hasDailyLimit
                  ? context.l10n.compactDuration(
                      Duration(minutes: _dailyLimitMinutes),
                    )
                  : context.l10n.routineNoDailyLimit,
            ),
            value: _hasDailyLimit,
            onChanged: (value) => setState(() => _hasDailyLimit = value),
          ),
          if (_hasDailyLimit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hours in const [1, 2, 3, 4])
                    ChoiceChip(
                      label: Text(
                        context.l10n.compactDuration(Duration(hours: hours)),
                      ),
                      selected: _dailyLimitMinutes == hours * 60,
                      onSelected: (_) =>
                          setState(() => _dailyLimitMinutes = hours * 60),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(context.l10n.routineCustomDuration),
                    onPressed: _chooseCustomDuration,
                  ),
                ],
              ),
            ),
          Expanded(
            child: RoutineAppPicker(
              apps: _candidates,
              selected: _selectedApps.keys.toSet(),
              onChanged: _select,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSave ? _save : null,
                icon: const Icon(Icons.save_outlined),
                label: Text(context.l10n.routineEditorSave),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<AppUsageSummary> _buildCandidates() {
    final byKey = <String, AppUsageSummary>{
      for (final app in widget.apps) app.appKey: app,
    };
    for (final app in widget.existing?.apps ?? const <RoutineApp>[]) {
      byKey.putIfAbsent(
        app.appKey,
        () => AppUsageSummary(
          appName: app.appName,
          packageName: app.appKey,
          totalDurationSeconds: 0,
          percentageOfTotal: 0,
        ),
      );
    }
    return byKey.values.toList();
  }

  void _select(Set<String> keys) {
    final names = {for (final app in _candidates) app.appKey: app.appName};
    setState(() {
      _selectedApps.removeWhere((key, _) => !keys.contains(key));
      for (final key in keys) {
        // Keep an existing member's settings (inclusion, app limit).
        _selectedApps.putIfAbsent(
          key,
          () => RoutineApp(appKey: key, appName: names[key] ?? key),
        );
      }
    });
  }

  void _save() {
    final existing = widget.existing;
    Navigator.of(context).pop(
      BlockRoutine(
        id:
            existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        name: _nameController.text.trim(),
        apps: _selectedApps.values.toList(),
        dailyLimitMinutes: _hasDailyLimit ? _dailyLimitMinutes : null,
        isEnabled: _hasDailyLimit && (existing?.isEnabled ?? true),
      ),
    );
  }

  Future<void> _chooseCustomDuration() async {
    final selected = await showRoutineLimitPicker(
      context,
      initialMinutes: _dailyLimitMinutes,
    );
    if (selected != null && mounted) {
      setState(() => _dailyLimitMinutes = selected);
    }
  }
}

OutlineInputBorder _roundedBorder({Color? color, double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(28),
    borderSide: BorderSide(
      color: color ?? const Color(0xFF465064),
      width: width,
    ),
  );
}

/// Returns minutes, null when cancelled, or 0 when [removeLabel] was chosen.
Future<int?> showRoutineLimitPicker(
  BuildContext context, {
  required int initialMinutes,
  String? title,
  String? hint,
  String? removeLabel,
}) {
  var hours = initialMinutes ~/ 60;
  var minutes = initialMinutes % 60;
  minutes = (minutes / 5).round() * 5;
  if (minutes == 60) {
    hours += 1;
    minutes = 0;
  }
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final valid = hours > 0 || minutes > 0;
        return AlertDialog(
          title: Text(title ?? context.l10n.routineChooseDuration),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(hint),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: hours.clamp(0, 24),
                    items: [
                      for (var value = 0; value <= 24; value++)
                        DropdownMenuItem(value: value, child: Text('$value h')),
                    ],
                    onChanged: (value) => setDialogState(() {
                      hours = value ?? 0;
                      if (hours == 24) minutes = 0;
                    }),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: hours == 24 ? 0 : minutes,
                    items: [
                      for (var value = 0; value < 60; value += 5)
                        DropdownMenuItem(
                          value: value,
                          child: Text('$value min'),
                        ),
                    ],
                    onChanged: hours == 24
                        ? null
                        : (value) => setDialogState(() => minutes = value ?? 0),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (removeLabel != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(0),
                child: Text(removeLabel),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.of(context).pop(hours * 60 + minutes)
                  : null,
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        );
      },
    ),
  );
}
