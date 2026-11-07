import Foundation

/// Usage thresholds on iOS: daily limits, routine allowances and preferred
/// usage time, as DeviceActivityEvents of one daily activity each.
///
/// iOS never gives FocusTrace usage numbers; it only wakes the monitor
/// extension when the picked apps have been used for a set time since the
/// interval started (00:00). So every moment Android's blocker reacts to on
/// its one-second tick is registered up front as a threshold:
///
/// | Activity | Event | Minutes | Effect |
/// | --- | --- | --- | --- |
/// | `ft.limit.<selection>` | `warning` | limit - 5 | notification, as Android's warning |
/// | | `reached` | limit | shield the rule's apps for the day |
/// | `ft.routine.<id>` | `warning` | limit - 5 | notification |
/// | | `reached` | limit (included apps together) | shield every included app |
/// | | `cap.<selection>` | member cap | shield that member |
/// | `ft.preferred.<hash>` | `amber` | limit - 5 | "5 min left" |
/// | | `red` | limit - 1 | "1 min left" |
/// | | `limit` | limit | "You've reached your time" |
/// | | `over.<n>` | limit + n, n = 10, 20, ... | "n min over" |
///
/// For a limit of five minutes or less the warning (and the amber nudge)
/// comes after the first minute. Thresholds past 23:59 are left out. Only
/// app keys of picked selections (`ios-sel:`) can be counted.
///
/// Pure Foundation (unit-tested in tool/ios/kit_tests).
enum UsageEvents {
  static let limitPrefix = ScheduleMapper.prefix + "limit."
  static let routinePrefix = ScheduleMapper.prefix + "routine."
  static let preferredPrefix = ScheduleMapper.prefix + "preferred."

  /// Android warns when five minutes or less are left (BlockerService).
  static let warningLeadMinutes = 5
  /// Preferred usage nudges: amber from 5 minutes left, red from 1 minute
  /// left, then every 10 minutes over (Android `RestrictionRules.NUDGE_*`).
  static let nudgeAmberMinutes = 5
  static let nudgeRedMinutes = 1
  static let nudgeRepeatMinutes = 10
  /// Over-limit nudges registered ahead; iOS cannot repeat an event itself.
  static let nudgeMaxRepeats = 12

  static let warning = "warning"
  static let reached = "reached"
  static let capPrefix = "cap."
  static let amber = "amber"
  static let red = "red"
  static let limit = "limit"
  static let overPrefix = "over."

  // MARK: Plans

  static func limitPlan(_ rule: RestrictionRule, id: String) -> MonitorPlan? {
    guard rule.type == .dailyLimit, let minutes = rule.limitMinutes, minutes > 0 else { return nil }
    var events: [ThresholdPlan] = []
    if let at = warningMinute(limit: minutes) {
      events.append(ThresholdPlan(name: warning, minutes: at, selectionIds: [id]))
    }
    events.append(ThresholdPlan(name: reached, minutes: minutes, selectionIds: [id]))
    return dailyPlan(name: limitPrefix + id, key: rule.key, events: events)
  }

  static func routinePlan(_ routine: RoutineLimit) -> MonitorPlan? {
    let included = unique(routine.includedApps.compactMap { selectionId(of: $0.appKey) })
    var events: [ThresholdPlan] = []
    if !included.isEmpty {
      if let at = warningMinute(limit: routine.limitMinutes) {
        events.append(ThresholdPlan(name: warning, minutes: at, selectionIds: included))
      }
      events.append(
        ThresholdPlan(name: reached, minutes: routine.limitMinutes, selectionIds: included))
    }
    for member in routine.cappedApps {
      guard let id = selectionId(of: member.appKey), let cap = member.limitMinutes else { continue }
      events.append(ThresholdPlan(name: capPrefix + id, minutes: cap, selectionIds: [id]))
    }
    return dailyPlan(name: routinePrefix + routine.id, key: routineKey(routine.id), events: events)
  }

