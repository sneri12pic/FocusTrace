import 'dart:convert';

class RoutineApp {
  const RoutineApp({required this.appKey, required this.appName});

  final String appKey;
  final String appName;

  Map<String, Object?> toJson() {
    return {'appKey': appKey, 'appName': appName};
  }

  static RoutineApp? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final appKey = value['appKey'];
    final appName = value['appName'];
    if (appKey is! String ||
        appKey.trim().isEmpty ||
        appName is! String ||
        appName.trim().isEmpty) {
      return null;
    }
    return RoutineApp(appKey: appKey, appName: appName);
  }
}

class BlockRoutine {
  const BlockRoutine({
    required this.id,
    required this.name,
    required this.apps,
    this.isEnabled = true,
  });

  final String id;
  final String name;
  final List<RoutineApp> apps;
  final bool isEnabled;

  BlockRoutine copyWith({
    String? id,
    String? name,
    List<RoutineApp>? apps,
    bool? isEnabled,
  }) {
    return BlockRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      apps: apps ?? this.apps,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'isEnabled': isEnabled,
      'apps': apps.map((app) => app.toJson()).toList(),
    };
  }

  static BlockRoutine? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final id = value['id'];
    final name = value['name'];
    final rawApps = value['apps'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        rawApps is! List) {
      return null;
    }
    final appsByKey = <String, RoutineApp>{};
    for (final rawApp in rawApps) {
      final app = RoutineApp.fromJson(rawApp);
      if (app != null) {
        appsByKey[app.appKey] = app;
      }
    }
    if (appsByKey.isEmpty) {
      return null;
    }
    return BlockRoutine(
      id: id,
      name: name.trim(),
      apps: appsByKey.values.toList(),
      isEnabled: value['isEnabled'] is bool ? value['isEnabled'] as bool : true,
    );
  }
}

String encodeBlockRoutines(List<BlockRoutine> routines) {
  return jsonEncode({
    'version': 1,
    'routines': routines.map((routine) => routine.toJson()).toList(),
  });
}

List<BlockRoutine> decodeBlockRoutines(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) {
    return const <BlockRoutine>[];
  }
  try {
    final decoded = jsonDecode(rawValue);
    final rawRoutines = decoded is Map ? decoded['routines'] : decoded;
    if (rawRoutines is! List) {
      return const <BlockRoutine>[];
    }
    return rawRoutines
        .map(BlockRoutine.fromJson)
        .whereType<BlockRoutine>()
        .toList();
  } on FormatException {
    return const <BlockRoutine>[];
  }
}
