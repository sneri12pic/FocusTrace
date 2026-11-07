import Foundation

/// Restriction state shared through the App Group by the app and every
/// extension: the configuration JSON Dart synced, the picker selections (as
/// opaque encoded data, keyed by selection id), which rules are shielded now,
/// block events for Flutter to import, and the shield's localized strings.
///
/// Pure Foundation (unit-tested in tool/ios/kit_tests); the Screen Time types
/// are encoded and decoded in ScreenTimeEnforcement.swift.
struct RestrictionStore {
  let defaults: UserDefaults

  /// The App Group store. Falls back to the process' own defaults when the
  /// App Group is unavailable (an unsigned build), so nothing crashes.
  static var shared: RestrictionStore {
    RestrictionStore(defaults: AppGroup.userDefaults ?? .standard)
  }

  private enum Key {
    static let configuration = "ft.restrictions.json"
    static let selectionPrefix = "ft.selection."
    static let selectionCreatedPrefix = "ft.selectionCreated."
    static let shieldedRules = "ft.shield.rules"
    static let shieldStores = "ft.shield.stores"
    static let events = "ft.events"
    static let lastEventPrefix = "ft.events.last."
    static let shieldStrings = "ft.shield.strings"
    static let notificationsAuthorized = "ft.notifications.authorized"
    static let reached = "ft.limits.reached"
    static let notices = "ft.limits.notices"
    static let monitorPlans = "ft.monitor.plans"
  }

  // MARK: Configuration

  /// Exactly the JSON Dart last synced (returned by readRestrictionConfiguration).
  var configurationJSON: String? {
    get { defaults.string(forKey: Key.configuration) }
    nonmutating set { defaults.set(newValue, forKey: Key.configuration) }
  }

  var configuration: RestrictionConfiguration {
    RestrictionConfiguration.parse(configurationJSON)
  }

  // MARK: Selections

  func selectionData(id: String) -> Data? {
    defaults.data(forKey: Key.selectionPrefix + id)
  }

  func setSelectionData(_ data: Data, id: String, now: Date = Date()) {
    defaults.set(data, forKey: Key.selectionPrefix + id)
    if defaults.object(forKey: Key.selectionCreatedPrefix + id) == nil {
      defaults.set(now.timeIntervalSince1970, forKey: Key.selectionCreatedPrefix + id)
    }
  }

  func removeSelection(id: String) {
    defaults.removeObject(forKey: Key.selectionPrefix + id)
    defaults.removeObject(forKey: Key.selectionCreatedPrefix + id)
  }

  var selectionIds: [String] {
    defaults.dictionaryRepresentation().keys
      .filter { $0.hasPrefix(Key.selectionPrefix) }
      .map { String($0.dropFirst(Key.selectionPrefix.count)) }
      .sorted()
  }

  /// Drops selections no rule or routine refers to. A selection younger than
  /// `grace` is kept: it may belong to a rule the user is still editing.
  func removeUnreferencedSelections(now: Date = Date(), grace: TimeInterval = 86_400) {
    let config = configuration
    var referenced = Set(config.rules.compactMap { $0.selectionId })
    for routine in config.routines {
      for app in routine.apps where app.appKey.hasPrefix(iosSelectionKeyPrefix) {
        referenced.insert(String(app.appKey.dropFirst(iosSelectionKeyPrefix.count)))
      }
    }
    for preferred in config.preferredLimits {
      referenced.formUnion(preferred.appKeys.compactMap(UsageEvents.selectionId(of:)))
    }
    for id in selectionIds where !referenced.contains(id) {
      let created = defaults.double(forKey: Key.selectionCreatedPrefix + id)
      if now.timeIntervalSince1970 - created >= grace {
        removeSelection(id: id)
      }
    }
  }

  // MARK: Backups

  /// Selection ids are lowercase UUIDs; a backup may only name such keys.
  static func isValidSelectionId(_ id: String) -> Bool {
    !id.isEmpty && id.count <= 64
      && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
  }

  /// The stored selections with these ids, base64-encoded for a backup.
  func exportSelections(ids: [String]) -> [String: String] {
    var result: [String: String] = [:]
    for id in ids where Self.isValidSelectionId(id) {
      if let data = selectionData(id: id) { result[id] = data.base64EncodedString() }
    }
    return result
  }

