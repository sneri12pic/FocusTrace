import Foundation

// Codable mirror of the restriction configuration Dart sends through
// `syncRestrictions` (`encodeRestrictionConfiguration` in
// lib/src/domain/models/restriction_rule.dart) and of its Android reader
// (RestrictionRules.kt). Decoding is as lenient as the Kotlin parser: a bad
// rule is dropped, never the whole configuration.
//
// Pure Foundation: compiled into every target and into the CI unit tests
// (tool/ios/kit_tests), so no Screen Time framework may be imported here.

/// App keys of rules whose apps were chosen in Apple's picker.
let iosSelectionKeyPrefix = "ios-sel:"

enum RestrictionRuleType: String, Codable, CaseIterable {
  case blockNow
  case dailyLimit
  case schedule
}

struct RestrictionRule: Codable, Equatable, Hashable {
  var appKey: String
  var appName: String
  var type: RestrictionRuleType
  var untilMs: Int64?
  var limitMinutes: Int?
  var startMinute: Int?
  var endMinute: Int?
  /// "easy", "moderate" or "hard"; unknown values behave like easy.
  var difficulty: String
  /// ISO weekdays (1 = Monday ... 7 = Sunday) on which a schedule starts.
  var weekdays: [Int]

  init(
    appKey: String,
    appName: String,
    type: RestrictionRuleType,
    untilMs: Int64? = nil,
    limitMinutes: Int? = nil,
    startMinute: Int? = nil,
    endMinute: Int? = nil,
    difficulty: String = "easy",
    weekdays: [Int] = Array(1...7)
  ) {
    self.appKey = appKey
    self.appName = appName
    self.type = type
    self.untilMs = untilMs
    self.limitMinutes = limitMinutes
    self.startMinute = startMinute
    self.endMinute = endMinute
    self.difficulty = difficulty
    self.weekdays = weekdays
  }

