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
    await AwesomeNotifications().isNotificationAllowed().then((
      isAllowed,
    ) async {
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

    // Clean up tokens and refresh token for current user if logged in
    String? userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        // Force token refresh and wait for it to complete
        String? token = await refreshToken();
        print(
          'FCM Token refreshed during initialization: ${token != null ? token : 'Failed'}',
        );
      } catch (e) {
        print('Error refreshing token during initialization: $e');
      }
    } else {
      print('No user logged in during initialization');
    }

    // Also listen for auth state changes to refresh token on login
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // User logged in, refresh token
        refreshToken().then((token) {
          print(
            'FCM Token refreshed after login: ${token != null ? 'Success' : 'Failed'}',
          );
        });
      }
    });

    // Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen((token) {
      print('FCM token refreshed automatically: $token');
      _saveTokenToFirestore(token);
    });

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
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onNotificationAction,
      onNotificationCreatedMethod: _onNotificationCreated,
      onNotificationDisplayedMethod: _onNotificationDisplayed,
      onDismissActionReceivedMethod: _onDismissActionReceived,
    );

    // Mark as initialized
    _isInitialized = true;
  }

  /// Force refresh the FCM token and save it to Firestore
  Future<String?> refreshToken() async {
    try {
      // Delete existing token first to force a new one
      try {
        await _firebaseMessaging.deleteToken();
        print('Deleted existing FCM token to force refresh');
      } catch (e) {
        print('Error deleting existing FCM token: $e');
        // Continue anyway to get a fresh token
      }

      // Get a fresh token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('New FCM Token: $token');

        // Store the token in Firestore
        await _saveTokenToFirestore(token);

        // Ensure we're subscribed to topics
        String? userId = _auth.currentUser?.uid;
        if (userId != null) {
          ensureTopicSubscriptions(userId);
        }

        return token;
      } else {
        print('Failed to get FCM token');
        return null;
      }
    } catch (e) {
      print('Error refreshing FCM token: $e');
      return null;
    }
  }

  /// Ensure user is subscribed to all required topics
  Future<void> ensureTopicSubscriptions(String userId) async {
    try {
      print('Ensuring topic subscriptions for user $userId');

      // Get the current token
      String? currentToken = await _firebaseMessaging.getToken();
      if (currentToken == null) {
        print('No current token available, skipping topic subscriptions');
        return;
      }

      // Deactivate all other tokens for this user
      await _deactivateAllOtherTokens(userId, currentToken);

      // Subscribe to user-specific topic
      await subscribeToTopic('user_$userId');
      print('Subscribed to topic: user_$userId');

      // Subscribe to chat topic
      await subscribeToTopic('chat');
      print('Subscribed to topic: chat');

      // Check notification permissions
      NotificationSettings settings =
          await _firebaseMessaging.getNotificationSettings();
      print(
        'Current notification permission status: ${settings.authorizationStatus}',
      );

      // If permissions are not authorized, request them
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print(
          'Notification permissions not authorized, requesting permissions',
        );
        await requestNotificationPermissions();
      }
    } catch (e) {
      print('Error ensuring topic subscriptions: $e');
    }
  }

  /// Save FCM token to Firestore with user information
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      // Get the current user ID
      String? userId = _auth.currentUser?.uid;

      if (userId != null) {
        print('Saving FCM token for user: $userId');

        try {
          // IMPORTANT: Delete ALL other tokens for this user FIRST
          // Get all existing tokens
          final tokensSnapshot =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('tokens')
                  .get();

          print(
            'Found ${tokensSnapshot.docs.length} existing tokens for user $userId',
          );

          // Delete all tokens except the current one
          int deletedCount = 0;
          for (var doc in tokensSnapshot.docs) {
            String tokenId = doc.id;
            if (tokenId != token) {
              // Directly delete from user's tokens collection without marking as inactive
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('tokens')
                    .doc(tokenId)
                    .delete();
              } catch (e) {
                print("Error deleting token from users collection: $e");
              }

              // Also delete from user_tokens collection
              try {
                await FirebaseFirestore.instance
                    .collection('user_tokens')
                    .doc(tokenId)
                    .delete();
              } catch (e) {
                print('Error deleting token from user_tokens collection: $e');
              }

              deletedCount++;
            }
          }

          print('Deleted $deletedCount old tokens for user $userId');

          // Also check for any orphaned tokens in user_tokens collection
          try {
            final userTokensSnapshot =
                await FirebaseFirestore.instance
                    .collection('user_tokens')
                    .where('userId', isEqualTo: userId)
                    .where('token', isNotEqualTo: token)
                    .get();

            for (var doc in userTokensSnapshot.docs) {
              try {
                await FirebaseFirestore.instance
                    .collection('user_tokens')
                    .doc(doc.id)
                    .delete();
                print(
                  "Deleted orphaned token ${doc.id} from user_tokens collection",
                );
              } catch (e) {
                print("Error deleting orphaned token: $e");
              }
            }
          } catch (e) {
            print("Error cleaning up orphaned tokens: $e");
          }
        } catch (e) {
          print('Error deleting old tokens: $e');
        }

        try {
          // Save token with user ID and mark as active
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
                'isActive': true, // Mark as active
              });
        } catch (e) {
          print('Error saving token to user tokens collection: $e');
        }

        try {
          // Also update in user_tokens collection for quick lookup
          await FirebaseFirestore.instance
              .collection('user_tokens')
              .doc(token)
              .set({
                'token': token,
                'userId': userId,
                'lastUpdated': FieldValue.serverTimestamp(),
                'platform': defaultTargetPlatform.toString(),
                'isActive': true, // Mark as active
              });
        } catch (e) {
          print('Error saving token to user_tokens collection: $e');
        }

        // Subscribe to topics in the background
        subscribeToTopic('user_$userId').catchError((e) {
          print('Error subscribing to user topic: $e');
        });

        subscribeToTopic('chat').catchError((e) {
          print('Error subscribing to chat topic: $e');
        });

        print('FCM token saved successfully for user: $userId');
      } else {
        print('No user logged in, saving anonymous token');
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
    } catch (e) {
      print('Error in _saveTokenToFirestore: $e');
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

  /// Check notification permissions status and return a detailed report
  Future<Map<String, dynamic>> checkNotificationPermissions() async {
    Map<String, dynamic> report = {};

    // Check FCM permissions
    NotificationSettings settings =
        await _firebaseMessaging.getNotificationSettings();
    report['fcmAuthStatus'] = settings.authorizationStatus.toString();
    report['fcmAlertSetting'] = settings.alert.toString();
    report['fcmBadgeSetting'] = settings.badge.toString();
    report['fcmSoundSetting'] = settings.sound.toString();

    // Check if we have a token
    String? token = await getToken();
    report['hasToken'] = token != null;
    if (token != null) {
      report['tokenLength'] = token.length;

      // Check if token exists in Firestore
      String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        try {
          var doc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('tokens')
                  .doc(token)
                  .get();
          report['tokenInFirestore'] = doc.exists;
        } catch (e) {
          report['tokenInFirestore'] = false;
          report['firestoreError'] = e.toString();
        }
      }
    }

    // Check Awesome Notifications permissions
    bool isAwesomeNotificationsAllowed =
        await AwesomeNotifications().isNotificationAllowed();
    report['awesomeNotificationsAllowed'] = isAwesomeNotificationsAllowed;

    print('Notification permissions report: $report');
    return report;
  }

  /// Request notification permissions for both FCM and Awesome Notifications
  Future<NotificationSettings> requestNotificationPermissions() async {
    // Request FCM permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    print('FCM permissions request result: ${settings.authorizationStatus}');

    // Request Awesome Notifications permissions
    await AwesomeNotifications().isNotificationAllowed().then((
      isAllowed,
    ) async {
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    return settings;
  }

  /// Delete FCM token when user logs out
  Future<void> deleteToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        // Get user ID before signing out
        String? userId = _auth.currentUser?.uid;

        if (userId != null) {
          print('Logging out user $userId, cleaning up FCM token $token');

          // Directly delete from user's tokens collection without marking as inactive
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('tokens')
                .doc(token)
                .delete();
            print("Token deleted from users collection");
          } catch (e) {
            print("Error deleting user token: $e");
          }

          // Delete from user_tokens collection
          try {
            await FirebaseFirestore.instance
                .collection('user_tokens')
                .doc(token)
                .delete();
            print("Token deleted from user_tokens collection");
          } catch (e) {
            print("Error deleting from user_tokens: $e");
          }

          // Delete ALL other tokens for this user as well (cleanup)
          try {
            final tokensSnapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('tokens')
                    .get();

            int deletedCount = 0;
            for (var doc in tokensSnapshot.docs) {
              String tokenId = doc.id;

              // Directly delete from user's tokens collection
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('tokens')
                    .doc(tokenId)
                    .delete();
              } catch (e) {
                print("Error deleting token $tokenId: $e");
                // Continue with other tokens
              }

              // Also delete from user_tokens collection
              try {
                await FirebaseFirestore.instance
                    .collection('user_tokens')
                    .doc(tokenId)
                    .delete();
              } catch (e) {
                print('Error deleting token from user_tokens collection: $e');
              }

              deletedCount++;
            }

            print(
              'Deleted $deletedCount total tokens for user $userId during logout',
            );

            // Also check for any orphaned tokens in user_tokens collection
            try {
              final userTokensSnapshot =
                  await FirebaseFirestore.instance
                      .collection('user_tokens')
                      .where('userId', isEqualTo: userId)
                      .get();

              for (var doc in userTokensSnapshot.docs) {
                try {
                  await FirebaseFirestore.instance
                      .collection('user_tokens')
                      .doc(doc.id)
                      .delete();
                  print(
                    "Deleted orphaned token ${doc.id} from user_tokens collection",
                  );
                } catch (e) {
                  print("Error deleting orphaned token: $e");
                }
              }
            } catch (e) {
              print("Error cleaning up orphaned tokens: $e");
            }
          } catch (e) {
            print('Error deleting all tokens during logout: $e');
          }

          // Unsubscribe from user's topic
          unsubscribeFromTopic(
            'user_$userId',
          ).catchError((e) => print("Error unsubscribing from user topic: $e"));

          // Unsubscribe from chat topic
          unsubscribeFromTopic(
            'chat',
          ).catchError((e) => print("Error unsubscribing from chat topic: $e"));
        }
      }

      // Delete the FCM token
      try {
        await _firebaseMessaging.deleteToken();
        print("FCM token deleted from Firebase");
      } catch (e) {
        print("Error deleting FCM token from Firebase: $e");
      }

      return;
    } catch (e) {
      print("Error in deleteToken: $e");
      // Don't rethrow, just log and continue
    }
  }

  /// Clean up old tokens for a user to prevent multiple tokens issue
  Future<void> _cleanupOldTokens(String userId, String currentToken) async {
    try {
      // Get all tokens for this user
      final tokensSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('tokens')
              .get();

      int totalTokens = tokensSnapshot.docs.length;
      print('Found $totalTokens tokens for user $userId');

      // If we have 3 or fewer tokens, don't delete any to avoid disrupting notifications
      if (totalTokens <= 3) {
        print('Only $totalTokens tokens found, skipping cleanup');
        return;
      }

      // Sort tokens by lastUpdated (newest first)
      List<QueryDocumentSnapshot> sortedDocs = tokensSnapshot.docs.toList();
      sortedDocs.sort((a, b) {
        final mapA = a.data() as Map<String, dynamic>?;
        final mapB = b.data() as Map<String, dynamic>?;

        Timestamp? timeA = mapA?['lastUpdated'] as Timestamp?;
        Timestamp? timeB = mapB?['lastUpdated'] as Timestamp?;

        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      // Keep the current token and the 2 most recently updated ones
      Set<String> tokensToKeep = {currentToken};

      // Add up to 2 most recent tokens (if they're not the current token)
      for (int i = 0; i < sortedDocs.length && tokensToKeep.length < 3; i++) {
        String tokenId = sortedDocs[i].id;
        if (tokenId != currentToken) {
          tokensToKeep.add(tokenId);
        }
      }

      print(
        'Keeping ${tokensToKeep.length} tokens for user $userId: $tokensToKeep',
      );

      int deletedCount = 0;

      // Delete tokens not in the keep list
      for (var doc in tokensSnapshot.docs) {
        String tokenId = doc.id;
        if (!tokensToKeep.contains(tokenId)) {
          // Delete from user's tokens collection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('tokens')
              .doc(tokenId)
              .delete();

          // Also delete from user_tokens collection
          await FirebaseFirestore.instance
              .collection('user_tokens')
              .doc(tokenId)
              .delete();

          deletedCount++;
        }
      }

      print('Deleted $deletedCount old tokens for user $userId');

      // Ensure we're subscribed to topics with the current token
      subscribeToTopic('user_$userId').catchError((e) {
        print('Error subscribing to user topic: $e');
      });

      subscribeToTopic('chat').catchError((e) {
        print('Error subscribing to chat topic: $e');
      });
    } catch (e) {
      // Just log errors, don't prevent token registration
      print('Error cleaning up old tokens: $e');
    }
  }

  /// Delete all tokens for a user except the current one
  Future<void> cleanupAllTokensExceptCurrent(String userId) async {
    try {
      print('Starting deletion of all tokens for user $userId except current');

      // Get the current token
      String? currentToken = await _firebaseMessaging.getToken();
      if (currentToken == null) {
        print('No current token available, skipping deletion');
        return;
      }

      // Delete all other tokens
      await _deactivateAllOtherTokens(userId, currentToken);
    } catch (e) {
      print('Error during token deletion: $e');
    }
  }

  /// Delete all other tokens for a user except the current one
  Future<void> _deactivateAllOtherTokens(
    String userId,
    String currentToken,
  ) async {
    try {
      print('Deleting all other tokens for user $userId except $currentToken');

      // Get all tokens for this user
      final tokensSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('tokens')
              .get();

      int totalTokens = tokensSnapshot.docs.length;
      print('Found $totalTokens total tokens for user $userId');

      int deletedCount = 0;

      // Process all tokens except the current one
      for (var doc in tokensSnapshot.docs) {
        String tokenId = doc.id;
        if (tokenId != currentToken) {
          // Directly delete from user's tokens collection
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('tokens')
                .doc(tokenId)
                .delete();
            print("Token $tokenId deleted from users collection");
          } catch (e) {
            print("Error deleting token $tokenId from users collection: $e");
          }

          // Also delete from user_tokens collection
          try {
            await FirebaseFirestore.instance
                .collection('user_tokens')
                .doc(tokenId)
                .delete();
            print("Token $tokenId deleted from user_tokens collection");
          } catch (e) {
            print("Error deleting token $tokenId from user_tokens: $e");
          }

          deletedCount++;
        }
      }

      print('Deleted $deletedCount tokens for user $userId');

      // Also check for any orphaned tokens in user_tokens collection
      try {
        final userTokensSnapshot =
            await FirebaseFirestore.instance
                .collection('user_tokens')
                .where('userId', isEqualTo: userId)
                .where('token', isNotEqualTo: currentToken)
                .get();

        for (var doc in userTokensSnapshot.docs) {
          String tokenId = doc.id;
          try {
            await FirebaseFirestore.instance
                .collection('user_tokens')
                .doc(tokenId)
                .delete();
            print(
              "Deleted orphaned token $tokenId from user_tokens collection",
            );
          } catch (e) {
            print("Error deleting orphaned token $tokenId: $e");
          }
        }
      } catch (e) {
        print("Error cleaning up orphaned tokens: $e");
      }
    } catch (e) {
      print('Error in _deactivateAllOtherTokens: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    // Get current FCM token
    String? currentToken = await _firebaseMessaging.getToken();

    // Check if this is a self-notification (from the same device)
    if (message.data['senderFcmToken'] == currentToken) {
      print('Ignoring self-notification from same device');
      return;
    }

    // Handle both notification and data-only messages
    String title = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';

    // For data-only messages or if notification fields are empty, try to use data fields
    if (title == 'New Message' && message.data.containsKey('title')) {
      title = message.data['title'] ?? title;
    }

    if (body.isEmpty && message.data.containsKey('body')) {
      body = message.data['body'] ?? '';
    }

    // Create a local notification using Awesome Notifications
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'chat_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: Map<String, String>.from(message.data),
        category: NotificationCategory.Message,
        wakeUpScreen: true,
      ),
    );

    print('Local notification created with title: $title');
  }

  /// Handle notification action
  @pragma('vm:entry-point')
  static Future<void> _onNotificationAction(ReceivedAction receivedAction) async {
    print('Notification action received: ${receivedAction.toString()}');
    // Handle the action based on the payload
    if (receivedAction.payload != null && receivedAction.payload!['type'] == 'chat') {
      final String? chatId = receivedAction.payload!['chatId'];
      if (chatId != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/chat', arguments: chatId);
      }
    }
  }

  /// Handle notification creation
  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreated(ReceivedNotification receivedNotification) async {
    print('Notification created: ${receivedNotification.toString()}');
  }

  /// Handle notification display
  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayed(ReceivedNotification receivedNotification) async {
    print('Notification displayed: ${receivedNotification.toString()}');
  }

  /// Handle notification dismissal
  @pragma('vm:entry-point')
  static Future<void> _onDismissActionReceived(ReceivedAction receivedAction) async {
    print('Notification dismissed: ${receivedAction.toString()}');
  }

  /// Handle app lifecycle changes to ensure tokens are properly managed
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    print("App lifecycle state changed to: $state");

    // Get current user ID
    String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      print(
        "No user logged in, skipping token management for lifecycle change",
      );
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        // App is in the foreground
        print("App resumed - refreshing FCM token");
        try {
          // Refresh token when app is resumed to ensure we have the latest
          await refreshToken();
        } catch (e) {
          print("Error refreshing token on resume: $e");
        }
        break;

      case AppLifecycleState.inactive:
        // App is inactive, about to enter another state
        break;

      case AppLifecycleState.paused:
        // App is in the background
        print("App paused - verifying token status");
        try {
          // Get current token
          String? token = await _firebaseMessaging.getToken();
          if (token != null) {
            // Update token status to indicate it's still active
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('tokens')
                .doc(token)
                .update({
                  'lastSeen': FieldValue.serverTimestamp(),
                  'isActive': true,
                });

            await FirebaseFirestore.instance
                .collection('user_tokens')
                .doc(token)
                .update({
                  'lastSeen': FieldValue.serverTimestamp(),
                  'isActive': true,
                });
          }
        } catch (e) {
          print("Error updating token status on pause: $e");
        }
        break;

      case AppLifecycleState.detached:
        // App is terminated
        print("App detached - marking token as possibly inactive");
        try {
          // Get current token
          String? token = await _firebaseMessaging.getToken();
          if (token != null) {
            // Update token status to indicate it might be inactive
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('tokens')
                .doc(token)
                .update({
                  'lastSeen': FieldValue.serverTimestamp(),
                  'possiblyTerminated': true,
                });

            await FirebaseFirestore.instance
                .collection('user_tokens')
                .doc(token)
                .update({
                  'lastSeen': FieldValue.serverTimestamp(),
                  'possiblyTerminated': true,
                });
          }
        } catch (e) {
          print("Error updating token status on detach: $e");
        }
        break;

      case AppLifecycleState.hidden:
        // App is hidden (minimized but still running)
        print("App hidden - updating token status");
        try {
          // Get current token
          String? token = await _firebaseMessaging.getToken();
          if (token != null) {
            // Update token status to indicate it's still active but hidden
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('tokens')
                .doc(token)
                .update({
                  'lastSeen': FieldValue.serverTimestamp(),
                  'appHidden': true,
                });
          }
        } catch (e) {
          print("Error updating token status on hidden: $e");
        }
        break;
    }
  }

  /// Perform a full cleanup of orphaned tokens for all users
  /// This should be called periodically to ensure token database stays clean
  Future<void> performFullTokenCleanup() async {
    try {
      print("Starting full token cleanup");

      // Get current user ID
      String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        print("No user logged in, skipping full token cleanup");
        return;
      }

      // Get current token
      String? currentToken = await _firebaseMessaging.getToken();
      if (currentToken == null) {
        print("No current token available, skipping cleanup");
        return;
      }

      print("Current token: $currentToken for user: $userId");

      // STEP 1: Clean up user's own tokens
      try {
        // Get all tokens for this user
        final tokensSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('tokens')
                .get();

        print("Found ${tokensSnapshot.docs.length} tokens for user $userId");

        // Delete all tokens except the current one
        for (var doc in tokensSnapshot.docs) {
          String tokenId = doc.id;
          if (tokenId != currentToken) {
            try {
              // Directly delete without marking as inactive first
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('tokens')
                  .doc(tokenId)
                  .delete();

              print("Deleted token $tokenId for user $userId");
            } catch (e) {
              print("Error deleting token $tokenId: $e");
            }
          }
        }
      } catch (e) {
        print("Error cleaning up user tokens: $e");
      }

      // STEP 2: Clean up user_tokens collection for this user
      try {
        final userTokensSnapshot =
            await FirebaseFirestore.instance
                .collection('user_tokens')
                .where('userId', isEqualTo: userId)
                .get();

        print(
          "Found ${userTokensSnapshot.docs.length} tokens in user_tokens for user $userId",
        );

        for (var doc in userTokensSnapshot.docs) {
          String tokenId = doc.id;
          if (tokenId != currentToken) {
            try {
              // Directly delete without marking as inactive first
              await FirebaseFirestore.instance
                  .collection('user_tokens')
                  .doc(tokenId)
                  .delete();

              print("Deleted token $tokenId from user_tokens collection");
            } catch (e) {
              print("Error deleting token from user_tokens: $e");
            }
          }
        }
      } catch (e) {
        print("Error cleaning up user_tokens: $e");
      }

      print("Token cleanup completed successfully");
    } catch (e) {
      print("Error in performFullTokenCleanup: $e");
    }
  }

  /// Clean up tokens based on lastUpdated timestamp, keeping only the most recent one
  Future<void> cleanupTokensByLastUpdated() async {
    try {
      print("Starting token cleanup based on lastUpdated timestamp");

      // Get current user ID
      String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        print("No user logged in, skipping token cleanup");
        return;
      }

      // STEP 1: Get all tokens for this user
      final tokensSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('tokens')
              .get();

      print("Found ${tokensSnapshot.docs.length} tokens for user $userId");

      // If there's only 0 or 1 token, no need to clean up
      if (tokensSnapshot.docs.length <= 1) {
        print("No cleanup needed, found ${tokensSnapshot.docs.length} tokens");
        return;
      }

      // STEP 2: Sort tokens by lastUpdated (newest first)
      List<QueryDocumentSnapshot> sortedDocs = tokensSnapshot.docs.toList();
      sortedDocs.sort((a, b) {
        final mapA = a.data() as Map<String, dynamic>?;
        final mapB = b.data() as Map<String, dynamic>?;

        Timestamp? timeA = mapA?['lastUpdated'] as Timestamp?;
        Timestamp? timeB = mapB?['lastUpdated'] as Timestamp?;

        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1; // Null timestamps are considered older
        if (timeB == null) return -1;
        return timeB.compareTo(timeA); // Sort descending (newest first)
      });

      // STEP 3: Keep only the most recent token
      String mostRecentTokenId = sortedDocs[0].id;
      print(
        "Most recent token is: $mostRecentTokenId (updated at: ${(sortedDocs[0].data() as Map<String, dynamic>)['lastUpdated']})",
      );

      // STEP 4: Delete all other tokens
      int deletedCount = 0;
      for (int i = 1; i < sortedDocs.length; i++) {
        String tokenId = sortedDocs[i].id;

        // Delete from user's tokens collection
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('tokens')
              .doc(tokenId)
              .delete();

          // Also delete from user_tokens collection
          await FirebaseFirestore.instance
              .collection('user_tokens')
              .doc(tokenId)
              .delete();

          deletedCount++;
          print("Deleted older token: $tokenId");
        } catch (e) {
          print("Error deleting token $tokenId: $e");
        }
      }

      print(
        "Deleted $deletedCount older tokens based on lastUpdated timestamp",
      );

      // STEP 5: Check for orphaned tokens in user_tokens collection
      try {
        final userTokensSnapshot =
            await FirebaseFirestore.instance
                .collection('user_tokens')
                .where('userId', isEqualTo: userId)
                .where('token', isNotEqualTo: mostRecentTokenId)
                .get();

        for (var doc in userTokensSnapshot.docs) {
          try {
            await FirebaseFirestore.instance
                .collection('user_tokens')
                .doc(doc.id)
                .delete();
            print(
              "Deleted orphaned token ${doc.id} from user_tokens collection",
            );
          } catch (e) {
            print("Error deleting orphaned token: $e");
          }
        }
      } catch (e) {
        print("Error cleaning up orphaned tokens: $e");
      }

      print("Token cleanup by lastUpdated completed successfully");
    } catch (e) {
      print("Error in cleanupTokensByLastUpdated: $e");
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

  // Get current FCM token
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? currentToken = await messaging.getToken();

  // Check if this is a self-notification (from the same device)
  if (message.data['senderFcmToken'] == currentToken) {
    print('Ignoring self-notification from same device in background');
    return;
  }

  // Handle both notification and data-only messages
  String title = message.notification?.title ?? 'New Message';
  String body = message.notification?.body ?? '';

  // For data-only messages or if notification fields are empty, try to use data fields
  if (title == 'New Message' && message.data.containsKey('title')) {
    title = message.data['title'] ?? title;
  }

  if (body.isEmpty && message.data.containsKey('body')) {
    body = message.data['body'] ?? '';
  }

  // Create a notification even in background
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      channelKey: 'chat_channel',
      title: title,
      body: body,
      notificationLayout: NotificationLayout.Default,
      payload: Map<String, String>.from(message.data),
      category: NotificationCategory.Message,
      wakeUpScreen: true,
    ),
  );

  print('Background notification created with title: $title');
}
