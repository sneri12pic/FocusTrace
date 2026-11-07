import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The block screen iOS shows over shielded apps, styled like FocusTrace's
/// Android block screen: the app's name, one line per rule blocking it
/// ("Temporary block until 15:00 · Social"), and a Leave button, in the app's
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
    let shielded = store.shieldedRuleKeys
    let candidates = store.configuration.rules.filter { rule in
      guard let id = rule.selectionId, let selection = store.selection(id: id) else { return false }
      return matches(selection)
    }
    // Prefer what the shield state says; fall back to the rules' own clocks.
    var rules = candidates.filter { shielded.contains($0.key) }
    if rules.isEmpty {
      rules = candidates.filter { $0.isBlocked(at: now) }
    }

    let formatter = ShieldStrings.timeFormatter()
    let reasons = rules.map {
      strings.reason(for: $0, until: $0.blockedUntil(at: now), timeFormatter: formatter)
    }
    if let tokenKey = tokenKey {
      store.recordDisplayed(ruleKeys: rules.map(\.key), tokenKey: tokenKey, now: now)
    }
    if let first = rules.first {
      store.recordBlocked(
        appKey: first.appKey, appName: first.appName, reason: first.type.rawValue, now: now)
    }
    let unblockable = !rules.isEmpty && rules.allSatisfy { $0.difficulty != "hard" }

    return ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialDark,
      backgroundColor: Self.background,
      icon: UIImage(systemName: "hourglass")?
        .withTintColor(Self.accent, renderingMode: .alwaysOriginal),
      title: ShieldConfiguration.Label(
        text: name ?? rules.first?.appName ?? "FocusTrace", color: .white),
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
