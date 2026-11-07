import DeviceActivity
import SwiftUI

/// DeviceActivityReport extension: renders FocusTrace's usage screens inside a
/// sandbox the host app cannot read. Usage numbers never leave this process.
///
/// One scene per `UsageReportKind`; the host (Runner's UsageReportView.swift,
/// shown in Flutter as the platform view `focustrace/usage_report`) picks one
/// by its context name and passes the period and apps as the filter.
@main
struct FocusTraceReportExtension: DeviceActivityReportExtension {
  var body: some DeviceActivityReportScene {
    UsageReportScene(kind: .today) { UsageReportRootView(snapshot: $0) }
    UsageReportScene(kind: .hourly) { UsageReportRootView(snapshot: $0) }
    UsageReportScene(kind: .week) { UsageReportRootView(snapshot: $0) }
    UsageReportScene(kind: .month) { UsageReportRootView(snapshot: $0) }
    UsageReportScene(kind: .appDetail) { UsageReportRootView(snapshot: $0) }
  }
}

struct UsageReportScene: DeviceActivityReportScene {
  let kind: UsageReportKind
  let content: (UsageSnapshot) -> UsageReportRootView

  var context: DeviceActivityReport.Context { DeviceActivityReport.Context(kind.rawValue) }

  func makeConfiguration(
    representing data: DeviceActivityResults<DeviceActivityData>
  ) async -> UsageSnapshot {
    await UsageSnapshot.make(from: data, kind: kind)
  }
}
