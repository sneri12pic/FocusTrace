import Foundation

/// Shared App Group used by the Runner app and every FocusTrace extension.
///
/// FocusTraceKit sources are compiled into each target directly (no framework),
/// so everything here must stay extension-safe (APPLICATION_EXTENSION_API_ONLY).
enum AppGroup {
  /// Must match `com.apple.security.application-groups` in every
  /// `*.entitlements` file under `ios/`.
  static let identifier = "group.com.stepandemianenko.focustrace"

  /// Shared defaults suite. `nil` only when the App Group entitlement is
  /// missing from the signed binary.
  static var userDefaults: UserDefaults? {
    UserDefaults(suiteName: identifier)
  }
}
