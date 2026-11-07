import DeviceActivity
import SwiftUI

/// DeviceActivityReport extension: renders usage UI inside a sandbox the host
/// app cannot read. Usage numbers never leave this process.
///
/// Phase 1 shell: a single total-activity scene. Real usage screens arrive in
/// phase 4 (see docs/ios/ios-port-plan.md).
@main
struct FocusTraceReportExtension: DeviceActivityReportExtension {
  var body: some DeviceActivityReportScene {
    TotalActivityReport { totalActivity in
      TotalActivityView(totalActivity: totalActivity)
    }
  }
}

extension DeviceActivityReport.Context {
  /// Must match the context the host app passes to `DeviceActivityReport`.
  static let totalActivity = Self("Total Activity")
}

struct TotalActivityReport: DeviceActivityReportScene {
  let context: DeviceActivityReport.Context = .totalActivity
  let content: (String) -> TotalActivityView

  func makeConfiguration(
    representing data: DeviceActivityResults<DeviceActivityData>
  ) async -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated
    formatter.zeroFormattingBehavior = .dropAll

    let totalDuration = await data
      .flatMap { $0.activitySegments }
      .reduce(0) { $0 + $1.totalActivityDuration }
    return formatter.string(from: totalDuration) ?? "No activity data"
  }
}

struct TotalActivityView: View {
  let totalActivity: String

  var body: some View {
    VStack(spacing: 8) {
      Text("Screen time")
        .font(.headline)
      Text(totalActivity)
        .font(.largeTitle)
    }
    .padding()
  }
}
