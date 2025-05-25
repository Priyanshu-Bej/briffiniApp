import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  // Singleton pattern
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // For navigating to chat screen
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Track if the service has been initialized
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized) return;

    // Initialize Awesome Notifications
    await AwesomeNotifications().initialize(
      null, // no icon for now, it will use the default app icon
      [
        NotificationChannel(
          channelKey: 'chat_channel',
          channelName: 'Chat Notifications',
          channelDescription: 'Notifications for new chat messages',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          enableVibration: true,
          enableLights: true,
        ),
      ],
    );

    // Request notification permissions
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // Request FCM permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    print('User notification settings: ${settings.authorizationStatus}');

    // Configure FCM for specific platforms
    if (!kIsWeb) {
      // iOS-specific setup for foreground notifications
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Get the token even if permissions are denied (for web/some platforms)
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      // Store the token in Firestore
      await _saveTokenToFirestore(token);
    }

    // Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle when app is opened from terminated state
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Handle when app is in background but opened
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Setup Awesome Notifications action handlers
    AwesomeNotifications().actionStream.listen(_onNotificationAction);

    // Mark as initialized
    _isInitialized = true;
  }

  /// Save FCM token to Firestore with user information
  Future<void> _saveTokenToFirestore(String token) async {
    // Get the current user ID
    String? userId = _auth.currentUser?.uid;

    if (userId != null) {
      // Save token with user ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .doc(token)
          .set({
            'token': token,
            'lastUpdated': FieldValue.serverTimestamp(),
            'platform': defaultTargetPlatform.toString(),
            'device': defaultTargetPlatform.toString(),
            'userId': userId,
            'email': _auth.currentUser?.email,
          });

      // Also update in user_tokens collection for quick lookup
      await FirebaseFirestore.instance
          .collection('user_tokens')
          .doc(token)
          .set({
            'token': token,
            'userId': userId,
            'lastUpdated': FieldValue.serverTimestamp(),
            'platform': defaultTargetPlatform.toString(),
          });

      // Subscribe to user-specific topic for direct messages
      await subscribeToTopic('user_$userId');

      // Subscribe to chat notifications topic
      await subscribeToTopic('chat');
    } else {
      // If no user is logged in, we can still store the token
      // for anonymous or pre-login notifications
      await FirebaseFirestore.instance
          .collection('anonymous_tokens')
          .doc(token)
          .set({
            'token': token,
            'lastUpdated': FieldValue.serverTimestamp(),
            'platform': defaultTargetPlatform.toString(),
          });
    }
  }

  /// Handle notification tap to navigate to appropriate screen
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');

    // Handle navigation based on notification type
    if (message.data['type'] == 'chat') {
      final String? chatId = message.data['chatId'];
      if (chatId != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/chat', arguments: chatId);
      }
    } else if (message.data['type'] == 'course') {
      final String? courseId = message.data['courseId'];
      if (courseId != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/course', arguments: courseId);
      }
    } else if (message.data['type'] == 'announcement') {
      // Navigate to announcements screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/announcements');
      }
    }
  }

  /// Subscribe to a topic for targeted notifications
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Delete the token when user logs out
  Future<void> deleteToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      // Remove from Firestore
      await FirebaseFirestore.instance
          .collection('user_tokens')
          .doc(token)
          .delete();

      // Also try to delete from user's tokens collection if we have userId
      String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('tokens')
            .doc(token)
            .delete();

        // Unsubscribe from user's topic
        await unsubscribeFromTopic('user_$userId');

        // Unsubscribe from chat topic
        await unsubscribeFromTopic('chat');
      }
    }

    // Delete the FCM token
    await _firebaseMessaging.deleteToken();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      // Create a local notification using Awesome Notifications
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'chat_channel',
          title: message.notification?.title ?? 'New Message',
          body: message.notification?.body ?? '',
          notificationLayout: NotificationLayout.Default,
          payload: Map<String, String>.from(message.data),
        ),
      );
    }
  }

  void _onNotificationAction(ReceivedAction receivedAction) {
    if (receivedAction.payload != null) {
      // Handle notification tap based on payload
      final payload = receivedAction.payload!;
      
      if (payload['type'] == 'chat') {
        final String? chatId = payload['chatId'];
        if (chatId != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed('/chat', arguments: chatId);
        }
      } else if (payload['type'] == 'course') {
        final String? courseId = payload['courseId'];
        if (courseId != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed('/course', arguments: courseId);
        }
      }
    }
  }
}

// This needs to be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  print('Background message data: ${message.data}');

  // Create a notification even in background
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      channelKey: 'chat_channel',
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? '',
      notificationLayout: NotificationLayout.Default,
      payload: Map<String, String>.from(message.data),
    ),
  );

  // You can perform background tasks here, but keep them lightweight
  // For complex operations, consider using WorkManager or similar solutions
}