  /// Restores selections from a backup. Existing selections are kept (one
  /// may belong to a protected rule); entries with a bad id, bad base64 or
  /// data `isValid` rejects are skipped. Returns how many were added.
  @discardableResult
  func importSelections(
    _ encoded: [String: String], now: Date = Date(), isValid: (Data) -> Bool
  ) -> Int {
    var added = 0
    for (id, text) in encoded.sorted(by: { $0.key < $1.key }) {
      guard Self.isValidSelectionId(id), selectionData(id: id) == nil,
        let data = Data(base64Encoded: text), !data.isEmpty, isValid(data)
      else { continue }
      setSelectionData(data, id: id, now: now)
      added += 1
    }
    return added
  }

  // MARK: Language

  /// The app's language (BCP-47) for the extensions' dates and texts; nil
  /// follows the device. Shield and report texts arrive separately from Dart.
  func setAppLanguage(_ tag: String?) {
    var values = shieldStrings.values
    if let tag = tag, !tag.isBlank {
      values["report.locale"] = tag
    } else {
      values.removeValue(forKey: "report.locale")
    }
    shieldStrings = ShieldStrings(values: values)
  }

  // MARK: Shield state

  /// `RestrictionRule.key`s whose shield is applied right now.
  var shieldedRuleKeys: Set<String> {
    get { Set(defaults.stringArray(forKey: Key.shieldedRules) ?? []) }
    nonmutating set { defaults.set(newValue.sorted(), forKey: Key.shieldedRules) }
  }

  /// Named ManagedSettingsStores FocusTrace has written to.
  var shieldStoreNames: Set<String> {
    get { Set(defaults.stringArray(forKey: Key.shieldStores) ?? []) }
    nonmutating set { defaults.set(newValue.sorted(), forKey: Key.shieldStores) }
  }

  // MARK: Usage thresholds (written by the monitor extension)

  /// The day a reached limit belongs to, in the device's calendar.
  static func dayStamp(_ date: Date, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// Records that a block's usage threshold was reached today; it holds until
  /// the day ends, like Android's `usage >= limit` until midnight.
  func markReached(_ key: String, at now: Date = Date(), calendar: Calendar = .current) {
    var map = reachedDays
    map[key] = Self.dayStamp(now, calendar: calendar)
    let today = Self.dayStamp(now, calendar: calendar)
    defaults.set(map.filter { $0.value == today }, forKey: Key.reached)
  }

  func isReached(_ key: String, at now: Date = Date(), calendar: Calendar = .current) -> Bool {
    reachedDays[key] == Self.dayStamp(now, calendar: calendar)
  }

  /// Forgets reached thresholds whose rule or routine changed: a new limit is
  /// measured again (DeviceActivity re-reports past use when it applies).
  func clearReached(where matches: (String) -> Bool) {
    defaults.set(reachedDays.filter { !matches($0.key) }, forKey: Key.reached)
  }

  private var reachedDays: [String: String] {
    defaults.dictionary(forKey: Key.reached) as? [String: String] ?? [:]
  }

  /// True the first time `key` is claimed today. A restarted activity may
  /// report thresholds it already passed; each notice is posted once a day.
  func claimNotice(_ key: String, at now: Date = Date(), calendar: Calendar = .current) -> Bool {
    let today = Self.dayStamp(now, calendar: calendar)
    var map = (defaults.dictionary(forKey: Key.notices) as? [String: String] ?? [:])
      .filter { $0.value == today }
    guard map[key] == nil else { return false }
    map[key] = today
    defaults.set(map, forKey: Key.notices)
    return true
  }

  /// Signatures of the DeviceActivity monitoring FocusTrace registered, by
  /// activity name, so unchanged activities are left running.
  var monitorPlanSignatures: [String: String] {
    get { defaults.dictionary(forKey: Key.monitorPlans) as? [String: String] ?? [:] }
    nonmutating set { defaults.set(newValue, forKey: Key.monitorPlans) }
  }

  /// `ShieldPlanner.usageProxy` with this store's reached state.
  func usageProxy(_ rule: RestrictionRule, at now: Date, calendar: Calendar = .current) -> Int64 {
    ShieldPlanner.usageProxy(rule, reached: isReached(rule.key, at: now, calendar: calendar))
  }

  // MARK: Block events

  /// Records that a shield was shown, at most once a minute per rule, the way
  /// Android records once per switch into a blocked app.
  func recordBlocked(
    appKey: String, appName: String, reason: String, now: Date = Date(),
    minimumInterval: TimeInterval = 60
  ) {
    let lastKey = Key.lastEventPrefix + appKey
    let last = defaults.double(forKey: lastKey)
    if last > 0 && now.timeIntervalSince1970 - last < minimumInterval { return }
    defaults.set(now.timeIntervalSince1970, forKey: lastKey)
    var events = pendingEvents
    events.append([
      "id": "ios-blocked:\(now.epochMilliseconds):\(UUID().uuidString)",
      "appKey": appKey,
      "appName": appName,
      "type": "blocked",
      "reason": reason,
      "occurredAtMs": NSNumber(value: now.epochMilliseconds),
    ])
    // Bounded so a device that never opens the app cannot grow it forever.
    defaults.set(Array(events.suffix(500)), forKey: Key.events)
  }

  var pendingEvents: [[String: Any]] {
    (defaults.array(forKey: Key.events) as? [[String: Any]]) ?? []
  }

  /// Returns and forgets the recorded events.
  func takeEvents() -> [[String: Any]] {
    let events = pendingEvents
    defaults.removeObject(forKey: Key.events)
    return events
  }

  // MARK: Strings and flags written by the app

  var shieldStrings: ShieldStrings {
    get { ShieldStrings(values: defaults.dictionary(forKey: Key.shieldStrings) as? [String: String] ?? [:]) }
    nonmutating set { defaults.set(newValue.values, forKey: Key.shieldStrings) }
  }

  var notificationsAuthorized: Bool {
    get { defaults.bool(forKey: Key.notificationsAuthorized) }
    nonmutating set { defaults.set(newValue, forKey: Key.notificationsAuthorized) }
  }
}

/// Validates and stores a configuration from Dart, like Android's
/// `MainActivity.syncRestrictions`: every rule that is removed or changed must
/// pass the change guard, otherwise nothing is stored.
enum RestrictionSync {
  struct Locked: Error, CustomStringConvertible {
    let rule: RestrictionRule
    let status: String
    var description: String {
      "Restriction change requires confirmation, a completed cooldown, or the end of the block."
    }
  }

