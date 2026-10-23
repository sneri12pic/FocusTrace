import 'dart:convert';

import 'block_routine.dart';

enum RestrictionRuleType {
  blockNow('blockNow'),
  dailyLimit('dailyLimit'),
  schedule('schedule');

  const RestrictionRuleType(this.jsonName);

  final String jsonName;

  static RestrictionRuleType? fromJsonName(String? value) {
    for (final type in RestrictionRuleType.values) {
      if (type.jsonName == value) {
        return type;
      }
    }
    return null;
  }
}

enum RestrictionDifficulty { easy, moderate, hard }

class RestrictionRule {
  const RestrictionRule({
    required this.appKey,
    required this.appName,
    required this.type,
    this.untilMs,
    this.limitMinutes,
    this.startMinute,
    this.endMinute,
    this.difficulty = RestrictionDifficulty.easy,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
  });

  factory RestrictionRule.blockNow({
    required String appKey,
    required String appName,
    required DateTime until,
  }) {
    return RestrictionRule(
      appKey: appKey,
      appName: appName,
      type: RestrictionRuleType.blockNow,
      untilMs: until.millisecondsSinceEpoch,
    );
  }

  factory RestrictionRule.dailyLimit({
    required String appKey,
    required String appName,
    required int limitMinutes,
  }) {
    return RestrictionRule(
      appKey: appKey,
      appName: appName,
      type: RestrictionRuleType.dailyLimit,
      limitMinutes: limitMinutes,
    );
  }

  factory RestrictionRule.schedule({
    required String appKey,
    required String appName,
    required int startMinute,
    required int endMinute,
  }) {
    return RestrictionRule(
      appKey: appKey,
      appName: appName,
      type: RestrictionRuleType.schedule,
      startMinute: startMinute,
      endMinute: endMinute,
    );
  }

  final String appKey;
  final String appName;
  final RestrictionRuleType type;
  final int? untilMs;
  final int? limitMinutes;
  final int? startMinute;
  final int? endMinute;
  final RestrictionDifficulty difficulty;

  /// ISO weekdays on which a schedule starts; overnight tails belong to that day.
  final List<int> weekdays;

  bool get isExpiredBlockNow {
    if (type != RestrictionRuleType.blockNow) {
      return false;
    }
    final until = untilMs;
    return until == null || until <= DateTime.now().millisecondsSinceEpoch;
  }

  bool blocksAt(DateTime now, int usageSecondsToday) {
    switch (type) {
      case RestrictionRuleType.blockNow:
        final until = untilMs;
        return until != null && now.millisecondsSinceEpoch < until;
      case RestrictionRuleType.dailyLimit:
        final limit = limitMinutes;
        return limit != null && usageSecondsToday >= limit * 60;
      case RestrictionRuleType.schedule:
        final start = startMinute;
        final end = endMinute;
        if (start == null || end == null || start == end) {
          return false;
        }
        final current = now.hour * 60 + now.minute;
        final startDay = end < start && current < end
            ? DateTime(now.year, now.month, now.day - 1)
            : now;
        if (!weekdays.contains(startDay.weekday)) return false;
        if (end < start) return current >= start || current < end;
        return current >= start && current < end;
    }
  }

  DateTime? blockedUntil(DateTime now, {int usageSecondsToday = 0}) {
    if (!blocksAt(now, usageSecondsToday)) {
      return null;
    }
    switch (type) {
      case RestrictionRuleType.blockNow:
        final until = untilMs;
        return until == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(until);
      case RestrictionRuleType.dailyLimit:
        return DateTime(now.year, now.month, now.day + 1);
      case RestrictionRuleType.schedule:
        final end = endMinute;
        if (end == null) {
          return null;
        }
        final endDate = DateTime(
          now.year,
          now.month,
          now.day,
          end ~/ 60,
          end % 60,
        );
        return endDate.isAfter(now)
            ? endDate
            : DateTime(now.year, now.month, now.day + 1, end ~/ 60, end % 60);
    }
  }

  DateTime? nextScheduledStart(DateTime now) {
    if (type != RestrictionRuleType.schedule || startMinute == null) {
      return null;
    }
    for (var offset = 0; offset <= 7; offset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day + offset,
        startMinute! ~/ 60,
        startMinute! % 60,
      );
      if (date.isAfter(now) && weekdays.contains(date.weekday)) return date;
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return {
      'appKey': appKey,
      'appName': appName,
      'type': type.jsonName,
      'difficulty': difficulty.name,
      'weekdays': weekdays,
      if (untilMs != null) 'untilMs': untilMs,
      if (limitMinutes != null) 'limitMinutes': limitMinutes,
      if (startMinute != null) 'startMinute': startMinute,
      if (endMinute != null) 'endMinute': endMinute,
    };
  }

