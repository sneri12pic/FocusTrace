import Foundation

/// Texts of the block screen. Flutter sends them from its ARB files (so the
/// shield follows the in-app language, like Android's FocusTraceLocale);
/// English is the fallback until it has. `{time}` and `{name}` are filled in
/// here.
struct ShieldStrings: Equatable {
  var values: [String: String]

  static let defaults: [String: String] = [
    "blockNowUntil": "Temporary block until {time}",
    "scheduleUntil": "Blocked by schedule until {time}",
    "dailyLimit": "Daily app limit reached",
    "restricted": "This app is restricted right now.",
    "leave": "Leave",
    "unblockInApp": "Unblock in FocusTrace",
    "notificationBody": "Open FocusTrace to change {name}.",
    "routineShared": "{name}: shared allowance reached",
    "routineApp": "{name}: app limit reached",
    "limitWarningTitle": "{name} limit almost reached",
    "routineWarningTitle": "{name} routine limit almost reached",
    "nudgeTitle": "Preferred usage time",
    "nudgeReached": "You've reached your time",
  ]

  /// Texts with a number, sent by Flutter already pluralized per count as
  /// "<base>.<count>" (ICU plural rules stay in Dart). English otherwise.
  static func englishCounted(_ base: String, _ count: Int) -> String {
    switch base {
    case "limitWarningBody":
      return "Blocking starts in about \(count) minute\(count == 1 ? "" : "s")."
    case "nudgeLeft": return "\(count) min left"
    case "nudgeOver": return "\(count) min over"
    default: return ""
    }
  }

  func text(_ key: String) -> String {
    if let value = values[key], !value.isBlank { return value }
    return Self.defaults[key] ?? ""
  }

  func counted(_ base: String, _ count: Int) -> String {
    if let value = values["\(base).\(count)"], !value.isBlank { return value }
    return Self.englishCounted(base, count)
  }

  /// One line per active block: rules as `reason(for:)`, routines as Android's
  /// "Study: shared allowance reached" (plus the app for a member's cap).
  func reason(for block: ShieldBlock, until: Date?, timeFormatter: DateFormatter) -> String {
    switch block.kind {
    case .rule(let rule):
      return reason(for: rule, until: until, timeFormatter: timeFormatter)
    case .routineShared(let routine):
      return text("routineShared").replacingOccurrences(of: "{name}", with: routine.name)
    case .routineApp(let routine, let member):
      let line = text("routineApp").replacingOccurrences(of: "{name}", with: routine.name)
      return "\(line) · \(member.appName)"
    }
  }

  /// One line per active rule, as Android lists every block reason:
  /// "Temporary block until 15:00 · Social".
  func reason(for rule: RestrictionRule, until: Date?, timeFormatter: DateFormatter) -> String {
    let time = until.map { timeFormatter.string(from: $0) } ?? ""
    let reason: String
    switch rule.type {
    case .blockNow: reason = text("blockNowUntil").replacingOccurrences(of: "{time}", with: time)
    case .schedule: reason = text("scheduleUntil").replacingOccurrences(of: "{time}", with: time)
    case .dailyLimit: reason = text("dailyLimit")
    }
    return "\(reason) · \(rule.appName)"
  }

  func notificationBody(ruleName: String) -> String {
    text("notificationBody").replacingOccurrences(of: "{name}", with: ruleName)
  }

  static func timeFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }
}
