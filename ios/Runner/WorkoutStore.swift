import Foundation

/// One workout read from Apple Health. Times are epoch milliseconds; the
/// fields mirror `HealthConnectStore.ImportedWorkout` on Android.
struct StoredWorkout: Codable, Equatable {
  var id: String
  var sourceBundle: String
  var sourceName: String
  /// `HKWorkoutActivityType.rawValue`.
  var activityType: Int
  /// strength / running / walking / cycling / swimming / yoga / other.
  var category: String
  var title: String?
  var startMillis: Int64
  var endMillis: Int64
}

/// Apple Health settings, import state and the imported workouts: the iOS
/// counterpart of `HealthConnectStore.kt`. Pure Foundation so it is unit
/// tested on the macOS CI host (tool/ios/kit_tests).
///
/// Kept apart from the Flutter database and the App Group on purpose: nothing
/// here enters cloud sync, the portable backup or an iCloud device backup
/// (the file is excluded from backup), and no extension reads it.
final class WorkoutStore {
  static let outcomeImported = "imported"
  static let outcomeNoNew = "noNew"
  static let reconcileDays = 30
  static let listLimit = 200

  private enum Key {
    static let enabled = "ft.health.enabled"
    static let autoImport = "ft.health.autoImport"
    static let anchor = "ft.health.anchor"
    static let lastSuccess = "ft.health.lastSuccessMillis"
    static let lastAttempt = "ft.health.lastAttemptMillis"
    static let outcome = "ft.health.lastOutcome"
    static let count = "ft.health.lastImportedCount"
  }

  let defaults: UserDefaults
  let fileURL: URL
  private var cache: [String: StoredWorkout]?
  /// Bumped by `clearImported`. An import compares it before applying what
  /// Health answered, so a run that started before a clear cannot write its
  /// rows and anchor back afterwards.
  private(set) var generation = 0

  init(defaults: UserDefaults, fileURL: URL) {
    self.defaults = defaults
    self.fileURL = fileURL
  }

  /// `Application Support/focustrace_workouts.json` of the app.
  static func standard() -> WorkoutStore {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return WorkoutStore(
      defaults: .standard, fileURL: base.appendingPathComponent("focustrace_workouts.json"))
  }

  var enabled: Bool {
    get { defaults.bool(forKey: Key.enabled) }
    set { defaults.set(newValue, forKey: Key.enabled) }
  }

  var autoImport: Bool {
    get { defaults.bool(forKey: Key.autoImport) }
    set { defaults.set(newValue, forKey: Key.autoImport) }
  }

  /// Archived `HKQueryAnchor`; nil means the next run reconciles 30 days.
  var anchorData: Data? {
    get { defaults.data(forKey: Key.anchor) }
    set { defaults.set(newValue, forKey: Key.anchor) }
  }

  var lastSuccessMillis: Int64 { Int64(defaults.double(forKey: Key.lastSuccess)) }
  var lastAttemptMillis: Int64 { Int64(defaults.double(forKey: Key.lastAttempt)) }
  var lastOutcome: String? { defaults.string(forKey: Key.outcome) }
  var lastImportedCount: Int { defaults.integer(forKey: Key.count) }

  func recordAttempt(outcome: String, importedCount: Int, nowMillis: Int64) {
    defaults.set(Double(nowMillis), forKey: Key.lastAttempt)
    defaults.set(outcome, forKey: Key.outcome)
    defaults.set(importedCount, forKey: Key.count)
    if outcome == Self.outcomeImported || outcome == Self.outcomeNoNew {
      defaults.set(Double(nowMillis), forKey: Key.lastSuccess)
    }
  }

  // MARK: Workouts

  private var rows: [String: StoredWorkout] {
    get {
      if let cache = cache { return cache }
      var loaded: [String: StoredWorkout] = [:]
      if let data = try? Data(contentsOf: fileURL),
        let list = try? JSONDecoder().decode([StoredWorkout].self, from: data)
      {
        for workout in list { loaded[workout.id] = workout }
      }
      cache = loaded
      return loaded
    }
    set { cache = newValue }
  }

  /// Writes the workouts; call once per import run.
  func save() throws {
    let list = rows.values.sorted { $0.startMillis > $1.startMillis }
    let data = try JSONEncoder().encode(list)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: fileURL, options: .atomic)
    var url = fileURL
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
  }

  /// Inserts or replaces by id; true when the workout is new or changed.
  @discardableResult
  func upsert(_ workout: StoredWorkout) -> Bool {
    if rows[workout.id] == workout { return false }
    rows[workout.id] = workout
    return true
  }

  @discardableResult
  func delete(id: String) -> Bool {
    rows.removeValue(forKey: id) != nil
  }

  /// Removes workouts starting in [from, to) whose ids are not in `keep`.
  @discardableResult
  func deleteMissing(fromMillis: Int64, toMillis: Int64, keep: Set<String>) -> Int {
    let stale = rows.values
      .filter { $0.startMillis >= fromMillis && $0.startMillis < toMillis && !keep.contains($0.id) }
      .map(\.id)
    stale.forEach { delete(id: $0) }
    return stale.count
  }

  /// Newest first, at most `limit`.
  func workouts(limit: Int = WorkoutStore.listLimit) -> [StoredWorkout] {
    Array(rows.values.sorted { ($0.startMillis, $0.id) > ($1.startMillis, $1.id) }.prefix(limit))
  }

  var workoutCount: Int { rows.count }

  /// Deletes imported workouts and import state; settings stay as they are.
  func clearImported() {
    generation &+= 1
    rows = [:]
    try? FileManager.default.removeItem(at: fileURL)
    for key in [Key.anchor, Key.lastSuccess, Key.lastAttempt, Key.outcome, Key.count] {
      defaults.removeObject(forKey: key)
    }
  }

  /// What `focustrace/health_connect` answers to `state` (Dart's
  /// `HealthConnectStatus.fromMap`). Apple Health never tells an app whether
  /// read access was granted, so `readGranted` means "the permission sheet
  /// was answered"; background reads need no separate permission.
  func status(available: Bool, requestAnswered: Bool) -> [String: Any] {
    [
      "sdkStatus": available ? "available" : "unavailable",
      "enabled": enabled,
      "autoImport": autoImport,
      "readGranted": available && requestAnswered,
      "backgroundGranted": available,
      "backgroundSupported": available,
      "lastSuccessMillis": NSNumber(value: lastSuccessMillis),
      "lastAttemptMillis": NSNumber(value: lastAttemptMillis),
      "lastOutcome": lastOutcome.map { $0 as Any } ?? NSNull(),
      "lastImportedCount": lastImportedCount,
      "workoutCount": workoutCount,
      "store": "appleHealth",
    ]
  }

  /// One row of `workouts`, as Dart's `ImportedWorkout.fromMap` reads it.
  static func channelMap(_ workout: StoredWorkout) -> [String: Any] {
    var map: [String: Any] = [
      "id": workout.id,
      "sourcePackage": workout.sourceBundle,
      "sourceName": workout.sourceName.isEmpty ? workout.sourceBundle : workout.sourceName,
      "exerciseType": workout.activityType,
      "category": workout.category,
      "startMillis": NSNumber(value: workout.startMillis),
      "endMillis": NSNumber(value: workout.endMillis),
    ]
    if let title = workout.title, !title.isEmpty { map["title"] = title }
    return map
  }
}
