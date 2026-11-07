import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The block screen iOS shows over shielded apps, styled like FocusTrace's
/// Android block screen: the app's name, one line per rule or routine blocking
/// it ("Temporary block until 15:00 · Social", "Study: shared allowance
/// reached"), and a Leave button, in the app's
/// dark background and sky-blue accent.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    configuration(
      name: application.localizedDisplayName,
      tokenKey: application.token.flatMap { SelectionCodec.tokenKey($0) }
    ) {
      $0.contains(application: application.token)
    }
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    configuration(
      name: application.localizedDisplayName,
      tokenKey: application.token.flatMap { SelectionCodec.tokenKey($0) }
    ) {
      $0.contains(application: application.token) || $0.contains(category: category.token)
    }
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    configuration(name: webDomain.domain, tokenKey: webDomain.token.flatMap { SelectionCodec.tokenKey($0) }) {
      $0.contains(webDomain: webDomain.token)
    }
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    configuration(name: webDomain.domain, tokenKey: webDomain.token.flatMap { SelectionCodec.tokenKey($0) }) {
      $0.contains(webDomain: webDomain.token) || $0.contains(category: category.token)
    }
  }

  // Brand colours from lib/src/presentation/focus_trace_app.dart and BlockActivity.kt.
  private static let background = UIColor(red: 7 / 255, green: 10 / 255, blue: 16 / 255, alpha: 1)
  private static let accent = UIColor(red: 91 / 255, green: 192 / 255, blue: 235 / 255, alpha: 1)
  private static let reasonColor = UIColor(red: 219 / 255, green: 226 / 255, blue: 239 / 255, alpha: 1)

  /// `tokenKey` identifies the shielded app or web domain; the rules listed
  /// are recorded under it for the shield action extension.
  private func configuration(
    name: String?, tokenKey: String?, matches: (FamilyActivitySelection) -> Bool
  ) -> ShieldConfiguration {
    let store = RestrictionStore.shared
    let strings = store.shieldStrings
    let now = Date()
    let blocks = ShieldController.blocks(store: store, now: now, matches: matches)

    let formatter = ShieldStrings.timeFormatter()
    let reasons = blocks.map { block -> String in
      var until: Date?
      if case .rule(let rule) = block.kind {
        until = rule.blockedUntil(
          at: now, usageSecondsToday: store.usageProxy(rule, at: now))
      }
      return strings.reason(for: block, until: until, timeFormatter: formatter)
    }
    if let tokenKey = tokenKey {
      store.recordDisplayed(ruleKeys: blocks.map(\.key), tokenKey: tokenKey, now: now)
    }
    if let first = blocks.first {
      // A routine's statistics belong to the member app that was opened.
      var appKey = first.appKey
      var appName = first.appName
      if case .routineShared(let routine) = first.kind,
        let member = routine.includedApps.first(where: { member in
          UsageEvents.selectionId(of: member.appKey)
            .flatMap { store.selection(id: $0) }.map(matches) ?? false
        })
      {
        appKey = member.appKey
        appName = member.appName
      }
      store.recordBlocked(appKey: appKey, appName: appName, reason: first.eventReason, now: now)
    }
    let unblockable = !blocks.isEmpty && blocks.allSatisfy { !$0.isHard }

    return ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialDark,
      backgroundColor: Self.background,
      icon: UIImage(systemName: "hourglass")?
        .withTintColor(Self.accent, renderingMode: .alwaysOriginal),
      title: ShieldConfiguration.Label(
        text: name ?? blocks.first?.appName ?? "FocusTrace", color: .white),
      subtitle: ShieldConfiguration.Label(
        text: reasons.isEmpty ? strings.text("restricted") : reasons.joined(separator: "\n"),
        color: Self.reasonColor),
      primaryButtonLabel: ShieldConfiguration.Label(text: strings.text("leave"), color: Self.background),
      primaryButtonBackgroundColor: Self.accent,
      secondaryButtonLabel: unblockable && store.notificationsAuthorized
        ? ShieldConfiguration.Label(text: strings.text("unblockInApp"), color: Self.accent)
        : nil
    )
  }
}
