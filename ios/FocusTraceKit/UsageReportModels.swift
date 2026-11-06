import Foundation

// Pure-Foundation half of the usage reports (unit-tested in tool/ios/kit_tests):
// which report the host asks for, the period it covers, how DeviceActivity
// segments become hourly or daily buckets, and the texts and durations the
// report extension draws. The SwiftUI views live in FocusTraceReport/; the
// host view in Runner/UsageReportView.swift.

/// The DeviceActivityReport scenes FocusTrace draws. The raw value is the
/// `DeviceActivityReport.Context` name the host and the extension share, and
/// the `context` creation param of the Flutter platview `focustrace/usage_report`.
enum UsageReportKind: String, CaseIterable {
  /// Dashboard: the day's dial with the total, pickups and notifications,
  /// then the per-app list ("Current list") with category chips.
  case today
  /// Dashboard: the day's usage per hour as a bar timeline.
  case hourly
  /// Reports: seven days as bars, totals and the most used apps.
  case week
  /// Reports: thirty days as bars, totals and the most used apps.
  case month
  /// Usage of one picked selection (a rule or routine member) over a range.
  case appDetail

  /// The range a report shows when the host does not name one.
  var defaultRange: UsageReportRange {
    switch self {
    case .today, .hourly, .appDetail: return .today
    case .week: return .week
    case .month: return .month
    }
  }
}

/// The span a report covers, chosen in Flutter (`range` creation param).
enum UsageReportRange: String, CaseIterable {
  case today
  case week
  case month

  var days: Int {
    switch self {
    case .today: return 1
    case .week: return 7
    case .month: return 30
    }
  }

  /// One day is split into hours, longer ranges into days.
  var isHourly: Bool { self == .today }

  /// `days` calendar days ending with (and including) the day of `date`.
  func interval(endingOn date: Date, calendar: Calendar = .current) -> DateInterval {
    let lastDay = calendar.startOfDay(for: date)
    let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay.addingTimeInterval(86_400)
    let start = calendar.date(byAdding: .day, value: -(days - 1), to: lastDay) ?? lastDay
    return DateInterval(start: start, end: end)
  }
}

/// Seconds of use per bucket: the 24 hours of a day, or the days of a range.
struct UsageBuckets: Equatable {
  /// Start of each bucket, ascending.
  var starts: [Date]
  /// End of the last bucket.
  var end: Date
  var seconds: [TimeInterval]

  init(starts: [Date], end: Date) {
    self.starts = starts
    self.end = end
    seconds = Array(repeating: 0, count: starts.count)
  }

  /// The 24 hours of the day that contains `day` (fewer or more on a DST day
  /// would shift the clock face, so it is always 24 clock hours).
  static func hourly(day: Date, calendar: Calendar = .current) -> UsageBuckets {
    let start = calendar.startOfDay(for: day)
    let starts = (0..<24).map { hour in
      calendar.date(byAdding: .hour, value: hour, to: start) ?? start.addingTimeInterval(Double(hour) * 3600)
    }
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    return UsageBuckets(starts: starts, end: end)
  }

  /// One bucket per calendar day in `interval` (at least one).
  static func daily(interval: DateInterval, calendar: Calendar = .current) -> UsageBuckets {
    let first = calendar.startOfDay(for: interval.start)
    var starts: [Date] = []
    var day = first
    while day < interval.end && starts.count < 400 {
      starts.append(day)
      guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
      day = next
    }
    if starts.isEmpty { starts = [first] }
    let last = starts[starts.count - 1]
    let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last.addingTimeInterval(86_400)
    return UsageBuckets(starts: starts, end: end)
  }

  /// Adds use that started at `date` to its bucket; outside the span it is
  /// ignored.
  mutating func add(_ value: TimeInterval, at date: Date) {
    guard value > 0, let index = index(of: date) else { return }
    seconds[index] += value
  }

  func index(of date: Date) -> Int? {
    guard let first = starts.first, date >= first, date < end else { return nil }
    var index = 0
    for (i, start) in starts.enumerated() where start <= date { index = i }
    return index
  }

  var total: TimeInterval { seconds.reduce(0, +) }

  var maximum: TimeInterval { seconds.max() ?? 0 }

  /// The busiest bucket, or nil when nothing was used.
  var peakIndex: Int? {
    guard let maximum = seconds.max(), maximum > 0 else { return nil }
    return seconds.firstIndex(of: maximum)
  }

  /// Buckets with at least a minute of use (Android's "active days").
  var activeCount: Int { seconds.filter { $0 >= 60 }.count }

  /// Mean per bucket over the whole span, as Android's daily average.
  var average: TimeInterval { starts.isEmpty ? 0 : total / Double(starts.count) }
}

