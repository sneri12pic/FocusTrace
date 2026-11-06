import FamilyControls
import Flutter
import Foundation
import UIKit
import UserNotifications

/// The iOS side of the Dart channels:
/// - `focustrace/usage`: the restriction methods Android's MainActivity
///   implements (syncRestrictions, readRestrictionConfiguration,
///   requestRestrictionChange, the notifications permission) plus
///   takeRestrictionEvents. Usage numbers never come through here on iOS.
/// - `focustrace/screen_time`: Screen Time authorization, the app picker and
///   the shield's texts.
/// - platform view `focustrace/selection_icons`.
final class FocusTraceChannels: NSObject {
  static let shared = FocusTraceChannels()

  /// Read-check-write of the stored rules never interleaves (Android's
  /// restrictionLock); shield and monitoring updates run here too.
  private let queue = DispatchQueue(label: "com.stepandemianenko.focustrace.restrictions")
  private var topViewController: () -> UIViewController? = { nil }
  private var isPicking = false

  func register(
    with registrar: FlutterPluginRegistrar,
    topViewController: @escaping () -> UIViewController?
  ) {
    self.topViewController = topViewController
    let messenger = registrar.messenger()
    FlutterMethodChannel(name: "focustrace/usage", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handleUsage(call, result: result) }
    FlutterMethodChannel(name: "focustrace/screen_time", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleScreenTime(call, result: result)
      }
    registrar.register(SelectionIconsFactory(), withId: "focustrace/selection_icons")
    NotificationCenter.default.addObserver(
      self, selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  /// A block may have started or ended while FocusTrace was in the background
  /// and the monitor was not woken (e.g. more rules than monitored activities).
  @objc private func didBecomeActive() {
    queue.async { RestrictionEnforcer.refresh() }
  }

  // MARK: focustrace/usage

  private func handleUsage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let store = RestrictionStore.shared
    switch call.method {
    case "syncRestrictions":
      let json = call.arguments as? String ?? ""
      queue.async {
        do {
          try RestrictionSync.apply(json: json, store: store)
          store.removeUnreferencedSelections()
          RestrictionEnforcer.refresh(store: store)
          Self.reply(result, nil)
        } catch let locked as RestrictionSync.Locked {
          Self.reply(
            result,
            FlutterError(code: "RESTRICTION_LOCKED", message: locked.description, details: nil))
        } catch {
          Self.reply(
            result,
            FlutterError(
              code: "RESTRICTION_SYNC_FAILED", message: "\(error)", details: nil))
        }
      }
    case "readRestrictionConfiguration":
      queue.async { Self.reply(result, store.configurationJSON) }
    case "requestRestrictionChange":
      let args = call.arguments as? [String: Any] ?? [:]
      let appKey = args["appKey"] as? String ?? ""
      let type = args["type"] as? String ?? ""
      queue.async {
        Self.reply(result, RestrictionSync.requestChange(appKey: appKey, type: type, store: store))
      }
    case "takeRestrictionEvents":
      queue.async { Self.reply(result, store.takeEvents()) }
    case "hasNotificationsPermission":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let allowed = Self.allowsNotifications(settings.authorizationStatus)
        store.notificationsAuthorized = allowed
        Self.reply(result, allowed)
      }
    case "requestNotificationsPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
        granted, _ in
        store.notificationsAuthorized = granted
        Self.reply(result, granted)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func allowsNotifications(_ status: UNAuthorizationStatus) -> Bool {
    switch status {
    case .authorized, .provisional, .ephemeral: return true
    case .denied, .notDetermined: return false
    @unknown default: return false
    }
  }

  // MARK: focustrace/screen_time

  private func handleScreenTime(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "authorizationStatus":
      result(Self.statusName(AuthorizationCenter.shared.authorizationStatus))
    case "requestAuthorization":
      Task {
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
          NSLog("FocusTrace: Screen Time authorization failed: \(error)")
        }
        let status = Self.statusName(AuthorizationCenter.shared.authorizationStatus)
        Self.reply(result, status)
      }
    case "pickSelection":
      pickSelection(args, result: result)
    case "selectionSummary":
      let id = args["selectionId"] as? String ?? ""
      queue.async {
        let summary = RestrictionStore.shared.selection(id: id).map { Self.summary(id: id, $0) }
        Self.reply(result, summary)
      }
    case "setShieldStrings":
      let values = (args["strings"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
      queue.async {
        let store = RestrictionStore.shared
        store.shieldStrings = ShieldStrings(values: values)
        Self.reply(result, nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickSelection(_ args: [String: Any], result: @escaping FlutterResult) {
    guard !isPicking, let presenter = topViewController() else {
      result(FlutterError(code: "PICKER_UNAVAILABLE", message: "The picker is busy.", details: nil))
      return
    }
    let store = RestrictionStore.shared
    let existingId = (args["selectionId"] as? String).flatMap { $0.isBlank ? nil : $0 }
    if let id = existingId {
      // Changing the apps of an active rule weakens it as much as deleting it.
      let now = Date()
      let guardian = RestrictionChangeGuard(defaults: store.defaults)
      let locked = store.configuration.rules.contains {
        $0.selectionId == id
          && guardian.check($0, now: now, usageSeconds: store.usageProxy($0, at: now))
            != "allowed"
      }
      if locked {
        result(
          FlutterError(
            code: "RESTRICTION_LOCKED", message: "This selection is part of an active rule.",
            details: nil))
        return
      }
    }
    isPicking = true
    ActivityPickerPresenter.present(
      from: presenter,
      initial: existingId.flatMap { store.selection(id: $0) } ?? FamilyActivitySelection(),
      doneLabel: args["doneLabel"] as? String ?? "Done",
      cancelLabel: args["cancelLabel"] as? String ?? "Cancel"
    ) { [weak self] selection in
      self?.isPicking = false
      guard let selection = selection, !selection.isEmptySelection else {
        result(nil)
        return
      }
      let id = existingId ?? UUID().uuidString.lowercased()
      guard store.storeSelection(selection, id: id) else {
        result(
          FlutterError(code: "SELECTION_NOT_SAVED", message: "Could not store the selection.",
            details: nil))
        return
      }
      if existingId != nil {
        self?.queue.async { RestrictionEnforcer.refresh(store: store) }
      }
      result(Self.summary(id: id, selection))
    }
  }

  private static func summary(id: String, _ selection: FamilyActivitySelection) -> [String: Any] {
    [
      "selectionId": id,
      "appKey": iosSelectionKeyPrefix + id,
      "appCount": selection.applicationTokens.count,
      "categoryCount": selection.categoryTokens.count,
      "webDomainCount": selection.webDomainTokens.count,
    ]
  }

  private static func statusName(_ status: AuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .approved: return "approved"
    @unknown default: return "notDetermined"
    }
  }

  /// FlutterResult must be called on the main thread.
  private static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    if Thread.isMainThread {
      result(value)
    } else {
      DispatchQueue.main.async { result(value) }
    }
  }
}
