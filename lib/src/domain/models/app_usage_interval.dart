class AppUsageInterval {
  const AppUsageInterval({
    required this.id,
    required this.appKey,
    required this.appName,
    required this.startedAt,
    required this.endedAt,
  });

  final String id;
  final String appKey;
  final String appName;
  final DateTime startedAt;
  final DateTime endedAt;

  int get durationSeconds => endedAt.difference(startedAt).inSeconds;
}
