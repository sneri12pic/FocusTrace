import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_item.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import 'app_category_widgets.dart';
import 'app_icon_avatar.dart';

// ponytail: prefix match covers the release and .dev packages; read the
// package name from the platform if another flavour ever ships.
const _ownPackage = 'com.stepandemianenko.focustrace';

/// The most-used app first, then every other app alphabetically, each once.
@visibleForTesting
List<AppUsageSummary> orderRoutineCandidates(List<AppUsageSummary> apps) {
  final byKey = <String, AppUsageSummary>{};
  for (final app in apps) {
    // The blocker never blocks FocusTrace itself, so it is not offered.
    if (app.appKey.startsWith(_ownPackage)) continue;
    final known = byKey[app.appKey];
    if (known == null ||
        app.totalDurationSeconds > known.totalDurationSeconds) {
      byKey[app.appKey] = app;
    }
  }
  final unique = byKey.values.toList();
  AppUsageSummary? top;
  for (final app in unique) {
    if (app.totalDurationSeconds > (top?.totalDurationSeconds ?? 0)) {
      top = app;
    }
  }
  final rest = unique.where((app) => app != top).toList()
    ..sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );
  return [?top, ...rest];
}

enum _Selection { none, some, all }

/// Pick apps one by one or a whole category at a time. Selection is owned by
/// the caller and survives filtering by search or category.
class RoutineAppPicker extends ConsumerStatefulWidget {
  const RoutineAppPicker({
    super.key,
    required this.apps,
    required this.selected,
    required this.onChanged,
  });

  final List<AppUsageSummary> apps;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  ConsumerState<RoutineAppPicker> createState() => _RoutineAppPickerState();
}

class _RoutineAppPickerState extends ConsumerState<RoutineAppPicker> {
  String _query = '';
  UsageCategory? _category;
  // Ordered and categorised once per app list, not on every keystroke.
  late List<AppUsageSummary> _ordered;
  Map<String, UsageCategory> _categories = const {};
  Map<String, UsageCategory>? _overrides;

  @override
  void initState() {
    super.initState();
    _ordered = orderRoutineCandidates(widget.apps);
  }

  @override
  void didUpdateWidget(RoutineAppPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.apps, widget.apps)) {
      _ordered = orderRoutineCandidates(widget.apps);
      _overrides = null;
    }
  }

  void _classify(Map<String, UsageCategory> overrides) {
    if (identical(overrides, _overrides)) return;
    _overrides = overrides;
    _categories = {
      for (final app in _ordered)
        app.appKey: resolveUsageCategory(app, overrides),
    };
  }

  _Selection _state(Iterable<String> keys) {
    var selected = 0, total = 0;
    for (final key in keys) {
      total++;
      if (widget.selected.contains(key)) selected++;
    }
    return selected == 0
        ? _Selection.none
        : selected == total
        ? _Selection.all
        : _Selection.some;
  }

  void _toggle(String key) {
    final next = {...widget.selected};
    next.contains(key) ? next.remove(key) : next.add(key);
    widget.onChanged(next);
  }

  void _toggleAll(List<String> keys) {
    final next = {...widget.selected};
    _state(keys) == _Selection.all ? next.removeAll(keys) : next.addAll(keys);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    _classify(
      ref.watch(appCategoriesViewModelProvider).asData?.value ??
          const <String, UsageCategory>{},
    );
    final l = context.l10n;
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final present = {for (final app in _ordered) _categories[app.appKey]!};
    final visible = [
      for (final app in _ordered)
        if ((_category == null || _categories[app.appKey] == _category) &&
            (query.isEmpty ||
                app.appName.toLowerCase().contains(query) ||
                app.appKey.toLowerCase().contains(query)))
          app,
    ];
    final categoryKeys = _category == null
        ? const <String>[]
        : [
            for (final app in _ordered)
              if (_categories[app.appKey] == _category) app.appKey,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: l.routineEditorSearchApps,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: l.routinePickerAll,
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final category in UsageCategory.values)
                if (present.contains(category))
                  _FilterChip(
                    label: l.usageCategoryLabel(category),
                    icon: category.icon,
                    color: category.color,
                    selected: _category == category,
                    selection: _state([
                      for (final app in _ordered)
                        if (_categories[app.appKey] == category) app.appKey,
                    ]),
                    onTap: () => setState(() => _category = category),
                  ),
            ],
          ),
        ),
        if (_category != null)
          _PickerRow(
            key: ValueKey('routine-picker-category-${_category!.name}'),
            leading: Icon(_category!.icon, color: _category!.color),
            title: l.routinePickerSelectCategory(
              l.usageCategoryLabel(_category!),
            ),
            selection: _state(categoryKeys),
            onTap: () => _toggleAll(categoryKeys),
            bold: true,
          ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    l.routineEditorNoMatchingApps,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  // Fixed row height keeps scrolling cheap and steady.
                  itemExtent: MediaQuery.textScalerOf(context).scale(64),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final app = visible[index];
                    return _PickerRow(
                      key: ValueKey(app.appKey),
                      leading: AppIconAvatar(
                        appName: app.appName,
                        iconBytes: app.iconBytes,
                      ),
                      title: app.appName,
                      selection: widget.selected.contains(app.appKey)
                          ? _Selection.all
                          : _Selection.none,
                      onTap: () => _toggle(app.appKey),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
    this.selection = _Selection.none,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final _Selection selection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .16)
            : colors.surfaceContainerHigh,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                ],
                Text(label),
                // How much of this category is already chosen.
                if (selection != _Selection.none) ...[
                  const SizedBox(width: 6),
                  _RoundCheck(selection, size: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    super.key,
    required this.leading,
    required this.title,
    required this.selection,
    required this.onTap,
    this.bold = false,
  });

  final Widget leading;
  final String title;
  final _Selection selection;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selection == _Selection.all,
      mixed: selection == _Selection.some,
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bold
                      ? const TextStyle(fontWeight: FontWeight.w700)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              _RoundCheck(selection),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round selection mark: empty ring, ring with a dash (some), or a filled
/// circle with a tick (all).
class _RoundCheck extends StatelessWidget {
  const _RoundCheck(this.selection, {this.size = 26});

  final _Selection selection;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final on = selection != _Selection.none;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selection == _Selection.all
            ? colors.primary
            : Colors.transparent,
        border: Border.all(
          color: on ? colors.primary : colors.outline,
          width: 2,
        ),
      ),
      child: switch (selection) {
        _Selection.all => Icon(
          Icons.check,
          size: size * .7,
          color: colors.onPrimary,
        ),
        _Selection.some => Icon(
          Icons.remove,
          size: size * .7,
          color: colors.primary,
        ),
        _Selection.none => null,
      },
    );
  }
}