  enum CodingKeys: String, CodingKey {
    case appKey, appName, type, untilMs, limitMinutes, startMinute, endMinute, difficulty, weekdays
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let appKey = (try? c.decode(String.self, forKey: .appKey)) ?? ""
    let appName = (try? c.decode(String.self, forKey: .appName)) ?? ""
    guard !appKey.isBlank, !appName.isBlank else {
      throw DecodingError.dataCorruptedError(
        forKey: .appKey, in: c, debugDescription: "appKey and appName are required")
    }
    guard let rawType = try? c.decode(String.self, forKey: .type),
      let type = RestrictionRuleType(rawValue: rawType)
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: c, debugDescription: "unknown rule type")
    }
    let untilMs = c.lenientInt64(.untilMs)
    let limitMinutes = c.lenientInt64(.limitMinutes).map { Int(clamping: $0) }
    let startMinute = c.lenientMinute(.startMinute)
    let endMinute = c.lenientMinute(.endMinute)
    switch type {
    case .blockNow:
      guard untilMs != nil else {
        throw DecodingError.dataCorruptedError(
          forKey: .untilMs, in: c, debugDescription: "blockNow needs untilMs")
      }
    case .dailyLimit:
      guard let limit = limitMinutes, limit > 0 else {
        throw DecodingError.dataCorruptedError(
          forKey: .limitMinutes, in: c, debugDescription: "dailyLimit needs limitMinutes")
      }
    case .schedule:
      guard let start = startMinute, let end = endMinute, start != end else {
        throw DecodingError.dataCorruptedError(
          forKey: .startMinute, in: c, debugDescription: "schedule needs distinct minutes")
      }
    }
    var weekdays = Array(1...7)
    if let raw = try? c.decode([LenientInt].self, forKey: .weekdays) {
      var seen = Set<Int>()
      weekdays = raw.compactMap { $0.value }.map { Int(clamping: $0) }
        .filter { (1...7).contains($0) && seen.insert($0).inserted }
    }
    self.init(
      appKey: appKey,
      appName: appName,
      type: type,
      untilMs: untilMs,
      limitMinutes: limitMinutes,
      startMinute: startMinute,
      endMinute: endMinute,
      difficulty: (try? c.decode(String.self, forKey: .difficulty)) ?? "easy",
      weekdays: weekdays
    )
  }

  /// Same keys as Dart's `RestrictionRule.toJson`.
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(appKey, forKey: .appKey)
    try c.encode(appName, forKey: .appName)
    try c.encode(type.rawValue, forKey: .type)
    try c.encode(difficulty, forKey: .difficulty)
    try c.encode(weekdays, forKey: .weekdays)
    try c.encodeIfPresent(untilMs, forKey: .untilMs)
    try c.encodeIfPresent(limitMinutes, forKey: .limitMinutes)
    try c.encodeIfPresent(startMinute, forKey: .startMinute)
    try c.encodeIfPresent(endMinute, forKey: .endMinute)
  }

  /// Rules are unique per app key and type, as on Android.
  var key: String { "\(appKey)#\(type.rawValue)" }

  /// The picker selection id for `ios-sel:<id>` app keys.
  var selectionId: String? {
    appKey.hasPrefix(iosSelectionKeyPrefix)
      ? String(appKey.dropFirst(iosSelectionKeyPrefix.count)) : nil
  }

  /// Stable text of every field, for the change guard's occurrence signature.
  var signature: String {
    func text(_ value: Int64?) -> String { value.map { String($0) } ?? "-" }
    var parts: [String] = [appKey, appName, type.rawValue]
    parts.append(text(untilMs))
    parts.append(text(limitMinutes.map { Int64($0) }))
    parts.append(text(startMinute.map { Int64($0) }))
    parts.append(text(endMinute.map { Int64($0) }))
    parts.append(difficulty)
    parts.append(weekdays.map { String($0) }.joined(separator: ","))
    return parts.joined(separator: "|")
  }

  // MARK: Time logic (RestrictionRules.isBlocked / blockedUntilMs)

  func isBlocked(at now: Date, usageSecondsToday: Int64 = 0, calendar: Calendar = .current)
    -> Bool
  {
    switch type {
    case .blockNow:
      guard let until = untilMs else { return false }
      return now.epochMilliseconds < until
    case .dailyLimit:
      guard let limit = limitMinutes else { return false }
      return usageSecondsToday >= Int64(limit) * 60
    case .schedule:
      return isScheduleActive(at: now, calendar: calendar)
    }
  }

  func blockedUntil(at now: Date, usageSecondsToday: Int64 = 0, calendar: Calendar = .current)
    -> Date?
  {
    guard isBlocked(at: now, usageSecondsToday: usageSecondsToday, calendar: calendar) else {
      return nil
    }
    switch type {
    case .blockNow:
      return untilMs.map(Date.init(epochMilliseconds:))
    case .dailyLimit:
      return calendar.startOfTomorrow(after: now)
    case .schedule:
      guard let end = endMinute else { return nil }
      var date = calendar.date(at: end, onDayOf: now)
      if date <= now {
        date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
      }
      return date
    }
  }

  private func isScheduleActive(at now: Date, calendar: Calendar) -> Bool {
    guard let start = startMinute, let end = endMinute, start != end else { return false }
    let parts = calendar.dateComponents([.hour, .minute], from: now)
    let current = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    var startDay = now
    if end < start && current < end {
      startDay = calendar.date(byAdding: .day, value: -1, to: now) ?? now
    }
    guard weekdays.contains(calendar.isoWeekday(of: startDay)) else { return false }
    return end < start ? (current >= start || current < end) : (current >= start && current < end)
  }
}

/// An enabled routine with a shared daily allowance (Android `RoutineLimit`).
/// Stored for phase 3; iOS does not enforce routines yet.
struct RoutineLimit: Codable, Equatable {
  struct Member: Codable, Equatable {
    var appKey: String
    var appName: String
    var isIncludedInLimit: Bool
    var limitMinutes: Int?
  }

  var id: String
  var name: String
  var limitMinutes: Int
  var apps: [Member]

  enum CodingKeys: String, CodingKey {
    case id, name, isEnabled, dailyLimitMinutes, apps
  }

  enum MemberKeys: String, CodingKey {
    case appKey, appName, isIncludedInLimit, limitMinutes
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let enabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? true
    let id = (try? c.decode(String.self, forKey: .id)) ?? ""
    let name = (try? c.decode(String.self, forKey: .name)) ?? ""
    guard enabled, !id.isBlank, !name.isBlank,
      let limit = c.lenientInt64(.dailyLimitMinutes), limit > 0
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .id, in: c, debugDescription: "not an enforceable routine")
    }
    var members: [Member] = []
    var seen = Set<String>()
    var list = try c.nestedUnkeyedContainer(forKey: .apps)
    while !list.isAtEnd {
      guard let app = try? list.nestedContainer(keyedBy: MemberKeys.self) else {
        _ = try? list.decode(Skip.self)
        continue
      }
      let key = (try? app.decode(String.self, forKey: .appKey)) ?? ""
      let appName = (try? app.decode(String.self, forKey: .appName)) ?? ""
      guard !key.isBlank, !appName.isBlank, seen.insert(key).inserted else { continue }
      members.append(
        Member(
          appKey: key,
          appName: appName,
          isIncludedInLimit: (try? app.decode(Bool.self, forKey: .isIncludedInLimit)) ?? true,
          limitMinutes: app.lenientInt64(.limitMinutes).flatMap { $0 > 0 ? Int(clamping: $0) : nil }
        ))
    }
    guard members.contains(where: { $0.isIncludedInLimit }) else {
      throw DecodingError.dataCorruptedError(
        forKey: .apps, in: c, debugDescription: "no app counts toward the limit")
    }
    self.id = id
    self.name = name
    self.limitMinutes = Int(clamping: limit)
    self.apps = members
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(true, forKey: .isEnabled)
    try c.encode(limitMinutes, forKey: .dailyLimitMinutes)
    try c.encode(apps, forKey: .apps)
  }
}

