import DeviceActivity
import FamilyControls
import Flutter
import ManagedSettings
import SwiftUI
import UIKit

/// Platform view `focustrace/usage_report`: hosts Apple's `DeviceActivityReport`
/// view, which iOS fills from FocusTrace's report extension (FocusTraceReport).
/// Flutter never sees the numbers it draws.
///
/// creationParams:
/// - `context`: a `UsageReportKind` raw value (today, hourly, week, month,
///   appDetail) - the extension scene to show.
/// - `range`: a `UsageReportRange` raw value (today, week, month); defaults
///   per context.
/// - `date`: milliseconds since the epoch of the period's last day.
/// - `selectionId`: optional stored picker selection; the report then counts
///   only its apps, categories and websites.
/// - `dark`: whether Flutter's theme is dark (the report follows it).
///
/// Flutter gives the view a fixed height per context; the report does not
/// scroll inside it.
final class UsageReportFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any] ?? [:]
    let kind = UsageReportKind(rawValue: params["context"] as? String ?? "") ?? .today
    let range = UsageReportRange(rawValue: params["range"] as? String ?? "") ?? kind.defaultRange
    let date = (params["date"] as? NSNumber).map {
      Date(timeIntervalSince1970: $0.doubleValue / 1000)
    } ?? Date()
    let selectionId = (params["selectionId"] as? String).flatMap { $0.isBlank ? nil : $0 }
    let dark = (params["dark"] as? NSNumber)?.boolValue ?? true

    let root: UsageReportHost
    if let id = selectionId {
      // A deleted selection must not fall back to "every app".
      if let selection = RestrictionStore.shared.selection(id: id), !selection.isEmptySelection {
        root = .report(kind, UsageReportFilter.make(range: range, date: date, selection: selection))
      } else {
        root = .unavailable(RestrictionStore.shared.reportStrings.text("noData"))
      }
    } else {
      root = .report(kind, UsageReportFilter.make(range: range, date: date, selection: nil))
    }
    return UsageReportPlatformView(frame: frame, root: root, dark: dark)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

enum UsageReportFilter {
  /// Hourly segments for one day, daily segments for a week or month, on
  /// this iPhone (and iPad) for the signed-in user.
  static func make(
    range: UsageReportRange, date: Date, selection: FamilyActivitySelection?,
    calendar: Calendar = .current
  ) -> DeviceActivityFilter {
    let interval = range.interval(endingOn: date, calendar: calendar)
    let segment: DeviceActivityFilter.SegmentInterval =
      range.isHourly ? .hourly(during: interval) : .daily(during: interval)
    return DeviceActivityFilter(
      segment: segment,
      users: .all,
      devices: .init([.iPhone, .iPad]),
      applications: selection?.applicationTokens ?? [],
      categories: selection?.categoryTokens ?? [],
      webDomains: selection?.webDomainTokens ?? [])
  }
}

enum UsageReportHost: View {
  case report(UsageReportKind, DeviceActivityFilter)
  case unavailable(String)

  var body: some View {
    switch self {
    case .report(let kind, let filter):
      DeviceActivityReport(DeviceActivityReport.Context(kind.rawValue), filter: filter)
    case .unavailable(let text):
      Text(text)
        .font(.footnote)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }
}

final class UsageReportPlatformView: NSObject, FlutterPlatformView {
  private let host: UIHostingController<UsageReportHost>

  init(frame: CGRect, root: UsageReportHost, dark: Bool) {
    host = UIHostingController(rootView: root)
    host.view.frame = frame
    host.view.backgroundColor = .clear
    host.overrideUserInterfaceStyle = dark ? .dark : .light
    super.init()
  }

  func view() -> UIView { host.view }
}
