import 'dart:typed_data';

class AppUsageSummary {
  const AppUsageSummary({
    required this.appName,
    required this.totalDurationSeconds,
    required this.percentageOfTotal,
    this.launchCount = 0,
    this.packageName,
    this.processName,
    this.lastUsedAt,
    this.iconBytes,
  });

  final String appName;
  final String? packageName;
  final String? processName;
  final int totalDurationSeconds;
  final double percentageOfTotal;
  final int launchCount;
  final DateTime? lastUsedAt;
  final Uint8List? iconBytes;

  String get appKey => packageName ?? processName ?? appName;

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);

  AppUsageSummary copyWith({
    String? appName,
    String? packageName,
    String? processName,
    int? totalDurationSeconds,
    double? percentageOfTotal,
    int? launchCount,
    DateTime? lastUsedAt,
    Uint8List? iconBytes,
  }) {
    return AppUsageSummary(
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      processName: processName ?? this.processName,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      percentageOfTotal: percentageOfTotal ?? this.percentageOfTotal,
      launchCount: launchCount ?? this.launchCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      iconBytes: iconBytes ?? this.iconBytes,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppUsageSummary &&
            other.appName == appName &&
            other.packageName == packageName &&
            other.processName == processName &&
            other.totalDurationSeconds == totalDurationSeconds &&
            other.percentageOfTotal == percentageOfTotal &&
            other.launchCount == launchCount &&
            other.lastUsedAt == lastUsedAt;
  }

  @override
  int get hashCode => Object.hash(
    appName,
    packageName,
    processName,
    totalDurationSeconds,
    percentageOfTotal,
    launchCount,
    lastUsedAt,
  );
}