  static func preferredPlan(_ preferred: PreferredLimit) -> MonitorPlan? {
    let ids = unique(preferred.appKeys.compactMap(selectionId(of:)))
    guard !ids.isEmpty else { return nil }
    let limit = preferred.limitMinutes
    var events: [ThresholdPlan] = []
    let redAt = limit - nudgeRedMinutes
    if let amberAt = warningMinute(limit: limit), amberAt < redAt {
      events.append(ThresholdPlan(name: amber, minutes: amberAt, selectionIds: ids))
    }
    if redAt >= 1 {
      events.append(ThresholdPlan(name: red, minutes: redAt, selectionIds: ids))
    }
    events.append(ThresholdPlan(name: self.limit, minutes: limit, selectionIds: ids))
    for step in 1...nudgeMaxRepeats {
      let over = step * nudgeRepeatMinutes
      events.append(
        ThresholdPlan(name: overPrefix + String(over), minutes: limit + over, selectionIds: ids))
    }
    let key = preferredKey(ids: ids, limit: limit)
    return dailyPlan(name: preferredPrefix + key, key: "preferred:" + key, events: events)
  }

  /// When the warning (or amber nudge) fires: five minutes before the limit,
  /// or after the first minute of a limit of five minutes or less.
  static func warningMinute(limit: Int) -> Int? {
    if limit > warningLeadMinutes { return limit - warningLeadMinutes }
    return limit > 1 ? 1 : nil
  }

  private static func dailyPlan(name: String, key: String, events: [ThresholdPlan]) -> MonitorPlan? {
    let reachable = events.filter { $0.minutes >= 1 && $0.minutes <= ScheduleMapper.lastMinute }
    guard !reachable.isEmpty else { return nil }
    return MonitorPlan(
      name: name,
      start: DateComponents(hour: 0, minute: 0),
      end: DateComponents(hour: 23, minute: 59),
      repeats: true,
      warning: nil,
      ruleKey: key,
      events: reachable
    )
  }

  // MARK: Reached limits

  static func routineKey(_ id: String) -> String { "routine:" + id }

  static func routineAppKey(_ id: String, selectionId: String) -> String {
    "routineApp:\(id):\(selectionId)"
  }

  static func limitKey(selectionId: String) -> String {
    // RestrictionRule.key of the daily limit on that selection.
    "\(iosSelectionKeyPrefix)\(selectionId)#\(RestrictionRuleType.dailyLimit.rawValue)"
  }

  /// The block a reached event starts, as a `ShieldPlanner` block key, or nil
  /// for warnings and nudges.
  static func reachedKey(activity: String, event: String) -> String? {
    if activity.hasPrefix(limitPrefix), event == reached {
      return limitKey(selectionId: String(activity.dropFirst(limitPrefix.count)))
    }
    if activity.hasPrefix(routinePrefix) {
      let id = String(activity.dropFirst(routinePrefix.count))
      if event == reached { return routineKey(id) }
      if event.hasPrefix(capPrefix) {
        return routineAppKey(id, selectionId: String(event.dropFirst(capPrefix.count)))
      }
    }
    return nil
  }

  // MARK: Notifications

  /// The identifier of an activity's limit warning; the reached event
  /// removes a delivered warning, which no longer applies.
  static func warningIdentifier(activity: String) -> String {
    "focustrace.warning." + activity
  }

