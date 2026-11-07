import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "FocusTraceNative") {
      FocusTraceChannels.shared.register(with: registrar) { [weak self] in
        self?.topViewController()
      }
      // Backups through the Files pickers.
      DataTransferBridge.shared.register(with: registrar.messenger()) { [weak self] in
        self?.topViewController()
      }
      // Workouts from Apple Health (the iOS side of focustrace/health_connect).
      HealthKitBridge.shared.register(with: registrar.messenger())
      // Usage screens drawn by the FocusTraceReport extension.
      registrar.register(UsageReportFactory(), withId: "focustrace/usage_report")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// The controller to present the app picker from: the Flutter view
  /// controller, or whatever it currently presents.
  private func topViewController() -> UIViewController? {
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
