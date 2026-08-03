import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    // Prefer FlutterViewController messenger after super (window ready);
    // fall back to registrar for scene/cold-start edge cases.
    if let controller = window?.rootViewController as? FlutterViewController {
      ReceiptOcrBridge.register(with: controller.binaryMessenger)
    } else if let registrar = self.registrar(forPlugin: "ReceiptOcrBridge") {
      ReceiptOcrBridge.register(with: registrar.messenger())
    }
    return launched
  }
}
