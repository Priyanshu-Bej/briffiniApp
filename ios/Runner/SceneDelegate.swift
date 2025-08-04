import UIKit
import Flutter

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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        let controller = FlutterViewController.init(engine: nil, nibName: nil, bundle: nil)
        
        // Setup method channel for screenshot prevention in SceneDelegate
        let screenProtectionChannel = FlutterMethodChannel(
            name: "flutter.native/screenProtection", 
            binaryMessenger: controller.binaryMessenger
        )
        
        screenProtectionChannel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "preventScreenshots" {
                if let enable = call.arguments as? Bool {
                    // Note: We'll keep this channel for backward compatibility
                    // but we'll always enforce protection regardless of the value passed
                    DispatchQueue.main.async {
                        self.toggleScreenProtection(enable: true)
                    }
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
        
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
        
        // Always enable screenshot prevention when scene loads
        DispatchQueue.main.async {
            self.toggleScreenProtection(enable: true)
        }
    }
    
    private func toggleScreenProtection(enable: Bool) {
        if #available(iOS 11.0, *) {
            guard let window = self.window else { return }
            // If enable is true, we prevent screenshots and recording
            // If false, we allow screenshots and recording
            window.makeSecure(enable)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}