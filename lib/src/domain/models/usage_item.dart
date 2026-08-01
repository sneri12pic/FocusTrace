import 'dart:typed_data';

import 'app_usage_summary.dart';

enum UsageCategory {
  entertainment,
  productivity,
  web,
  communication,
  system,
  activity,
}

class UsageItem {
  const UsageItem({
    required this.id,
    required this.name,
    required this.totalDurationSeconds,
    required this.percentageOfTotal,
    required this.category,
    required this.initials,
    this.sourceName,
    this.iconBytes,
  });

  factory UsageItem.fromSummary(AppUsageSummary summary) {
    return UsageItem(
      id: summary.appKey,
      name: summary.appName,
      sourceName: summary.processName ?? summary.packageName,
      totalDurationSeconds: summary.totalDurationSeconds,
      percentageOfTotal: summary.percentageOfTotal,
      category: _categoryFor(summary.appName),
      initials: _initialsFor(summary.appName),
      iconBytes: summary.iconBytes,
    );
  }

  final String id;
  final String name;
  final String? sourceName;
  final int totalDurationSeconds;
  final double percentageOfTotal;
  final UsageCategory category;
  final String initials;
  final Uint8List? iconBytes;

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    final first = parts.first;
    return first
        .substring(0, first.length < 2 ? first.length : 2)
        .toUpperCase();
  }
  return parts.take(2).map((part) => part[0]).join().toUpperCase();
}

UsageCategory _categoryFor(String name) {
  final normalized = name.toLowerCase();
  if (_containsAny(normalized, const [
    'youtube',
    'tiktok',
    'instagram',
    'spotify',
    'netflix',
  ])) {
    return UsageCategory.entertainment;
  }
  if (_containsAny(normalized, const [
    'code',
    'studio',
    'terminal',
    'editor',
  ])) {
    return UsageCategory.productivity;
  }
  if (_containsAny(normalized, const [
    'chrome',
    'edge',
    'firefox',
    'safari',
    'browser',
  ])) {
    return UsageCategory.web;
  }
  if (_containsAny(normalized, const [
    'whatsapp',
    'discord',
    'gmail',
    'mail',
    'slack',
    'teams',
  ])) {
    return UsageCategory.communication;
  }
  if (_containsAny(normalized, const ['settings', 'system'])) {
    return UsageCategory.system;
  }
  return UsageCategory.activity;
}

bool _containsAny(String value, List<String> terms) {
  return terms.any(value.contains);
}
