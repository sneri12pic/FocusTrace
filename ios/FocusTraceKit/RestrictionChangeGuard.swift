import Foundation

/// Durable, occurrence-scoped permission to change an actively blocking rule.
///
/// Swift port of android/.../RestrictionChangeGuard.kt with the same result
/// strings, so Dart's `requestRestrictionChange` behaves identically:
/// - "allowed": the rule is not blocking, is Easy (Flutter confirms), or a
///   Moderate cooldown requested for this exact occurrence has elapsed.
/// - "cooldown": Moderate; a five-minute wait was (or already is) running.
/// - "hard": Hard; locked until the current block ends.
///
/// Pure Foundation (unit-tested in tool/ios/kit_tests).
struct RestrictionChangeGuard {
  static let cooldownMilliseconds: Int64 = 300_000

  let defaults: UserDefaults

  func check(
    _ rule: RestrictionRule,
    now: Date,
    usageSeconds: Int64 = 0,
    request: Bool = false,
    calendar: Calendar = .current
  ) -> String {
    guard let end = rule.blockedUntil(at: now, usageSecondsToday: usageSeconds, calendar: calendar)
    else { return "allowed" }
    if rule.difficulty == "hard" { return "hard" }
    let key = Self.key(for: rule)
    let signature = "\(rule.signature):\(end.epochMilliseconds)"
    let matches = defaults.string(forKey: "\(key):rule") == signature
    let nowMs = now.epochMilliseconds
    if rule.difficulty == "moderate" {
      if !matches && request {
        defaults.set(signature, forKey: "\(key):rule")
        defaults.set(
          NSNumber(value: nowMs + Self.cooldownMilliseconds), forKey: "\(key):ready")
      }
      let ready = (defaults.object(forKey: "\(key):ready") as? NSNumber)?.int64Value ?? .max
      return (matches || request) && nowMs >= ready ? "allowed" : "cooldown"
    }
    // Easy changes are confirmed in Flutter. They require no native timer.
    return "allowed"
  }

  func clear(_ rule: RestrictionRule) {
    let key = Self.key(for: rule)
    defaults.removeObject(forKey: "\(key):rule")
    defaults.removeObject(forKey: "\(key):ready")
  }

  private static func key(for rule: RestrictionRule) -> String {
    "ft.change:\(rule.appKey):\(rule.type.rawValue)"
  }
}
