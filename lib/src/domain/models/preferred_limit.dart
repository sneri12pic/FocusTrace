import 'dart:convert';

import 'app_usage_summary.dart';
import 'usage_item.dart';

/// How long the user would like to spend per day on one app or one category.
/// It never blocks: near and past it the app only gets a red screen outline.
class PreferredLimit {
  const PreferredLimit({
    this.category,
    this.appKey,
    this.appName,
    required this.minutes,
  });

  final UsageCategory? category;
  final String? appKey;
  final String? appName;
  final int minutes;

  bool hasSameTarget(PreferredLimit other) =>
      category == other.category && appKey == other.appKey;

  PreferredLimit withMinutes(int value) => PreferredLimit(
    category: category,
    appKey: appKey,
    appName: appName,
    minutes: value,
  );

  Map<String, Object?> toJson() => {
    'category': category?.name,
    'appKey': appKey,
    'appName': appName,
    'minutes': minutes,
  };

  static PreferredLimit? fromJson(Object? value) {
    if (value is! Map) return null;
    final minutes = value['minutes'];
    final appKey = value['appKey'];
    final category = UsageCategory.values
        .where((category) => category.name == value['category'])
        .firstOrNull;
    if (minutes is! int || minutes <= 0) return null;
    if ((appKey is! String || appKey.isEmpty) && category == null) return null;
    return PreferredLimit(
      category: category,
      appKey: category == null ? appKey as String : null,
      appName: value['appName'] as String?,
      minutes: minutes,
    );
  }
}

String encodePreferredLimits(List<PreferredLimit> limits) =>
    jsonEncode(limits.map((limit) => limit.toJson()).toList());

List<PreferredLimit> decodePreferredLimits(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) return const [];
  try {
    final decoded = jsonDecode(rawValue);
    if (decoded is! List) return const [];
    return decoded
        .map(PreferredLimit.fromJson)
        .whereType<PreferredLimit>()
        .toList();
  } on FormatException {
    return const [];
  }
}

/// Native code cannot classify apps, so each limit goes to the blocker with the
/// apps counted toward it. A category with no apps is left out.
List<Map<String, Object>> preferredLimitsForBlocker(
  List<PreferredLimit> limits, {
  required List<AppUsageSummary> installedApps,
  required Map<String, UsageCategory> categoryOverrides,
  required List<String> excludedApps,
}) {
  final payload = <Map<String, Object>>[];
  for (final limit in limits) {
    final apps = limit.appKey != null
        ? [limit.appKey!]
        : [
            for (final app in installedApps)
              if (!excludedApps.contains(app.appKey) &&
                  resolveUsageCategory(app, categoryOverrides) ==
                      limit.category)
                app.appKey,
          ];
    if (apps.isNotEmpty) {
      payload.add({'limitMinutes': limit.minutes, 'apps': apps});
    }
  }
  return payload;
}
