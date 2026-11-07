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

  /// Runs `body` while holding an exclusive `flock` on `ft.<name>.lock` in the
  /// App Group container, so the app and the extensions (separate processes)
  /// never interleave read-modify-write sequences on shared state. Held only
  /// for the duration of `body`, which must be short and synchronous. Without
  /// the container (an unsigned build, or the macOS kit tests) the lock file
  /// lives in the temporary directory, which still serializes one process.
  static func withLock<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
    let fileManager = FileManager.default
    var directory = fileManager.temporaryDirectory
    #if os(iOS)
      if let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
        directory = container
      }
    #endif
    let path = directory.appendingPathComponent("ft.\(name).lock").path
    let descriptor = open(path, O_CREAT | O_RDWR, 0o644)
    guard descriptor >= 0 else { return try body() }
    defer { close(descriptor) }
    flock(descriptor, LOCK_EX)
    defer { flock(descriptor, LOCK_UN) }
    return try body()
  }
}
