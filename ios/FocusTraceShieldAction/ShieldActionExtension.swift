import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Handles the block screen's buttons.
///
/// Primary ("Leave") closes the blocked app, like Android's Leave button.
/// iOS gives a shield no way to open FocusTrace, so the secondary button
/// (offered for Easy and Moderate rules and for routines, and only when
/// notifications are allowed) posts a notification that opens FocusTrace when tapped, where the
/// rule can be unblocked through the usual difficulty checks. Then it closes
/// the app as well.
class ShieldActionExtension: ShieldActionDelegate {
  override func handle(
    action: ShieldAction,
    for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(to: action, completionHandler: completionHandler) {
      $0.contains(application: application)
    }
  }

  override func handle(
    action: ShieldAction,
    for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(to: action, completionHandler: completionHandler) {
      $0.contains(webDomain: webDomain)
    }
  }

  override func handle(
    action: ShieldAction,
    for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(to: action, completionHandler: completionHandler) {
      $0.contains(category: category)
    }
  }

  private func respond(
    to action: ShieldAction,
    completionHandler: @escaping (ShieldActionResponse) -> Void,
    matches: (FamilyActivitySelection) -> Bool
  ) {
    switch action {
    case .secondaryButtonPressed:
      let store = RestrictionStore.shared
      let block = ShieldController.blocks(store: store, now: Date(), matches: matches).first
      guard let block = block, !block.isHard else {
        completionHandler(.close)
        return
      }
      postOpenAppNotification(ruleName: block.appName, strings: store.shieldStrings) {
        completionHandler(.close)
      }
    case .primaryButtonPressed:
      completionHandler(.close)
    @unknown default:
      completionHandler(.close)
    }
  }

  private func postOpenAppNotification(
    ruleName: String, strings: ShieldStrings, completion: @escaping () -> Void
  ) {
    let content = UNMutableNotificationContent()
    content.title = "FocusTrace"
    content.body = strings.notificationBody(ruleName: ruleName)
    let request = UNNotificationRequest(
      identifier: "focustrace.unblock.\(ruleName)", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { _ in completion() }
  }
}
