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
    respond(
      to: action, tokenKey: SelectionCodec.tokenKey(application),
      completionHandler: completionHandler
    ) {
      $0.contains(application: application)
    }
  }

  override func handle(
    action: ShieldAction,
    for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(
      to: action, tokenKey: SelectionCodec.tokenKey(webDomain),
      completionHandler: completionHandler
    ) {
      $0.contains(webDomain: webDomain)
    }
  }

  override func handle(
    action: ShieldAction,
    for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(to: action, tokenKey: nil, completionHandler: completionHandler) {
      $0.contains(category: category)
    }
  }

  /// `tokenKey` is the shielded app's or web domain's key: the rules the
  /// block screen listed for it are used first, because an app shielded
  /// through a picked category is in no selection's application tokens.
  private func respond(
    to action: ShieldAction,
    tokenKey: String?,
    completionHandler: @escaping (ShieldActionResponse) -> Void,
    matches: (FamilyActivitySelection) -> Bool
  ) {
    switch action {
    case .secondaryButtonPressed:
      let store = RestrictionStore.shared
      let shielded = store.shieldedRuleKeys
      let all = ShieldPlanner.blocks(for: store.configuration)
      let displayed = Set(tokenKey.map { store.displayedRuleKeys(tokenKey: $0) } ?? [])
      let recorded =
        all.first { displayed.contains($0.key) && shielded.contains($0.key) }
        ?? all.first { displayed.contains($0.key) }
      let block = recorded ?? ShieldController.blocks(store: store, now: Date(), matches: matches).first
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