struct RestrictionConfiguration: Codable, Equatable {
  var rules: [RestrictionRule] = []
  var routines: [RoutineLimit] = []

  init(rules: [RestrictionRule] = [], routines: [RoutineLimit] = []) {
    self.rules = rules
    self.routines = routines
  }

  enum CodingKeys: String, CodingKey {
    case version, rules, routines
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    rules = (try? c.decode(LossyArray<RestrictionRule>.self, forKey: .rules))?.items ?? []
    routines = (try? c.decode(LossyArray<RoutineLimit>.self, forKey: .routines))?.items ?? []
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(3, forKey: .version)
    try c.encode(rules, forKey: .rules)
    try c.encode(routines, forKey: .routines)
  }

  var isEmpty: Bool { rules.isEmpty && routines.isEmpty }

  /// Parses what Dart sent; anything unreadable is an empty configuration,
  /// as in `RestrictionRules.parseConfiguration`.
  static func parse(_ json: String?) -> RestrictionConfiguration {
    guard let json = json, let data = json.data(using: .utf8), !json.isBlank else {
      return RestrictionConfiguration()
    }
    return (try? JSONDecoder().decode(RestrictionConfiguration.self, from: data))
      ?? RestrictionConfiguration()
  }

  func encodedJSON() -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) }
  }
}

// MARK: - Helpers

private struct Skip: Decodable {
  init(from decoder: Decoder) throws {}
}

private struct LossyArray<Element: Decodable>: Decodable {
  var items: [Element] = []

  init(from decoder: Decoder) throws {
    var c = try decoder.unkeyedContainer()
    while !c.isAtEnd {
      if let item = try? c.decode(Element.self) {
        items.append(item)
      } else {
        // A failed decode does not advance the container; skip the element.
        _ = try? c.decode(Skip.self)
      }
    }
  }
}

/// A number sent as an int, a double or a numeric string.
struct LenientInt: Decodable {
  var value: Int64?

  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if let v = try? c.decode(Int64.self) {
      value = v
    } else if let v = try? c.decode(Double.self), v.isFinite {
      value = Int64(v)
    } else if let v = try? c.decode(String.self) {
      value = Int64(v.trimmingCharacters(in: .whitespaces))
    } else {
      value = nil
    }
  }
}

extension KeyedDecodingContainer {
  func lenientInt64(_ key: Key) -> Int64? {
    // `try?` flattens the optional from decodeIfPresent (Swift 5).
    guard let wrapped = try? decodeIfPresent(LenientInt.self, forKey: key) else { return nil }
    return wrapped.value
  }

  func lenientMinute(_ key: Key) -> Int? {
    guard let value = lenientInt64(key), value >= 0, value < 24 * 60 else { return nil }
    return Int(value)
  }
}

extension String {
  var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

extension Date {
  var epochMilliseconds: Int64 { Int64((timeIntervalSince1970 * 1000).rounded(.down)) }

  init(epochMilliseconds: Int64) {
    self.init(timeIntervalSince1970: TimeInterval(epochMilliseconds) / 1000)
  }
}

extension Calendar {
  /// ISO weekday: 1 = Monday ... 7 = Sunday (Calendar uses 1 = Sunday).
  func isoWeekday(of date: Date) -> Int {
    (component(.weekday, from: date) + 5) % 7 + 1
  }

  /// `minuteOfDay` on the day of `date`, with zero seconds.
  func date(at minuteOfDay: Int, onDayOf date: Date) -> Date {
    let day = startOfDay(for: date)
    return self.date(
      bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: day)
      ?? day.addingTimeInterval(TimeInterval(minuteOfDay * 60))
  }

  func startOfTomorrow(after date: Date) -> Date {
    let today = startOfDay(for: date)
    return self.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
  }
}
