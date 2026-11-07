import DeviceActivity
import Foundation
import UserNotifications

/// Woken by DeviceActivity at the boundaries and usage thresholds
/// ScheduleMapper registered, also while FocusTrace is not running. Every
/// callback re-reads the App Group configuration and makes each block's shield
/// match this moment, so it never matters which activity fired or whether one
/// was missed.
///
/// Usage thresholds (UsageEvents): a reached daily limit, routine allowance or
/// routine app cap is recorded for the day and shielded until the next day's
/// interval starts; warnings and preferred-usage nudges become local
/// notifications, each at most once a day.
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

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    let store = RestrictionStore.shared
    let now = Date()
    if let key = UsageEvents.reachedKey(activity: activity.rawValue, event: event.rawValue) {
      store.markReached(key, at: now)
      ShieldController.reconcile(store: store, now: now)
      WidgetRefresher.reload()
    }
    guard
      let notice = UsageEvents.notice(
        activity: activity.rawValue, event: event.rawValue,
        configuration: store.configuration, strings: store.shieldStrings),
      store.claimNotice("\(activity.rawValue)#\(event.rawValue)", at: now)
    else { return }
    post(notice)
  }

  /// Also redraws the home screen widget when the shields changed.
  private func reconcile() {
    let store = RestrictionStore.shared
    let before = store.shieldedRuleKeys
    let after = ShieldController.reconcile(store: store, now: Date(), tolerance: Self.tolerance)
    if after != before { WidgetRefresher.reload() }
  }

  /// Without notification permission iOS drops the request; blocking does not
  /// depend on it, as on Android.
  private func post(_ notice: UsageNotice) {
    let content = UNMutableNotificationContent()
    content.title = notice.title
    content.body = notice.body
    content.sound = .default
    content.threadIdentifier = "focustrace.usage"
    let request = UNNotificationRequest(
      identifier: notice.identifier, content: content, trigger: nil)
    let done = DispatchSemaphore(value: 0)
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        NSLog("FocusTrace: notification not posted: \(error)")
      }
      done.signal()
    }
    // The extension may be suspended as soon as the callback returns.
    _ = done.wait(timeout: .now() + 5)
  }
}
