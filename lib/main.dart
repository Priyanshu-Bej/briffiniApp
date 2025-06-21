import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Add this for StreamSubscription
import 'dart:io' show Platform;
import 'screens/splash_screen.dart';
import 'screens/assigned_courses_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'utils/app_info.dart';
import 'utils/accessibility_helper.dart';
import 'utils/app_theme.dart';
import 'utils/text_scale_calculator.dart';
import 'utils/logger.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:student_app/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

// Global flag to track Firebase availability - default is true now since we want dynamic data
bool isFirebaseInitialized = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI properties for the entire app with platform-specific adjustments
  final Brightness statusBarIconBrightness =
      Platform.isIOS ? Brightness.dark : Brightness.light;

  final Brightness navBarIconBrightness =
      Platform.isIOS ? Brightness.dark : Brightness.light;

  AccessibilityHelper.configureSystemUI(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: statusBarIconBrightness,
    navigationBarColor: Platform.isIOS ? null : Colors.white,
    navigationBarIconBrightness: navBarIconBrightness,
  );

  // Request storage permissions
  await _requestPermissions();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
    Logger.i("Firebase initialized successfully");

    // Force Firebase Storage initialization
    try {
      final storage = FirebaseStorage.instance;
      Logger.i("Firebase Storage initialized: ${storage.bucket}");
    } catch (e) {
      Logger.e("Error initializing Firebase Storage: $e");
    }

    // Initialize notification service but don't wait for token refresh
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Don't wait for token refresh here - do it after app starts
  } catch (e) {
    Logger.e("Failed to initialize Firebase: $e");
    isFirebaseInitialized = false;
  }

  // Run the app
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  if (await Permission.storage.status.isDenied) {
    await Permission.storage.request();
  }

  // Add notifications permission request for iOS
  if (Platform.isIOS) {
    if (await Permission.notification.status.isDenied) {
      await Permission.notification.request();
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AuthService? _authService;
  StreamSubscription<User?>? _tokenChangesSubscription;
  NotificationService? _notificationService;

  @override
  void initState() {
    super.initState();

    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Initialize notification service
    _notificationService = NotificationService();

    // We'll initialize the token change listener in the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTokenChangeListener();

      // Clean up tokens based on lastUpdated timestamp when the app starts
      if (isFirebaseInitialized) {
        _notificationService
            ?.cleanupTokensByLastUpdated()
            .then((_) {
              Logger.i("Initial token cleanup by lastUpdated completed");
            })
            .catchError((e) {
              Logger.e("Error during initial token cleanup: $e");
            });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    Logger.i('App lifecycle state changed to: $state');

    // Handle app lifecycle changes for notification token management
    _notificationService?.handleAppLifecycleChange(state);

    // Reset system UI when app is resumed to handle different device behaviors
    if (state == AppLifecycleState.resumed) {
      final Brightness statusBarIconBrightness =
          Platform.isIOS ? Brightness.dark : Brightness.light;

      AccessibilityHelper.configureSystemUI(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
      );
    }
  }

  void _setupTokenChangeListener() {
    if (!isFirebaseInitialized) return;

    _authService = AuthService();

    // Listen for token changes to handle custom claims updates
    _tokenChangesSubscription = _authService!.idTokenChanges.listen(
      (User? user) async {
        if (user != null) {
          Logger.i("ID token changed - user is signed in");

          // Get the latest claims
          final claims = await _authService!.getCustomClaims();
          Logger.i("Updated claims: $claims");

          // Verify if these claims contain our expected fields
          if (claims.containsKey('role') ||
              claims.containsKey('assignedCourseIds')) {
            Logger.i("Custom claims contain role or assignedCourseIds");
          }
        } else {
          Logger.i("ID token changed - user is signed out");
        }
      },
      onError: (error) {
        Logger.e("Error in ID token change listener: $error");
      },
    );
  }

  @override
  void dispose() {
    // Unregister from lifecycle events
    WidgetsBinding.instance.removeObserver(this);

    // Clean up the subscription
    _tokenChangesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => _authService ?? AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        // Add a provider for Firebase initialization status
        Provider<bool>(create: (_) => isFirebaseInitialized),
      ],
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: AppInfo.appName,
        debugShowCheckedModeBanner: false,
        // Add builder for handling text scaling and other accessibility features
        builder: (context, child) {
          // Apply a maximum text scale factor to prevent layout issues
          return TextScaleCalculator.wrapWithConstrainedTextScale(
            context: context,
            child: child!,
          );
        },
        // Use platform-specific theme
        theme: AppTheme.getAppTheme(context),
        home: const SplashScreen(),
        // Add fallback route to prevent white screen
        onUnknownRoute:
            (settings) => MaterialPageRoute(
              builder: (_) => const AssignedCoursesScreen(),
            ),
        // Define routes for navigation from notifications
        routes: {
          '/chat': (context) => ChatScreen(),
          '/notification-settings':
              (context) => const NotificationSettingsScreen(),
        },
      ),
    );
  }
}
