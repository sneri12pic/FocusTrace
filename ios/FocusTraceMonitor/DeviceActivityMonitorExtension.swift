import DeviceActivity
import Foundation

/// Woken by DeviceActivity at the boundaries ScheduleMapper registered, also
/// while FocusTrace is not running. Every callback re-reads the App Group
/// configuration and makes each rule's shield match the rule at this moment,
/// so it never matters which activity fired or whether one was missed.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  /// Callbacks can arrive a moment before the boundary they mark.
  private static let tolerance: TimeInterval = 30

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    reconcile()
  }

  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)
    reconcile()
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    reconcile()
  }

  /// Daily limits arrive in phase 3.
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
  }

  private func reconcile() {
    ShieldController.reconcile(store: .shared, now: Date(), tolerance: Self.tolerance)
  }
}
