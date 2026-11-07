import Flutter
import Foundation
import HealthKit
import UIKit

/// `focustrace/health_connect` on iOS: the same methods and result maps as
/// Android's `HealthConnectBridge.kt`, backed by Apple Health workouts
/// (`HKWorkout`, read only; FocusTrace writes nothing to Health).
///
/// - The first import (and any after "Delete imported workouts") reconciles
///   the last 30 days, as Android; later imports apply the changes since the
///   saved `HKQueryAnchor` (new and deleted workouts).
/// - Automatic import: an `HKObserverQuery` with hourly background delivery,
///   registered at every launch while it is on, plus an import whenever
///   FocusTrace becomes active (at most every 15 minutes).
/// - Apple Health never reveals whether read access was granted: a denied
///   permission looks like "no workouts". `readGranted` therefore means the
///   permission sheet was answered.
final class HealthKitBridge: NSObject {
  static let shared = HealthKitBridge()

  private let healthStore = HKHealthStore()
  private let store = WorkoutStore.standard()
  /// Every store access and import bookkeeping happens here.
  private let queue = DispatchQueue(label: "com.stepandemianenko.focustrace.health")
  private var isImporting = false
  private var waiters: [() -> Void] = []
  private var observer: HKObserverQuery?

  private static let foregroundInterval: Int64 = 15 * 60 * 1000

  private var available: Bool { HKHealthStore.isHealthDataAvailable() }
  private var workoutType: HKObjectType { HKObjectType.workoutType() }

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "focustrace/health_connect", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    NotificationCenter.default.addObserver(
      self, selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    // Background delivery only reaches an app that registers its observer
    // query on every launch, including background launches.
    queue.async { [weak self] in self?.updateBackgroundDelivery() }
  }

  // MARK: Channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "state":
      replyState(result)
    case "enable":
      enable(result)
    case "disable":
      queue.async {
        self.store.enabled = false
        self.updateBackgroundDelivery()
        self.replyState(result)
      }
    case "setAutoImport":
      let on = call.arguments as? Bool ?? false
      queue.async {
        self.store.autoImport = on
        self.updateBackgroundDelivery()
        self.replyState(result)
      }
    case "importNow":
      runImport { self.replyState(result) }
    case "workouts":
      queue.async {
        Self.reply(result, self.store.workouts().map(WorkoutStore.channelMap))
      }
    case "clearImported":
      queue.async {
        self.store.clearImported()
        self.replyState(result)
      }
    case "openPermissionSettings":
      openHealthApp()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func enable(_ result: @escaping FlutterResult) {
    guard available else {
      replyState(result)
      return
    }
    healthStore.requestAuthorization(toShare: [], read: [workoutType]) { success, error in
      if let error = error {
        NSLog("FocusTrace: Health authorization failed: \(error)")
      }
      self.queue.async {
        // A shown and answered sheet; whether reading was allowed stays
        // private to Health.
        if success { self.store.enabled = true }
        self.updateBackgroundDelivery()
        self.replyState(result)
      }
    }
  }

  private func replyState(_ result: @escaping FlutterResult) {
    guard available else {
      queue.async { Self.reply(result, self.store.status(available: false, requestAnswered: false)) }
      return
    }
    healthStore.getRequestStatusForAuthorization(toShare: [], read: [workoutType]) {
      status, _ in
      self.queue.async {
        Self.reply(
          result,
          self.store.status(available: true, requestAnswered: status == .unnecessary))
      }
    }
  }

  private func openHealthApp() {
    let health = URL(string: "x-apple-health://")
    let settings = URL(string: UIApplication.openSettingsURLString)
    if let health = health {
      UIApplication.shared.open(health, options: [:]) { opened in
        if !opened, let settings = settings {
          UIApplication.shared.open(settings, options: [:], completionHandler: nil)
        }
      }
    }
  }

  // MARK: Automatic import

  @objc private func didBecomeActive() {
    queue.async {
      guard self.store.enabled, self.store.autoImport else { return }
      let now = Int64(Date().timeIntervalSince1970 * 1000)
      if now - self.store.lastAttemptMillis < Self.foregroundInterval { return }
      self.runImportLocked {}
    }
  }

  /// On `queue`. Starts or stops the observer query and background delivery.
  private func updateBackgroundDelivery() {
    let wanted = available && store.enabled && store.autoImport
    if wanted, observer == nil {
      guard let sampleType = workoutType as? HKSampleType else { return }
      let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {
        [weak self] _, completionHandler, error in
        guard let self = self, error == nil else {
          completionHandler()
          return
        }
        self.runImport { completionHandler() }
      }
      observer = query
      healthStore.execute(query)
      healthStore.enableBackgroundDelivery(for: workoutType, frequency: .hourly) { _, error in
        if let error = error {
          NSLog("FocusTrace: Health background delivery not enabled: \(error)")
        }
      }
    } else if !wanted, let query = observer {
      healthStore.stop(query)
      observer = nil
      healthStore.disableBackgroundDelivery(for: workoutType) { _, _ in }
    }
  }

