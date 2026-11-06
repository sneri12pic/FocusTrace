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
  ]

  func text(_ key: String) -> String {
    if let value = values[key], !value.isBlank { return value }
    return Self.defaults[key] ?? ""
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
