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

/// Applies or clears one named ManagedSettingsStore per block (rule, routine
/// allowance, routine member cap; see ShieldPlanner). iOS shields an app while
/// any store shields it, so lifting one block never unblocks an app another
/// block still holds (as on Android, where every reason must end).
enum ShieldController {
  /// Re-evaluates every block at `now + tolerance` and makes the shields match.
  /// The monitor passes a small tolerance because DeviceActivity may wake it a
  /// moment before an interval boundary (including the day's end, which lifts
  /// reached limits).
  @discardableResult
  static func reconcile(
    store: RestrictionStore = .shared, now: Date = Date(), tolerance: TimeInterval = 0
  ) -> Set<String> {
    let at = now.addingTimeInterval(tolerance)
    var shielded = Set<String>()
    var names = Set<String>()
    for block in ShieldPlanner.blocks(for: store.configuration) {
      names.insert(block.storeName)
      let settings = ManagedSettingsStore(named: ManagedSettingsStore.Name(block.storeName))
      let selection = combinedSelection(block.selectionIds, store: store)
      if ShieldPlanner.isActive(block, at: at, isReached: { store.isReached($0, at: at) }),
        !selection.isEmptySelection
      {
        apply(selection, to: settings)
        shielded.insert(block.key)
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

  /// The blocks whose apps include what `matches` accepts, preferring those
  /// shielded now; for the shield and shield-action extensions.
  static func blocks(
    store: RestrictionStore, now: Date, matches: (FamilyActivitySelection) -> Bool
  ) -> [ShieldBlock] {
    let candidates = ShieldPlanner.blocks(for: store.configuration).filter { block in
      block.selectionIds.contains { id in store.selection(id: id).map(matches) ?? false }
    }
    let shielded = store.shieldedRuleKeys
    let current = candidates.filter { shielded.contains($0.key) }
    if !current.isEmpty { return current }
    return candidates.filter {
      ShieldPlanner.isActive($0, at: now, isReached: { store.isReached($0, at: now) })
    }
  }

  /// The tokens of several picked selections together (a routine's members).
  static func combinedSelection(_ ids: [String], store: RestrictionStore)
    -> FamilyActivitySelection
  {
    var combined = FamilyActivitySelection()
    for id in ids {
      guard let selection = store.selection(id: id) else { continue }
      combined.applicationTokens.formUnion(selection.applicationTokens)
      combined.categoryTokens.formUnion(selection.categoryTokens)
      combined.webDomainTokens.formUnion(selection.webDomainTokens)
    }
    return combined
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
  /// Makes FocusTrace's monitored activities match the plans. An activity
  /// whose plan (and picked apps) did not change keeps running: restarting a
  /// usage activity could change how its usage is counted. Returns how many
  /// are monitored; failures are logged and leave the app-side shields in place.
  @discardableResult
  static func reschedule(
    configuration: RestrictionConfiguration, store: RestrictionStore = .shared,
    now: Date = Date()
  ) -> Int {
    let center = DeviceActivityCenter()
    let plans = ScheduleMapper.plans(for: configuration, now: now)
    let running = Set(center.activities.map(\.rawValue).filter { $0.hasPrefix(ScheduleMapper.prefix) })
    let previous = store.monitorPlanSignatures
    var signatures: [String: String] = [:]
    for plan in plans {
      signatures[plan.name] = signature(of: plan, store: store)
    }
    let obsolete = running.filter { signatures[$0] == nil || signatures[$0] != previous[$0] }
    if !obsolete.isEmpty {
      center.stopMonitoring(obsolete.map { DeviceActivityName($0) })
    }
    var monitored = 0
    var kept: [String: String] = [:]
    for plan in plans {
      let name = plan.name
      if running.contains(name) && !obsolete.contains(name) {
        monitored += 1
        kept[name] = signatures[name]
        continue
      }
      let schedule = DeviceActivitySchedule(
        intervalStart: plan.start,
        intervalEnd: plan.end,
        repeats: plan.repeats,
        warningTime: plan.warning
      )
      var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
      for event in plan.events {
        events[DeviceActivityEvent.Name(event.name)] = deviceActivityEvent(event, store: store)
      }
      do {
        try center.startMonitoring(DeviceActivityName(name), during: schedule, events: events)
        monitored += 1
        kept[name] = signatures[name]
      } catch {
        NSLog("FocusTrace: could not monitor \(name): \(error)")
      }
    }
    store.monitorPlanSignatures = kept
    return monitored
  }

  private static func deviceActivityEvent(_ event: ThresholdPlan, store: RestrictionStore)
    -> DeviceActivityEvent
  {
    let selection = ShieldController.combinedSelection(event.selectionIds, store: store)
    let threshold = DateComponents(hour: event.minutes / 60, minute: event.minutes % 60)
    if #available(iOS 17.4, *) {
      // Use earlier today counts, as Android's limits count the whole day.
      return DeviceActivityEvent(
        applications: selection.applicationTokens,
        categories: selection.categoryTokens,
        webDomains: selection.webDomainTokens,
        threshold: threshold,
        includesPastActivity: true)
    }
    return DeviceActivityEvent(
      applications: selection.applicationTokens,
      categories: selection.categoryTokens,
      webDomains: selection.webDomainTokens,
      threshold: threshold)
  }

  /// The plan plus a checksum of every selection its events count, so an
  /// edited selection restarts the activity.
  private static func signature(of plan: MonitorPlan, store: RestrictionStore) -> String {
    let ids = UsageEvents.unique(plan.events.flatMap(\.selectionIds))
    let data = ids.map { id in
      id + "=" + UsageEvents.stableHash(bytes: Array(store.selectionData(id: id) ?? Data()))
    }
    return plan.signature + "|" + data.joined(separator: ",")
  }
}

/// What the app does after a sync or when it becomes active.
enum RestrictionEnforcer {
  static func refresh(store: RestrictionStore = .shared, now: Date = Date()) {
    ShieldController.reconcile(store: store, now: now)
    ActivityScheduler.reschedule(configuration: store.configuration, store: store, now: now)
  }
}