  // MARK: Import

  /// One import at a time; callers arriving meanwhile get its result.
  private func runImport(_ completion: @escaping () -> Void) {
    queue.async { self.runImportLocked(completion) }
  }

  /// On `queue`.
  private func runImportLocked(_ completion: @escaping () -> Void) {
    if isImporting {
      waiters.append(completion)
      return
    }
    guard store.enabled else {
      completion()
      return
    }
    let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
    guard available else {
      store.recordAttempt(outcome: "unavailable", importedCount: 0, nowMillis: nowMillis)
      completion()
      return
    }
    isImporting = true
    waiters.append(completion)
    fetch(now: Date()) { outcome in
      self.queue.async {
        if let outcome = outcome, self.store.enabled {
          try? self.store.save()
          // A locked device is no attempt: the next foreground import must
          // not wait the 15 minutes.
          if outcome.recorded {
            self.store.recordAttempt(
              outcome: outcome.name, importedCount: outcome.changed, nowMillis: nowMillis)
          }
        }
        self.isImporting = false
        let done = self.waiters
        self.waiters = []
        done.forEach { $0() }
      }
    }
  }

  private struct Outcome {
    var name: String
    var changed: Int
    /// False when the run says nothing about the import (the device was
    /// locked): it is not recorded as the last attempt.
    var recorded = true
  }

  /// Runs the anchored query and applies it to the store (on `queue`).
  /// Answers nil when the import was switched off or the imported workouts
  /// were cleared meanwhile.
  private func fetch(now: Date, completion: @escaping (Outcome?) -> Void) {
    guard let sampleType = workoutType as? HKSampleType else {
      completion(Outcome(name: "failed", changed: 0))
      return
    }
    let anchor = store.anchorData.flatMap {
      try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
    }
    let from = now.addingTimeInterval(-Double(WorkoutStore.reconcileDays) * 86_400)
    let to = now.addingTimeInterval(86_400)
    // Without an anchor: the last 30 days, as Android's first run.
    let predicate =
      anchor == nil ? HKQuery.predicateForSamples(withStart: from, end: to, options: []) : nil
    let ownBundle = Bundle.main.bundleIdentifier
    let generation = store.generation
    let query = HKAnchoredObjectQuery(
      type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit
    ) { [weak self] _, samples, deleted, newAnchor, error in
      guard let self = self else { return }
      self.queue.async {
        guard self.store.enabled, self.store.generation == generation else {
          completion(nil)
          return
        }
        if let error = error {
          let code = (error as? HKError)?.code
          let denied =
            code == .errorAuthorizationDenied || code == .errorAuthorizationNotDetermined
          completion(
            Outcome(
              name: denied ? "permissionMissing" : "failed", changed: 0,
              recorded: code != .errorDatabaseInaccessible))
          return
        }
        var changed = 0
        var seen = Set<String>()
        for case let workout as HKWorkout in samples ?? [] {
          let source = workout.sourceRevision.source
          if source.bundleIdentifier == ownBundle { continue }
          let row = Self.storedWorkout(workout)
          seen.insert(row.id)
          if self.store.upsert(row) { changed += 1 }
        }
        for object in deleted ?? [] {
          if self.store.delete(id: object.uuid.uuidString) { changed += 1 }
        }
        if anchor == nil {
          changed += self.store.deleteMissing(
            fromMillis: Self.millis(from), toMillis: Self.millis(to), keep: seen)
        }
        if let newAnchor = newAnchor {
          self.store.anchorData = try? NSKeyedArchiver.archivedData(
            withRootObject: newAnchor, requiringSecureCoding: true)
        }
        completion(Outcome(name: changed > 0 ? "imported" : "noNew", changed: changed))
      }
    }
    healthStore.execute(query)
  }

  private static func storedWorkout(_ workout: HKWorkout) -> StoredWorkout {
    let source = workout.sourceRevision.source
    return StoredWorkout(
      id: workout.uuid.uuidString,
      sourceBundle: source.bundleIdentifier,
      sourceName: source.name,
      activityType: Int(workout.workoutActivityType.rawValue),
      category: category(workout.workoutActivityType),
      title: workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String,
      startMillis: millis(workout.startDate),
      endMillis: millis(workout.endDate))
  }

  /// The coarse groups Flutter localizes, as `HealthConnectBridge.category`.
  private static func category(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength"
    case .running: return "running"
    case .walking: return "walking"
    case .cycling: return "cycling"
    case .swimming: return "swimming"
    case .yoga: return "yoga"
    default: return "other"
    }
  }

  private static func millis(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
  }

  private static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    if Thread.isMainThread {
      result(value)
    } else {
      DispatchQueue.main.async { result(value) }
    }
  }
}
