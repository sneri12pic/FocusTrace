import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the look of the block screen iOS shows over shielded apps.
///
/// Phase 1 shell: one static configuration for every shielded item.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    Self.focusTraceShield
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    Self.focusTraceShield
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    Self.focusTraceShield
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    Self.focusTraceShield
  }

  private static var focusTraceShield: ShieldConfiguration {
    ShieldConfiguration(
      title: ShieldConfiguration.Label(text: "FocusTrace", color: .label),
      subtitle: ShieldConfiguration.Label(
        text: "This app is restricted right now.",
        color: .secondaryLabel
      ),
      primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white),
      primaryButtonBackgroundColor: .systemIndigo
    )
  }
}
