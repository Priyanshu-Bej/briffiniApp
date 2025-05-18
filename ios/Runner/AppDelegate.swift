import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // Setup method channel for screenshot prevention
    let screenProtectionChannel = FlutterMethodChannel(name: "flutter.native/screenProtection", 
                                                    binaryMessenger: controller.binaryMessenger)
    
    screenProtectionChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "preventScreenshots" {
        if let enable = call.arguments as? Bool {
          // Set screen recording/screenshot protection
          self.toggleScreenProtection(enable: enable)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", 
                             message: "Arguments must be a boolean", 
                             details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func toggleScreenProtection(enable: Bool) {
    DispatchQueue.main.async {
      if #available(iOS 11.0, *) {
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        // If enable is true, we prevent screenshots and recording
        // If false, we allow screenshots and recording
        window?.makeSecure(enable)
      }
    }
  }
}

// Extension to make the window secure against screen capture
extension UIWindow {
  func makeSecure(_ secure: Bool) {
    if secure {
      // Add protection
      self.isHidden = false
      self.layer.superlayer?.allowsGroupOpacity = false
      self.layer.speed = 0
    } else {
      // Remove protection
      self.layer.superlayer?.allowsGroupOpacity = true
      self.layer.speed = 1
    }
  }
}
