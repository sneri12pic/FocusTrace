import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// The Screen Time half of FocusTraceKit: decoding stored picker selections,
// applying shields and registering DeviceActivity monitoring. Used by the app
// (after every sync and when it becomes active) and by the monitor extension
// (at every interval boundary, also with the app killed).

enum SelectionCodec {
  static func encode(_ selection: FamilyActivitySelection) -> Data? {
    try? JSONEncoder().encode(selection)
  }

  static func decode(_ data: Data) -> FamilyActivitySelection? {
    try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  /// A stable string for one app or web domain token, the key under which the
  /// block screen records what it listed (`RestrictionStore.recordDisplayed`).
  static func tokenKey(_ token: ApplicationToken) -> String? {
    tokenKey(prefix: "app:", token)
  }

  static func tokenKey(_ token: WebDomainToken) -> String? {
    tokenKey(prefix: "web:", token)
  }

  private static func tokenKey<T: Encodable>(prefix: String, _ token: T) -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(token)).map { prefix + $0.base64EncodedString() }
  }
}

extension RestrictionStore {
  func selection(id: String) -> FamilyActivitySelection? {
    selectionData(id: id).flatMap(SelectionCodec.decode)
  }

  @discardableResult
  func storeSelection(_ selection: FamilyActivitySelection, id: String) -> Bool {
    guard let data = SelectionCodec.encode(selection) else { return false }
    setSelectionData(data, id: id)
    return true
  }
}

extension FamilyActivitySelection {
  var isEmptySelection: Bool {
    applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
  }

  func contains(application token: ApplicationToken?) -> Bool {
    token.map { applicationTokens.contains($0) } ?? false
  }

  func contains(category token: ActivityCategoryToken?) -> Bool {
    token.map { categoryTokens.contains($0) } ?? false
  }

  func contains(webDomain token: WebDomainToken?) -> Bool {
    token.map { webDomainTokens.contains($0) } ?? false
  }
}

/// Applies or clears one named ManagedSettingsStore per rule. iOS shields an
/// app while any store shields it, so lifting one rule never unblocks an app
/// another rule still blocks (as on Android, where every reason must end).
enum ShieldController {
  static func storeName(for rule: RestrictionRule) -> String {
    "ft.\(rule.type.rawValue).\(rule.selectionId ?? rule.appKey)"
  }

  /// Re-evaluates every rule at `now + tolerance` and makes the shields match.
  /// The monitor passes a small tolerance because DeviceActivity may wake it a
  /// moment before an interval boundary.
  ///
  /// The app and the monitor extension may reconcile at the same time. A file
  /// lock in the App Group serializes them, and a reconcile that sees the
  /// configuration generation change while it applied shields runs again, so
  /// shields computed from an older configuration never stay in place.
  @discardableResult
  static func reconcile(
    store: RestrictionStore = .shared, now: Date = Date(), tolerance: TimeInterval = 0
  ) -> Set<String> {
    AppGroup.withLock("shields") {
      var shielded = Set<String>()
      for _ in 0..<3 {
        let generation = store.configurationGeneration
        shielded = applyShields(store: store, at: now.addingTimeInterval(tolerance))
        if store.configurationGeneration == generation { break }
      }
      return shielded
    }
  }

  private static func applyShields(store: RestrictionStore, at: Date) -> Set<String> {
    var shielded = Set<String>()
    var names = Set<String>()
    for rule in store.configuration.rules {
      guard let id = rule.selectionId else { continue }
      let name = storeName(for: rule)
      names.insert(name)
      let settings = ManagedSettingsStore(named: ManagedSettingsStore.Name(name))
      if rule.isBlocked(at: at), let selection = store.selection(id: id),
        !selection.isEmptySelection
      {
        apply(selection, to: settings)
        shielded.insert(rule.key)
      } else {
        settings.clearAllSettings()
      }
    }
    for stale in store.shieldStoreNames.subtracting(names) {
      ManagedSettingsStore(named: ManagedSettingsStore.Name(stale)).clearAllSettings()
    }
    store.shieldStoreNames = names
    store.shieldedRuleKeys = shielded
    return shielded
  }

  private static func apply(_ selection: FamilyActivitySelection, to settings: ManagedSettingsStore)
  {
    let apps = selection.applicationTokens
    let categories = selection.categoryTokens
    let domains = selection.webDomainTokens
    settings.shield.applications = apps.isEmpty ? nil : apps
    settings.shield.webDomains = domains.isEmpty ? nil : domains
    if categories.isEmpty {
      settings.shield.applicationCategories = nil
      settings.shield.webDomainCategories = nil
    } else {
      settings.shield.applicationCategories = .specific(categories)
      settings.shield.webDomainCategories = .specific(categories)
    }
  }
}

/// Registers the DeviceActivity monitoring ScheduleMapper plans.
enum ActivityScheduler {
  /// Replaces FocusTrace's monitored activities. Returns how many were
  /// registered; failures are logged and leave the app-side shields in place.
  @discardableResult
  static func reschedule(
    configuration: RestrictionConfiguration, now: Date = Date()
  ) -> Int {
    let center = DeviceActivityCenter()
    let ours = center.activities.filter { $0.rawValue.hasPrefix(ScheduleMapper.prefix) }
    if !ours.isEmpty {
      center.stopMonitoring(ours)
    }
    var registered = 0
    for plan in ScheduleMapper.plans(for: configuration, now: now) {
      let schedule = DeviceActivitySchedule(
        intervalStart: plan.start,
        intervalEnd: plan.end,
        repeats: plan.repeats,
        warningTime: plan.warning
      )
      do {
        try center.startMonitoring(DeviceActivityName(plan.name), during: schedule)
        registered += 1
      } catch {
        NSLog("FocusTrace: could not monitor \(plan.name): \(error)")
      }
    }
    return registered
  }
}

/// What the app does after a sync or when it becomes active.
enum RestrictionEnforcer {
  static func refresh(store: RestrictionStore = .shared, now: Date = Date()) {
    ShieldController.reconcile(store: store, now: now)
    ActivityScheduler.reschedule(configuration: store.configuration, now: now)
  }
}