enum UsageReportMath {
  /// Bar length as a share of the longest, with a visible stub for any use.
  static func fraction(_ value: TimeInterval, of maximum: TimeInterval, minimum: Double = 0.02) -> Double {
    guard maximum > 0, value > 0 else { return 0 }
    return max(minimum, min(1, value / maximum))
  }

  /// The `limit` largest items (ties by name, so the order is stable) and how
  /// many were left out.
  static func ranked<T>(
    _ items: [T], limit: Int, seconds: (T) -> TimeInterval, name: (T) -> String
  ) -> (shown: [T], hidden: Int) {
    let sorted = items.sorted {
      let a = seconds($0)
      let b = seconds($1)
      return a != b ? a > b : name($0).localizedCaseInsensitiveCompare(name($1)) == .orderedAscending
    }
    let shown = Array(sorted.prefix(max(0, limit)))
    return (shown, sorted.count - shown.count)
  }

  /// Dial slice colour as a share between the dim and bright blues: any use
  /// is visible, a full hour is brightest (Flutter `_ClockPainter`).
  static func dialShade(_ seconds: TimeInterval, capacity: TimeInterval = 3600) -> Double {
    guard seconds > 0, capacity > 0 else { return 0 }
    return min(1, seconds / capacity)
  }
}

/// Texts of the report extension. Flutter sends them from its ARB files with
/// the shield texts (`setShieldStrings`, keys prefixed `report.`), because the
/// sandboxed extension can read the App Group but not Flutter's assets.
/// English is the fallback until it has.
struct ReportStrings: Equatable {
  static let prefix = "report."

  var values: [String: String]

  static let defaults: [String: String] = [
    "totalTime": "Total time",
    "currentList": "Current list",
    "all": "All",
    "timeline": "Usage timeline",
    "totalUsage": "Total usage",
    "dailyAverage": "Daily average",
    "activeDays": "Active days",
    "topApps": "Most used apps",
    "peakTime": "Most active time",
    "pickups": "Pickups",
    "notifications": "Notifications",
    "tapHour": "Tap an hour to see its time",
    "moreApps": "+{count} more",
    "noData": "No Screen Time data for this period yet.",
    "groupApps": "Apps in this group",
    "durationLessThanMinute": "<1m",
    "durationM": "{m}m",
    "durationH": "{h}h",
    "durationHM": "{h}h {m}m",
  ]

  init(values: [String: String] = [:]) {
    self.values = values
  }

  /// The report texts inside the shield string map the app stored.
  init(sharedValues: [String: String]) {
    var values: [String: String] = [:]
    for (key, value) in sharedValues where key.hasPrefix(Self.prefix) {
      values[String(key.dropFirst(Self.prefix.count))] = value
    }
    self.init(values: values)
  }

  func text(_ key: String) -> String {
    if let value = values[key], !value.isBlank { return value }
    return Self.defaults[key] ?? ""
  }

  /// The app language (BCP 47), or nil to follow the device.
  var localeIdentifier: String? {
    guard let value = values["locale"], !value.isBlank else { return nil }
    return value
  }

  /// Dart's `compactDuration`: whole minutes, "<1m" below one.
  func duration(_ seconds: TimeInterval) -> String {
    let totalMinutes = seconds.isFinite ? Int(max(0, seconds) / 60) : 0
    if totalMinutes < 1 { return text("durationLessThanMinute") }
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours == 0 { return text("durationM").replacingOccurrences(of: "{m}", with: "\(minutes)") }
    if minutes == 0 { return text("durationH").replacingOccurrences(of: "{h}", with: "\(hours)") }
    return text("durationHM")
      .replacingOccurrences(of: "{h}", with: "\(hours)")
      .replacingOccurrences(of: "{m}", with: "\(minutes)")
  }

  func moreApps(_ count: Int) -> String {
    text("moreApps").replacingOccurrences(of: "{count}", with: "\(count)")
  }
}

extension RestrictionStore {
  var reportStrings: ReportStrings {
    ReportStrings(sharedValues: shieldStrings.values)
  }

  /// Daily-limit rules the monitor recorded as reached today, as usage
  /// seconds equal to their limit (`ShieldPlanner.usageProxy`), by app key.
  /// Flutter treats them as today's usage, so a reached limit shows
  /// "Blocked until" and offers "Unblock now" exactly as on Android.
  func reachedLimitUsage(at now: Date = Date(), calendar: Calendar = .current) -> [String: Int64] {
    var usage: [String: Int64] = [:]
    for rule in configuration.rules where rule.type == .dailyLimit {
      let seconds = usageProxy(rule, at: now, calendar: calendar)
      if seconds > 0 { usage[rule.appKey] = max(usage[rule.appKey] ?? 0, seconds) }
    }
    return usage
  }
}
