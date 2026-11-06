import Foundation

/// One thing that can shield picked apps, with its own named
/// ManagedSettingsStore. Several blocks may cover the same app; iOS shields it
/// while any of them does, as Android blocks while any `BlockReason` remains.
struct ShieldBlock: Equatable {
  enum Kind: Equatable {
    case rule(RestrictionRule)
    /// The routine's included apps together reached its shared allowance.
    case routineShared(RoutineLimit)
    /// One member reached its own cap inside the routine.
    case routineApp(RoutineLimit, RoutineLimit.Member)
  }

  var kind: Kind
  /// Shield-state key: `RestrictionRule.key`, `routine:<id>` or
  /// `routineApp:<id>:<selection>`. Reached limits are recorded under it.
  var key: String
  var storeName: String
  var selectionIds: [String]

  /// What Android records as the event reason (`BlockReason.eventName`).
  var eventReason: String {
    switch kind {
    case .rule(let rule): return rule.type.rawValue
    case .routineShared(let routine): return "routineLimit:\(routine.id)"
    case .routineApp(let routine, _): return "routineAppLimit:\(routine.id)"
    }
  }

  /// The name the block's apps go by in FocusTrace.
  var appName: String {
    switch kind {
    case .rule(let rule): return rule.appName
    case .routineShared(let routine): return routine.name
    case .routineApp(_, let member): return member.appName
    }
  }

  var appKey: String {
    switch kind {
    case .rule(let rule): return rule.appKey
    case .routineShared(let routine): return "routine:\(routine.id)"
    case .routineApp(_, let member): return member.appKey
    }
  }

  /// Hard rules cannot be relaxed while they block; routines have no
  /// difficulty (they are switched off in FocusTrace, as on Android).
  var isHard: Bool {
    if case .rule(let rule) = kind { return rule.difficulty == "hard" }
    return false
  }
}

/// Which blocks exist and which hold now. Pure Foundation, so the decision is
/// unit-tested; ShieldController applies it to ManagedSettingsStores.
enum ShieldPlanner {
  /// Every block the configuration can raise on iOS (only `ios-sel:` apps can
  /// be shielded).
  static func blocks(for configuration: RestrictionConfiguration) -> [ShieldBlock] {
    var blocks: [ShieldBlock] = []
    for rule in configuration.rules {
      guard let id = rule.selectionId else { continue }
      blocks.append(
        ShieldBlock(
          kind: .rule(rule), key: rule.key, storeName: "ft.\(rule.type.rawValue).\(id)",
          selectionIds: [id]))
    }
    for routine in configuration.routines {
      let included = UsageEvents.unique(
        routine.includedApps.compactMap { UsageEvents.selectionId(of: $0.appKey) })
      if !included.isEmpty {
        blocks.append(
          ShieldBlock(
            kind: .routineShared(routine), key: UsageEvents.routineKey(routine.id),
            storeName: "ft.routine.\(routine.id)", selectionIds: included))
      }
      for member in routine.cappedApps {
        guard let id = UsageEvents.selectionId(of: member.appKey) else { continue }
        blocks.append(
          ShieldBlock(
            kind: .routineApp(routine, member),
            key: UsageEvents.routineAppKey(routine.id, selectionId: id),
            storeName: "ft.routineApp.\(routine.id).\(id)", selectionIds: [id]))
      }
    }
    return blocks
  }

  /// Whether `block` shields at `now`. `isReached` says whether the monitor
  /// recorded the block's usage threshold today.
  static func isActive(
    _ block: ShieldBlock, at now: Date, isReached: (String) -> Bool,
    calendar: Calendar = .current
  ) -> Bool {
    switch block.kind {
    case .rule(let rule):
      return rule.isBlocked(
        at: now, usageSecondsToday: usageProxy(rule, reached: isReached(rule.key)),
        calendar: calendar)
    case .routineShared, .routineApp:
      return isReached(block.key)
    }
  }

  /// Today's usage as far as the change guard and the time logic need it: iOS
  /// only knows whether the limit was reached, so it is the limit or nothing.
  static func usageProxy(_ rule: RestrictionRule, reached: Bool) -> Int64 {
    guard rule.type == .dailyLimit, reached, let limit = rule.limitMinutes else { return 0 }
    return Int64(limit) * 60
  }
}
