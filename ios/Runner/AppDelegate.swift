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