  /// Returns the rules that were removed or changed.
  @discardableResult
  static func apply(
    json: String, store: RestrictionStore, now: Date = Date(), calendar: Calendar = .current
  ) throws -> [RestrictionRule] {
    let previousConfiguration = store.configuration
    let nextConfiguration = RestrictionConfiguration.parse(json)
    let previous = previousConfiguration.rules
    let next = nextConfiguration.rules
    let changed = previous.filter { !next.contains($0) }
    let guardian = RestrictionChangeGuard(defaults: store.defaults)
    for rule in changed {
      // iOS has no usage numbers: a daily limit counts as at its limit once
      // the monitor recorded it reached today, else as unused.
      let usage = store.usageProxy(rule, at: now, calendar: calendar)
      let status = guardian.check(rule, now: now, usageSeconds: usage, calendar: calendar)
      if status != "allowed" { throw Locked(rule: rule, status: status) }
    }
    store.configurationJSON = json
    changed.forEach(guardian.clear)
    // A limit or routine whose thresholds changed is measured again: its
    // activity restarts and DeviceActivity reports past use against the new
    // thresholds. Routines are not guarded, as on Android.
    var remeasured = Set<String>()
    for rule in previous where rule.type == .dailyLimit {
      guard let id = rule.selectionId,
        let updated = next.first(where: { $0.key == rule.key }),
        UsageEvents.limitPlan(updated, id: id)?.signature != UsageEvents.limitPlan(rule, id: id)?.signature
      else { continue }
      remeasured.insert(rule.key)
    }
    var remeasuredRoutines = Set<String>()
    for routine in previousConfiguration.routines {
      guard let updated = nextConfiguration.routines.first(where: { $0.id == routine.id }),
        UsageEvents.routinePlan(updated)?.signature != UsageEvents.routinePlan(routine)?.signature
      else { continue }
      remeasuredRoutines.insert(routine.id)
    }
    store.clearReached { key in
      remeasured.contains(key)
        || remeasuredRoutines.contains { id in
          key == UsageEvents.routineKey(id) || key.hasPrefix("routineApp:\(id):")
        }
    }
    return changed
  }

  /// Dart's `requestRestrictionChange`: "allowed" when no such rule exists.
  static func requestChange(
    appKey: String, type: String, store: RestrictionStore, now: Date = Date(),
    calendar: Calendar = .current
  ) -> String {
    guard
      let rule = store.configuration.rules.first(where: {
        $0.appKey == appKey && $0.type.rawValue == type
      })
    else { return "allowed" }
    return RestrictionChangeGuard(defaults: store.defaults)
      .check(
        rule, now: now, usageSeconds: store.usageProxy(rule, at: now, calendar: calendar),
        request: true, calendar: calendar)
  }
}
