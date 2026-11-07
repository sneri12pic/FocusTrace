import DeviceActivity
import Foundation

/// Receives DeviceActivity schedule and threshold callbacks.
///
/// Phase 1 shell: no behaviour yet. Schedules, daily limits and nudges are
/// wired in phases 2 and 3 (see docs/ios/ios-port-plan.md).
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
  }
}
