import Foundation

/// One DeviceActivity monitoring request, in plain Foundation types so the
/// mapping is unit-testable without the Screen Time frameworks.
struct MonitorPlan: Equatable {
  /// DeviceActivityName raw value; always starts with `ScheduleMapper.prefix`.
  var name: String
  var start: DateComponents
  var end: DateComponents
  var repeats: Bool
  /// DeviceActivitySchedule.warningTime: `intervalWillEndWarning` fires this
  /// long before `end`, giving a third wake-up inside short intervals.
  var warning: DateComponents?
  /// The `RestrictionRule.key` this plan wakes the monitor for.
  var ruleKey: String
}

/// Turns restriction rules into DeviceActivity monitoring.
///
/// The monitor extension does not trust the activity that woke it: every
/// callback re-evaluates all rules (`RestrictionRule.isBlocked`) and applies or
/// clears each rule's shield. Activities only make sure it is woken at every
/// moment a shield must go up or come down, also with the app killed:
/// - blockNow: one non-repeating interval from now to `untilMs`.
/// - schedule: one daily interval `start-end`; a window over midnight is split
///   into `start-23:59` and `00:00-end`. Weekdays are not encoded in the
///   activity (that would cost one activity per day); the monitor checks them,
///   so a wake-up on an unselected day changes nothing.
/// - dailyLimit and routines: not monitored yet (phase 3).
///
/// DeviceActivity rejects intervals under 15 minutes, so a short piece is
/// widened and the moment that would be lost is covered by `warningTime`.
/// At most `maxActivities` are monitored (iOS allows about 20); block-now
/// rules come first, soonest end first, then schedules in rule order.
enum ScheduleMapper {
  static let prefix = "ft."
  static let maxActivities = 20
  static let minimumMinutes = 15
  private static let lastMinute = 23 * 60 + 59

  static func plans(
    for configuration: RestrictionConfiguration, now: Date, calendar: Calendar = .current
  ) -> [MonitorPlan] {
    var blockNow: [(Int64, MonitorPlan)] = []
    var schedules: [MonitorPlan] = []
    for rule in configuration.rules {
      guard let id = rule.selectionId else { continue }
      switch rule.type {
      case .blockNow:
        guard let until = rule.untilMs, until > now.epochMilliseconds else { continue }
        blockNow.append((until, blockNowPlan(rule, id: id, until: until, now: now, calendar: calendar)))
      case .schedule:
        schedules.append(contentsOf: schedulePlans(rule, id: id))
      case .dailyLimit:
        continue
      }
    }
    let ordered = blockNow.sorted { $0.0 < $1.0 }.map { $0.1 } + schedules
    return Array(ordered.prefix(maxActivities))
  }

  private static func blockNowPlan(
    _ rule: RestrictionRule, id: String, until: Int64, now: Date, calendar: Calendar
  ) -> MonitorPlan {
    let untilDate = Date(epochMilliseconds: until)
    let minimumEnd = now.addingTimeInterval(TimeInterval(minimumMinutes * 60))
    let end = max(untilDate, minimumEnd)
    let units: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    var warning: DateComponents?
    if end > untilDate {
      let seconds = Int(end.timeIntervalSince(untilDate).rounded())
      warning = DateComponents(minute: seconds / 60, second: seconds % 60)
    }
    return MonitorPlan(
      name: "\(prefix)blockNow.\(id)",
      start: calendar.dateComponents(units, from: now),
      end: calendar.dateComponents(units, from: end),
      repeats: false,
      warning: warning,
      ruleKey: rule.key
    )
  }

  private static func schedulePlans(_ rule: RestrictionRule, id: String) -> [MonitorPlan] {
    guard let start = rule.startMinute, let end = rule.endMinute, start != end,
      !rule.weekdays.isEmpty
    else { return [] }
    let pieces: [(suffix: String, lo: Int, hi: Int, on: Bool, off: Bool)] =
      end > start
      ? [("day", start, end, true, true)]
      : [("evening", start, lastMinute, true, false), ("morning", 0, end, false, true)]
    return pieces.map { piece in
      let fitted = fit(lo: piece.lo, hi: piece.hi, needsOn: piece.on, needsOff: piece.off)
      return MonitorPlan(
        name: "\(prefix)schedule.\(id).\(piece.suffix)",
        start: DateComponents(hour: fitted.start / 60, minute: fitted.start % 60),
        end: DateComponents(hour: fitted.end / 60, minute: fitted.end % 60),
        repeats: true,
        warning: fitted.warning.map { DateComponents(minute: $0) },
        ruleKey: rule.key
      )
    }
  }

  /// A daily interval of at least `minimumMinutes` within 00:00-23:59 whose
  /// start, end or warning lands on `lo` (when `needsOn`) and `hi` (when
  /// `needsOff`). Minutes of the day; `warning` is minutes before the end.
  static func fit(lo: Int, hi: Int, needsOn: Bool, needsOff: Bool)
    -> (start: Int, end: Int, warning: Int?)
  {
    if hi - lo >= minimumMinutes { return (lo, hi, nil) }
    let needed = [needsOn ? lo : nil, needsOff ? hi : nil].compactMap { $0 }
    for start in [lo, hi - minimumMinutes, 0, lastMinute - minimumMinutes] {
      let end = start + minimumMinutes
      guard start >= 0, end <= lastMinute else { continue }
      let uncovered = needed.filter { $0 != start && $0 != end }
      if uncovered.isEmpty { return (start, end, nil) }
      if uncovered.count == 1, let moment = uncovered.first, moment > start, moment < end {
        return (start, end, end - moment)
      }
    }
    return (lo, max(hi, lo + minimumMinutes), nil)
  }
}
