import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/block_routine.dart';
import '../localization/app_localizations_x.dart';

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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name);
    _selectedApps = {
      for (final app in widget.existing?.apps ?? const <RoutineApp>[])
        app.appKey: app,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates();
    final canSave =
        _nameController.text.trim().isNotEmpty && _selectedApps.isNotEmpty;
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
                prefixIcon: const Icon(Icons.bookmark_outline),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.routineEditorSearchApps,
                prefixIcon: const Icon(Icons.search),
                suffixText: context.l10n.restrictionsRoutineAppCount(
                  _selectedApps.length,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: candidates.isEmpty
                ? Center(child: Text(context.l10n.routineEditorNoMatchingApps))
                : ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final isSelected = _selectedApps.containsKey(
                        candidate.appKey,
                      );
                      return CheckboxListTile(
                        value: isSelected,
                        secondary: _RoutineAppIcon(
                          appName: candidate.appName,
                          iconBytes: candidate.iconBytes,
                        ),
                        title: Text(
                          candidate.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        onChanged: (_) => _toggle(candidate),
                      );
                    },
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

  List<AppUsageSummary> _candidates() {
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
    final query = _query.trim().toLowerCase();
    final candidates =
        byKey.values
            .where(
              (app) =>
                  query.isEmpty ||
                  app.appName.toLowerCase().contains(query) ||
                  app.appKey.toLowerCase().contains(query),
            )
            .toList()
          ..sort(
            (first, second) => first.appName.toLowerCase().compareTo(
              second.appName.toLowerCase(),
            ),
          );
    return candidates;
  }

  void _toggle(AppUsageSummary app) {
    setState(() {
      if (_selectedApps.containsKey(app.appKey)) {
        _selectedApps.remove(app.appKey);
      } else {
        _selectedApps[app.appKey] = RoutineApp(
          appKey: app.appKey,
          appName: app.appName,
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
        isEnabled: existing?.isEnabled ?? true,
      ),
    );
  }
}

class _RoutineAppIcon extends StatelessWidget {
  const _RoutineAppIcon({required this.appName, this.iconBytes});

  final String appName;
  final Uint8List? iconBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = iconBytes;
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: 40,
          height: 40,
          cacheWidth: 120,
          fit: BoxFit.cover,
        ),
      );
    }
    return CircleAvatar(
      child: Text(appName.isEmpty ? '?' : appName[0].toUpperCase()),
    );
  }
}
