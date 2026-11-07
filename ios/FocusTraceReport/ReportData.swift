import DeviceActivity
import Foundation
import ManagedSettings
// DeviceActivityResults and DeviceActivityData's report types come with
// DeviceActivity's SwiftUI overlay.
import SwiftUI

/// One app in a report: its token (drawn with `Label(token)`), name, time,
/// pickups and notifications over the report's span.
struct ReportApp: Identifiable {
  let id: Int
  let token: ApplicationToken?
  let name: String
  let categoryId: Int?
  var seconds: TimeInterval
  var pickups: Int
  var notifications: Int
}

/// One Screen Time category with the time of its apps.
struct ReportCategory: Identifiable {
  let id: Int
  let token: ActivityCategoryToken?
  let name: String
  var seconds: TimeInterval
}

/// Everything a FocusTrace report draws, read once from DeviceActivityResults
/// inside the extension. Only the busiest apps are kept (the views show a
/// capped list), so memory stays small.
struct UsageSnapshot {
  var kind: UsageReportKind
  var buckets: UsageBuckets
  var isHourly: Bool
  var total: TimeInterval
  var apps: [ReportApp]
  var hiddenApps: Int
  var categories: [ReportCategory]
  var pickups: Int
  var notifications: Int
  var strings: ReportStrings

  var hasData: Bool { total >= 1 }

  /// How many apps each report keeps. The views list fewer (`listLimit`) so
  /// they fit the host's fixed heights; today keeps more for its category
  /// chips.
  static func appLimit(for kind: UsageReportKind) -> Int {
    switch kind {
    case .today: return 60
    case .hourly: return 0
    case .week, .month: return 8
    case .appDetail: return 6
    }
  }

  static func make(
    from results: DeviceActivityResults<DeviceActivityData>, kind: UsageReportKind
  ) async -> UsageSnapshot {
    let calendar = Calendar.current
    var interval: DateInterval?
    var hourly: Bool?
    var segments: [(start: Date, duration: TimeInterval, seconds: TimeInterval)] = []
    var apps: [ReportApp] = []
    var appIndex: [AnyHashable: Int] = [:]
    var categories: [ReportCategory] = []
    var categoryIndex: [AnyHashable: Int] = [:]

    for await data in results {
      if interval == nil {
        switch data.segmentInterval {
        case .hourly(during: let span):
          interval = span
          hourly = true
        case .daily(during: let span):
          interval = span
          hourly = false
        case .weekly(during: let span):
          interval = span
          hourly = false
        @unknown default:
          break
        }
      }
      for await segment in data.activitySegments {
        segments.append(
          (segment.dateInterval.start, segment.dateInterval.duration, segment.totalActivityDuration))
        for await categoryActivity in segment.categories {
          let category = categoryActivity.category
          let categoryName = category.localizedDisplayName ?? ""
          let categoryKey: AnyHashable = category.token.map { AnyHashable($0) } ?? AnyHashable(categoryName)
          let categoryId: Int
          if let known = categoryIndex[categoryKey] {
            categoryId = known
          } else {
            categoryId = categories.count
            categoryIndex[categoryKey] = categoryId
            categories.append(
              ReportCategory(id: categoryId, token: category.token, name: categoryName, seconds: 0))
          }
          categories[categoryId].seconds += categoryActivity.totalActivityDuration

          guard kind != .hourly else { continue }
          for await activity in categoryActivity.applications {
            let application = activity.application
            let name = application.localizedDisplayName ?? application.bundleIdentifier ?? ""
            let key: AnyHashable = application.token.map { AnyHashable($0) } ?? AnyHashable(name)
            let index: Int
            if let known = appIndex[key] {
              index = known
            } else {
              index = apps.count
              appIndex[key] = index
              apps.append(
                ReportApp(
                  id: index, token: application.token, name: name, categoryId: categoryId,
                  seconds: 0, pickups: 0, notifications: 0))
            }
            apps[index].seconds += activity.totalActivityDuration
            apps[index].pickups += activity.numberOfPickups
            apps[index].notifications += activity.numberOfNotifications
          }
        }
      }
    }

    // Without a known interval, the segments themselves say what they cover.
    let isHourly = hourly ?? (segments.first.map { $0.duration <= 5400 } ?? (kind == .today || kind == .hourly))
    var span = interval
    if span == nil {
      for segment in segments {
        let next = DateInterval(start: segment.start, duration: segment.duration)
        span = span.map { DateInterval(start: min($0.start, next.start), end: max($0.end, next.end)) } ?? next
      }
    }
    let covered = span ?? kind.defaultRange.interval(endingOn: Date(), calendar: calendar)
    var buckets =
      isHourly
      ? UsageBuckets.hourly(day: covered.start, calendar: calendar)
      : UsageBuckets.daily(interval: covered, calendar: calendar)
    for segment in segments { buckets.add(segment.seconds, at: segment.start) }

    let ranked = UsageReportMath.ranked(
      apps, limit: appLimit(for: kind), seconds: { $0.seconds }, name: { $0.name })
    let rankedCategories = UsageReportMath.ranked(
      categories.filter { $0.seconds >= 60 }, limit: 8, seconds: { $0.seconds }, name: { $0.name })
    return UsageSnapshot(
      kind: kind,
      buckets: buckets,
      isHourly: isHourly,
      total: segments.reduce(0) { $0 + $1.seconds },
      apps: ranked.shown,
      hiddenApps: ranked.hidden,
      categories: kind == .today ? rankedCategories.shown : [],
      pickups: apps.reduce(0) { $0 + $1.pickups },
      notifications: apps.reduce(0) { $0 + $1.notifications },
      strings: RestrictionStore.shared.reportStrings)
  }
}
