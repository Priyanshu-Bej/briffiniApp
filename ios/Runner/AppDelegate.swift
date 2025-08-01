import Flutter
import UIKit
import UserNotifications
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // CRITICAL: Initialize Firebase first before any other Firebase services
    FirebaseApp.configure()
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // Always enable screenshot prevention when app launches
    toggleScreenProtection(enable: true)
    
    // Setup method channel for screenshot prevention
    let screenProtectionChannel = FlutterMethodChannel(name: "flutter.native/screenProtection", 
                                                    binaryMessenger: controller.binaryMessenger)
    
    screenProtectionChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "preventScreenshots" {
        if let enable = call.arguments as? Bool {
          // Note: We'll keep this channel for backward compatibility
          // but we'll always enforce protection regardless of the value passed
          self.toggleScreenProtection(enable: true)
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
    
    // Setup notification delegates for foreground notification presentation
    if #available(iOS 10.0, *) {
      // For iOS 10 and above, we need to set the UNUserNotificationCenter delegate
      UNUserNotificationCenter.current().delegate = self
      
      // Also set the Firebase Messaging delegate
      Messaging.messaging().delegate = self
    }
    
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
  
  // Handle foreground notifications - This will show notifications even when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    // Check if it's a chat notification
    if let type = userInfo["type"] as? String, type == "chat" {
      // For chat notifications, always show alert, badge, and sound
      if #available(iOS 14.0, *) {
        completionHandler([[.banner, .badge, .sound]])
      } else {
        completionHandler([[.alert, .badge, .sound]])
      }
    } else {
      // For other notifications, let Firebase handle it with default behavior
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }
  
  // Handle notification tap when app is in background or closed
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    // If it's a Firebase message, let Firebase handle it
    if userInfo[AnyHashable("gcm.message_id")] != nil {
      Messaging.messaging().appDidReceiveMessage(userInfo)
    }
    
    // Now we can do our custom handling if needed
    if let type = userInfo["type"] as? String {
      // Log the notification type for debugging
      // Notification type tapped: \(type)
    }
    
    // Call super to let Flutter/Firebase handle the rest
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
  
  // Firebase Messaging Delegate
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
      // Firebase registration token received
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
