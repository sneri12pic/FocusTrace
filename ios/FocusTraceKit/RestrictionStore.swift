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
    for id in selectionIds where !referenced.contains(id) {
      let created = defaults.double(forKey: Key.selectionCreatedPrefix + id)
      if now.timeIntervalSince1970 - created >= grace {
        removeSelection(id: id)
      }
    }
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
    let previous = store.configuration.rules
    let next = RestrictionConfiguration.parse(json).rules
    let changed = previous.filter { !next.contains($0) }
    let guardian = RestrictionChangeGuard(defaults: store.defaults)
    for rule in changed {
      // Daily limits need usage numbers iOS does not give the app (phase 3);
      // until then a limit never counts as blocking.
      let status = guardian.check(rule, now: now, calendar: calendar)
      if status != "allowed" { throw Locked(rule: rule, status: status) }
    }
    store.configurationJSON = json
    changed.forEach(guardian.clear)
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
      .check(rule, now: now, request: true, calendar: calendar)
  }
}
