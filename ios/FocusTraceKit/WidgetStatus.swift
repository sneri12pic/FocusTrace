import Foundation

// Pure-Foundation model of the FocusTraceWidget home screen widget (unit
// tested in tool/ios/kit_tests). WidgetKit cannot read Screen Time usage, so
// the widget shows restriction status from the App Group instead of Android's
// usage totals: what blocks now, what blocks next, and how many daily limits
// were reached today.

/// What the widget draws at one moment.
struct WidgetSnapshot: Equatable {
  struct Upcoming: Equatable {
    var name: String
    var start: Date
  }

  /// Names of the rules and routines that block now, soonest end first.
  var activeNames: [String]
  /// When the soonest active block ends, if it has a known end.
  var activeUntil: Date?
  /// The next schedule that is not active now, within a week.
  var next: Upcoming?
  /// Daily limits, routine allowances and member caps reached today.
  var limitsReached: Int
  /// False when FocusTrace has no iOS restriction at all yet.
  var hasRestrictions: Bool
}

enum WidgetStatus {
  /// The status at `now`. `isReached` says whether the monitor recorded a
  /// block's usage threshold today (RestrictionStore.isReached).
  static func snapshot(
    configuration: RestrictionConfiguration, at now: Date,
    isReached: (String) -> Bool, calendar: Calendar = .current
  ) -> WidgetSnapshot {
    let blocks = ShieldPlanner.blocks(for: configuration)
    var active: [(name: String, until: Date?)] = []
    var limitsReached = 0
    for block in blocks {
      let reached = isReached(block.key)
      switch block.kind {
      case .rule(let rule) where rule.type == .dailyLimit:
        if reached { limitsReached += 1 }
      case .routineShared, .routineApp:
        if reached { limitsReached += 1 }
      default:
        break
      }
      guard ShieldPlanner.isActive(block, at: now, isReached: isReached, calendar: calendar)
      else { continue }
      active.append((block.appName, until(block, at: now, calendar: calendar)))
    }
    active.sort { lhs, rhs in
      switch (lhs.until, rhs.until) {
      case let (l?, r?): return l < r
      case (.some, .none): return true
      default: return false
      }
    }
    var names: [String] = []
    for entry in active where !names.contains(entry.name) { names.append(entry.name) }
    return WidgetSnapshot(
      activeNames: names,
      activeUntil: active.compactMap(\.until).min(),
      next: nextSchedule(configuration: configuration, after: now, calendar: calendar),
      limitsReached: limitsReached,
      hasRestrictions: !blocks.isEmpty)
  }

  /// When an active block ends: a rule's own end; reached allowances at the
  /// start of tomorrow.
  private static func until(_ block: ShieldBlock, at now: Date, calendar: Calendar) -> Date? {
    switch block.kind {
    case .rule(let rule):
      return rule.blockedUntil(
        at: now, usageSecondsToday: ShieldPlanner.usageProxy(rule, reached: true),
        calendar: calendar)
    case .routineShared, .routineApp:
      return calendar.startOfTomorrow(after: now)
    }
  }

  /// The earliest start of a picked-apps schedule after `now`, within a
  /// week, on one of its weekdays; schedules blocking now are left out.
  static func nextSchedule(
    configuration: RestrictionConfiguration, after now: Date, calendar: Calendar = .current
  ) -> WidgetSnapshot.Upcoming? {
    var best: WidgetSnapshot.Upcoming?
    for rule in configuration.rules
    where rule.type == .schedule && rule.selectionId != nil {
      guard let start = rule.startMinute, let end = rule.endMinute, start != end,
        !rule.isBlocked(at: now, calendar: calendar)
      else { continue }
      for offset in 0...7 {
        guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
        let candidate = calendar.date(at: start, onDayOf: day)
        guard candidate > now, rule.weekdays.contains(calendar.isoWeekday(of: candidate)) else {
          continue
        }
        if best == nil || candidate < best!.start {
          best = WidgetSnapshot.Upcoming(name: rule.appName, start: candidate)
        }
        break
      }
    }
    return best
  }

  /// Moments within `horizon` at which the status can change without the
  /// app or the monitor running: block-now ends, schedule starts and ends,
  /// and midnight (reached limits lift). Sorted, starting with `now`.
  static func timeline(
    configuration: RestrictionConfiguration, from now: Date,
    horizon: TimeInterval = 24 * 3600, calendar: Calendar = .current
  ) -> [Date] {
    let limit = now.addingTimeInterval(horizon)
    var dates: Set<Date> = [now, calendar.startOfTomorrow(after: now)]
    for rule in configuration.rules where rule.selectionId != nil {
      switch rule.type {
      case .blockNow:
        if let until = rule.untilMs.map(Date.init(epochMilliseconds:)) { dates.insert(until) }
      case .schedule:
        for minute in [rule.startMinute, rule.endMinute].compactMap({ $0 }) {
          for offset in 0...1 {
            if let day = calendar.date(byAdding: .day, value: offset, to: now) {
              dates.insert(calendar.date(at: minute, onDayOf: day))
            }
          }
        }
      case .dailyLimit:
        break
      }
    }
    return dates.filter { $0 >= now && $0 <= limit }.sorted()
  }
}

/// The widget's texts: sent by Flutter with the shield strings as
/// `widget.<name>`, English otherwise.
struct WidgetStrings: Equatable {
  static let prefix = "widget."

  var values: [String: String]

  static let defaults: [String: String] = [
    "galleryName": "Restriction status",
    "galleryDescription": "What FocusTrace is blocking now and what's next.",
    "blockingNow": "Blocking now",
    "nothingBlocked": "Nothing blocked right now",
    "until": "until {time}",
    "nextBlock": "Next block",
    "noUpcoming": "No upcoming blocks",
    "limitsReached": "Limits reached today",
    "noRestrictions": "Open FocusTrace to choose apps to block",
  ]

  init(sharedValues: [String: String]) {
    var values: [String: String] = [:]
    for (key, value) in sharedValues where key.hasPrefix(Self.prefix) {
      values[String(key.dropFirst(Self.prefix.count))] = value
    }
    self.values = values
  }

  func text(_ key: String) -> String {
    if let value = values[key], !value.isBlank { return value }
    return Self.defaults[key] ?? ""
  }

  func until(_ time: String) -> String {
    text("until").replacingOccurrences(of: "{time}", with: time)
  }
}

extension RestrictionStore {
  var widgetStrings: WidgetStrings { WidgetStrings(sharedValues: shieldStrings.values) }

  func widgetSnapshot(at now: Date = Date(), calendar: Calendar = .current) -> WidgetSnapshot {
    WidgetStatus.snapshot(
      configuration: configuration, at: now,
      isReached: { isReached($0, at: now, calendar: calendar) }, calendar: calendar)
  }
}
