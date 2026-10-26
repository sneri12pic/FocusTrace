/// Whether Health Connect can be used on this device at all.
enum HealthConnectAvailability { available, updateRequired, unavailable }

/// What the last import attempt ended with. [noNew] is a success.
enum HealthConnectOutcome {
  imported,
  noNew,
  unavailable,
  updateRequired,
  permissionMissing,
  backgroundPermissionMissing,
  failed;

  bool get isSuccess => this == imported || this == noNew;

  static HealthConnectOutcome? parse(Object? value) {
    for (final outcome in values) {
      if (outcome.name == value) return outcome;
    }
    return null;
  }
}

/// The optional Health Connect integration as the native side reports it.
/// FocusTrace only reads exercise sessions; it writes nothing.
class HealthConnectStatus {
  const HealthConnectStatus({
    this.availability = HealthConnectAvailability.unavailable,
    this.enabled = false,
    this.autoImport = false,
    this.readGranted = false,
    this.backgroundGranted = false,
    this.backgroundSupported = false,
    this.lastSuccess,
    this.lastAttempt,
    this.lastOutcome,
    this.lastImportedCount = 0,
    this.workoutCount = 0,
  });

  factory HealthConnectStatus.fromMap(Map<Object?, Object?> map) {
    DateTime? time(Object? millis) => millis is int && millis > 0
        ? DateTime.fromMillisecondsSinceEpoch(millis)
        : null;
    return HealthConnectStatus(
      availability: switch (map['sdkStatus']) {
        'available' => HealthConnectAvailability.available,
        'updateRequired' => HealthConnectAvailability.updateRequired,
        _ => HealthConnectAvailability.unavailable,
      },
      enabled: map['enabled'] == true,
      autoImport: map['autoImport'] == true,
      readGranted: map['readGranted'] == true,
      backgroundGranted: map['backgroundGranted'] == true,
      backgroundSupported: map['backgroundSupported'] == true,
      lastSuccess: time(map['lastSuccessMillis']),
      lastAttempt: time(map['lastAttemptMillis']),
      lastOutcome: HealthConnectOutcome.parse(map['lastOutcome']),
      lastImportedCount: map['lastImportedCount'] as int? ?? 0,
      workoutCount: map['workoutCount'] as int? ?? 0,
    );
  }

  final HealthConnectAvailability availability;
  final bool enabled;
  final bool autoImport;
  final bool readGranted;
  final bool backgroundGranted;
  final bool backgroundSupported;
  final DateTime? lastSuccess;
  final DateTime? lastAttempt;
  final HealthConnectOutcome? lastOutcome;
  final int lastImportedCount;
  final int workoutCount;

  /// On, but the read permission was revoked in Health Connect since.
  bool get accessRevoked => enabled && !readGranted;

  /// Automatic import is on but cannot run in the background.
  bool get autoImportBlocked => enabled && autoImport && !backgroundGranted;
}

/// An exercise session imported from Health Connect, with the app that wrote it.
class ImportedWorkout {
  const ImportedWorkout({
    required this.id,
    required this.sourcePackage,
    required this.sourceName,
    required this.exerciseType,
    required this.category,
    required this.start,
    required this.end,
    this.title,
  });

  factory ImportedWorkout.fromMap(Map<Object?, Object?> map) => ImportedWorkout(
    id: map['id'] as String,
    sourcePackage: map['sourcePackage'] as String,
    sourceName: map['sourceName'] as String? ?? map['sourcePackage'] as String,
    exerciseType: map['exerciseType'] as int? ?? 0,
    category: WorkoutCategory.parse(map['category']),
    title: map['title'] as String?,
    start: DateTime.fromMillisecondsSinceEpoch(map['startMillis'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(map['endMillis'] as int),
  );

  final String id;
  final String sourcePackage;
  final String sourceName;

  /// Health Connect's `ExerciseSessionRecord.EXERCISE_TYPE_*` value.
  final int exerciseType;
  final WorkoutCategory category;
  final String? title;

  /// Shown in the device's current time zone.
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

/// A coarse grouping of Health Connect exercise types, for display.
enum WorkoutCategory {
  strength,
  running,
  walking,
  cycling,
  swimming,
  yoga,
  other;

  static WorkoutCategory parse(Object? value) => values.firstWhere(
    (category) => category.name == value,
    orElse: () => other,
  );
}