  /// The notification an event posts, or nil. One identifier per activity,
  /// so a later notice replaces an earlier one instead of piling up.
  ///
  /// `isReached` tells whether a block key (`reachedKey`) was reached today:
  /// a limit already reached (lowered below today's use, so both events fire
  /// at once) gets no warning.
  static func notice(
    activity: String, event: String, configuration: RestrictionConfiguration,
    strings: ShieldStrings, isReached: (String) -> Bool = { _ in false }
  ) -> UsageNotice? {
    if activity.hasPrefix(limitPrefix), event == warning {
      let id = String(activity.dropFirst(limitPrefix.count))
      guard
        let rule = configuration.rules.first(where: {
          $0.type == .dailyLimit && $0.selectionId == id
        }), let limit = rule.limitMinutes, let at = warningMinute(limit: limit),
        !isReached(limitKey(selectionId: id))
      else { return nil }
      return UsageNotice(
        identifier: warningIdentifier(activity: activity),
        title: strings.text("limitWarningTitle").replacingOccurrences(of: "{name}", with: rule.appName),
        body: strings.counted("limitWarningBody", limit - at),
        claimKey: claimKey(activity: activity, event: event, limitMinutes: limit))
    }
    if activity.hasPrefix(routinePrefix), event == warning {
      let id = String(activity.dropFirst(routinePrefix.count))
      guard let routine = configuration.routines.first(where: { $0.id == id }),
        let at = warningMinute(limit: routine.limitMinutes),
        !isReached(routineKey(id))
      else { return nil }
      return UsageNotice(
        identifier: warningIdentifier(activity: activity),
        title: strings.text("routineWarningTitle").replacingOccurrences(
          of: "{name}", with: routine.name),
        body: strings.counted("limitWarningBody", routine.limitMinutes - at),
        claimKey: claimKey(activity: activity, event: event, limitMinutes: routine.limitMinutes))
    }
    if activity.hasPrefix(preferredPrefix) {
      let key = String(activity.dropFirst(preferredPrefix.count))
      guard
        let preferred = configuration.preferredLimits.first(where: {
          preferredKey(ids: unique($0.appKeys.compactMap(selectionId(of:))), limit: $0.limitMinutes)
            == key
        })
      else { return nil }
      let body: String
      switch event {
      case amber:
        guard let at = warningMinute(limit: preferred.limitMinutes) else { return nil }
        body = strings.counted("nudgeLeft", preferred.limitMinutes - at)
      case red: body = strings.counted("nudgeLeft", nudgeRedMinutes)
      case limit: body = strings.text("nudgeReached")
      default:
        guard event.hasPrefix(overPrefix), let over = Int(event.dropFirst(overPrefix.count)) else {
          return nil
        }
        body = strings.counted("nudgeOver", over)
      }
      // Rules name the picked apps; a preferred limit has no name of its own.
      let names = unique(
        preferred.appKeys.compactMap { key in
          configuration.rules.first(where: { $0.appKey == key })?.appName
        })
      let title = strings.text("nudgeTitle")
      return UsageNotice(
        identifier: "focustrace.nudge." + activity,
        title: names.isEmpty ? title : "\(title) · \(names.joined(separator: ", "))",
        body: body,
        claimKey: claimKey(activity: activity, event: event, limitMinutes: preferred.limitMinutes))
    }
    return nil
  }

  /// The once-a-day claim of a notice (`RestrictionStore.claimNotice`). It
  /// holds the limit, as Android's warning key does, so a limit raised later
  /// the same day warns again before its new end.
  static func claimKey(activity: String, event: String, limitMinutes: Int) -> String {
    "\(activity)#\(event)#\(limitMinutes)"
  }

  // MARK: Helpers

  static func selectionId(of appKey: String) -> String? {
    appKey.hasPrefix(iosSelectionKeyPrefix)
      ? String(appKey.dropFirst(iosSelectionKeyPrefix.count)) : nil
  }

  static func unique(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
  }

  /// Stable across launches (Swift's `hashValue` is not): FNV-1a, 64 bit.
  static func stableHash(_ text: String) -> String {
    stableHash(bytes: Array(text.utf8))
  }

  static func stableHash(bytes: [UInt8]) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in bytes {
      hash ^= UInt64(byte)
      hash = hash &* 0x0000_0100_0000_01b3
    }
    return String(hash, radix: 16)
  }

  private static func preferredKey(ids: [String], limit: Int) -> String {
    stableHash(ids.sorted().joined(separator: ",") + "@" + String(limit))
  }
}

/// A local notification the monitor extension posts.
struct UsageNotice: Equatable {
  var identifier: String
  var title: String
  var body: String
  /// Posted at most once a day per claim key.
  var claimKey: String
}
