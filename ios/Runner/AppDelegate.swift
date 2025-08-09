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

    // Initialize Firebase BEFORE calling super to ensure proper plugin registration
    FirebaseApp.configure()

    // Setup notification delegates for foreground notification presentation
    if #available(iOS 10.0, *) {
      // Set UNUserNotificationCenter delegate
      UNUserNotificationCenter.current().delegate = self

      // Set Firebase Messaging delegate
      Messaging.messaging().delegate = self
    }

    // IMPORTANT: Initialize Flutter engine first, then register plugins
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    GeneratedPluginRegistrant.register(with: self)
    return result
  }

  // Handle foreground notifications - show notifications even when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo

    // Check if notification is a chat type
    if let type = userInfo["type"] as? String, type == "chat" {
      if #available(iOS 14.0, *) {
        completionHandler([[.banner, .badge, .sound]])
      } else if #available(iOS 10.0, *) {
        // Use alert for iOS 10-13 (deprecated but still functional)
        completionHandler([[.alert, .badge, .sound]])
      }
    } else {
      // Default handling for other notifications
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  // Handle notification taps when app is backgrounded or closed
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    if userInfo[AnyHashable("gcm.message_id")] != nil {
      Messaging.messaging().appDidReceiveMessage(userInfo)
    }

    if let type = userInfo["type"] as? String {
      print("Notification type tapped: \(type)")
    }

    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  // Firebase Messaging delegate method: receives registration token
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
      print("FCM registration token: \(token)")
    }
  }

  // Forward APNs device token to Firebase when AppDelegate proxying is disabled
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }
}