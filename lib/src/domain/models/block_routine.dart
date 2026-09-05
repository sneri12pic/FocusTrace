import 'dart:convert';

class RoutineApp {
  const RoutineApp({
    required this.appKey,
    required this.appName,
    this.isIncludedInLimit = true,
  });

  final String appKey;
  final String appName;
  final bool isIncludedInLimit;

  RoutineApp copyWith({
    String? appKey,
    String? appName,
    bool? isIncludedInLimit,
  }) {
    return RoutineApp(
      appKey: appKey ?? this.appKey,
      appName: appName ?? this.appName,
      isIncludedInLimit: isIncludedInLimit ?? this.isIncludedInLimit,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'appKey': appKey,
      'appName': appName,
      'isIncludedInLimit': isIncludedInLimit,
    };
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
    return RoutineApp(
      appKey: appKey,
      appName: appName,
      isIncludedInLimit: value['isIncludedInLimit'] is bool
          ? value['isIncludedInLimit'] as bool
          : true,
    );
  }
}

class BlockRoutine {
  const BlockRoutine({
    required this.id,
    required this.name,
    required this.apps,
    this.dailyLimitMinutes,
    this.isEnabled = false,
  });

  final String id;
  final String name;
  final List<RoutineApp> apps;
  final int? dailyLimitMinutes;
  final bool isEnabled;

  bool get canEnforceLimit =>
      dailyLimitMinutes != null &&
      dailyLimitMinutes! > 0 &&
      apps.any((app) => app.isIncludedInLimit);

  int usageSeconds(Map<String, int> usageByAppKey) {
    return apps
        .where((app) => app.isIncludedInLimit)
        .fold(0, (total, app) => total + (usageByAppKey[app.appKey] ?? 0));
  }

  BlockRoutine copyWith({
    String? id,
    String? name,
    List<RoutineApp>? apps,
    int? dailyLimitMinutes,
    bool clearDailyLimit = false,
    bool? isEnabled,
  }) {
    final nextApps = apps ?? this.apps;
    final nextLimit = clearDailyLimit
        ? null
        : dailyLimitMinutes ?? this.dailyLimitMinutes;
    final nextCanEnforce =
        nextLimit != null &&
        nextLimit > 0 &&
        nextApps.any((app) => app.isIncludedInLimit);
    return BlockRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      apps: nextApps,
      dailyLimitMinutes: nextLimit,
      isEnabled: nextCanEnforce && (isEnabled ?? this.isEnabled),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'isEnabled': isEnabled,
      'dailyLimitMinutes': dailyLimitMinutes,
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
    final dailyLimitMinutes = _positiveInt(value['dailyLimitMinutes']);
    final canEnforce =
        dailyLimitMinutes != null &&
        appsByKey.values.any((app) => app.isIncludedInLimit);
    return BlockRoutine(
      id: id,
      name: name.trim(),
      apps: appsByKey.values.toList(),
      dailyLimitMinutes: dailyLimitMinutes,
      // Legacy routines had no limit and used `isEnabled` as an immediate
      // block. They intentionally migrate to a disabled statistics group.
      isEnabled: canEnforce && value['isEnabled'] is bool
          ? value['isEnabled'] as bool
          : false,
    );
  }
}

String encodeBlockRoutines(List<BlockRoutine> routines) {
  return jsonEncode({
    'version': 2,
    'routines': routines.map((routine) => routine.toJson()).toList(),
  });
}

int? _positiveInt(Object? value) {
  final parsed = value is int
      ? value
      : value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
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