  static RestrictionRule? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final row = Map<String, Object?>.from(value);
    final appKey = row['appKey'];
    final appName = row['appName'];
    final type = RestrictionRuleType.fromJsonName(row['type'] as String?);
    if (appKey is! String ||
        appKey.isEmpty ||
        appName is! String ||
        type == null) {
      return null;
    }

    final untilMs = _intValue(row['untilMs']);
    final limitMinutes = _intValue(row['limitMinutes']);
    final startMinute = _minuteValue(row['startMinute']);
    final endMinute = _minuteValue(row['endMinute']);

    switch (type) {
      case RestrictionRuleType.blockNow:
        if (untilMs == null) {
          return null;
        }
      case RestrictionRuleType.dailyLimit:
        if (limitMinutes == null || limitMinutes <= 0) {
          return null;
        }
      case RestrictionRuleType.schedule:
        if (startMinute == null ||
            endMinute == null ||
            startMinute == endMinute) {
          return null;
        }
    }

    return RestrictionRule(
      appKey: appKey,
      appName: appName,
      type: type,
      untilMs: untilMs,
      limitMinutes: limitMinutes,
      startMinute: startMinute,
      endMinute: endMinute,
      difficulty:
          RestrictionDifficulty.values.asNameMap()[row['difficulty']] ??
          RestrictionDifficulty.easy,
      weekdays: row['weekdays'] is List
          ? (row['weekdays'] as List)
                .whereType<int>()
                .where((d) => d >= 1 && d <= 7)
                .toSet()
                .toList()
          : const [1, 2, 3, 4, 5, 6, 7],
    );
  }

  RestrictionRule copyWith({
    String? appKey,
    String? appName,
    RestrictionRuleType? type,
    int? untilMs,
    int? limitMinutes,
    int? startMinute,
    int? endMinute,
    RestrictionDifficulty? difficulty,
    List<int>? weekdays,
  }) {
    return RestrictionRule(
      appKey: appKey ?? this.appKey,
      appName: appName ?? this.appName,
      type: type ?? this.type,
      untilMs: untilMs ?? this.untilMs,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      difficulty: difficulty ?? this.difficulty,
      weekdays: weekdays ?? this.weekdays,
    );
  }
}

String encodeRules(List<RestrictionRule> rules) {
  return jsonEncode({
    'version': 1,
    'rules': rules.map((rule) => rule.toJson()).toList(),
  });
}

String encodeRestrictionConfiguration(
  List<RestrictionRule> rules,
  List<BlockRoutine> routines,
) {
  return jsonEncode({
    'version': 3,
    'rules': rules.map((rule) => rule.toJson()).toList(),
    'routines': routines
        .where((routine) => routine.isEnabled && routine.canEnforceLimit)
        .map((routine) => routine.toJson())
        .toList(),
  });
}

List<RestrictionRule> decodeRules(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) {
    return const <RestrictionRule>[];
  }
  try {
    final decoded = jsonDecode(rawValue);
    final rawRules = decoded is Map ? decoded['rules'] : decoded;
    if (rawRules is! List) {
      return const <RestrictionRule>[];
    }
    return rawRules
        .map(RestrictionRule.fromJson)
        .whereType<RestrictionRule>()
        .toList();
  } on FormatException {
    return const <RestrictionRule>[];
  }
}

bool isAppBlocked({
  required String appKey,
  required List<RestrictionRule> rules,
  required DateTime now,
  required int usageSecondsToday,
}) {
  return rules.any(
    (rule) => rule.appKey == appKey && rule.blocksAt(now, usageSecondsToday),
  );
}

List<RestrictionRule> pruneExpiredBlockNowRules(List<RestrictionRule> rules) {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  return rules
      .where(
        (rule) =>
            rule.type != RestrictionRuleType.blockNow ||
            (rule.untilMs != null && rule.untilMs! > nowMs),
      )
      .toList();
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

int? _minuteValue(Object? value) {
  final parsed = _intValue(value);
  if (parsed == null || parsed < 0 || parsed >= 24 * 60) {
    return null;
  }
  return parsed;
}
