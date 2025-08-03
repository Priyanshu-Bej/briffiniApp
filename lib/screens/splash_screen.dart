import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/auth_persistence_service.dart';
import '../services/firestore_service.dart';
import '../services/subscription_service.dart';
import '../utils/accessibility_helper.dart';
import '../utils/logger.dart';
import '../utils/responsive_helper.dart';
import 'login_screen.dart';
import 'assigned_courses_screen.dart';
import 'onboarding_screen.dart';
import '../services/notification_service.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;
  String _loadingText = "Loading...";

  // Debug flag to disable preloading if needed
  static const bool _enablePreloading = true;

  @override
  void initState() {
    super.initState();

    Logger.i("🔄 SplashScreen: initState called - Starting app initialization");

    // Configure status bar for splash screen
    _configureStatusBar();

    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start the fade-in animation immediately
    _fadeController.forward();

    // Force immediate UI update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.i("🎨 SplashScreen: Post-frame callback - Ensuring visual update");
      if (mounted) {
        setState(() {
          _loadingText = "Initializing...";
        });
      }
    });

    // Wait for Firebase initialization and then check auth
    _waitForFirebaseAndNavigate();

    // Ultimate failsafe - force navigation after a maximum time
    Timer(const Duration(seconds: 20), () {
      if (mounted && !_isNavigating) {
        Logger.e(
          "🚨 Ultimate failsafe triggered - forcing navigation to login",
        );
        setState(() {
          _isNavigating = true;
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  void _configureStatusBar() {
    // Configure status bar for splash screen
    if (ResponsiveHelper.isIOS()) {
      AccessibilityHelper.configureSystemUI(
        statusBarColor: const Color(0xFF1A237E),
        statusBarIconBrightness: Brightness.light,
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF1A237E),
          statusBarIconBrightness: Brightness.light,
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _waitForFirebaseAndNavigate() async {
    // Add timeout to prevent infinite splash screen
    Timer? timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && !_isNavigating) {
        Logger.w(
          "⏰ Splash screen timeout - forcing navigation to login screen",
        );
        setState(() {
          _isNavigating = true;
        });
        _navigateToLogin();
      }
    });

    try {
      // Show splash screen for minimum duration
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted || _isNavigating) return;

      // Update loading text to show Firebase initialization
      setState(() {
        _loadingText = "Initializing Firebase...";
      });

      // Actually wait for Firebase to be initialized with timeout
      bool firebaseReady = false;
      try {
        firebaseReady = await FirebaseInitState.ensureInitialized().timeout(
          const Duration(seconds: 8),
        );
      } catch (e) {
        Logger.e("Firebase initialization error in splash: $e");
        firebaseReady = false;
      }

      if (!mounted || _isNavigating) return;

      if (!firebaseReady) {
        // Handle Firebase initialization failure - navigate to login instead of retry
        Logger.w("Firebase initialization failed - navigating to login screen");
        setState(() {
          _loadingText = "Connection failed. Continuing to login...";
          _isNavigating = true;
        });

        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          _navigateToLogin();
          return;
        }
      }

      // Firebase is ready, now check authentication
      setState(() {
        _loadingText = "Checking authentication...";
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _isNavigating) return;

      // Now safely check authentication
      await _checkAuthAndNavigate();
    } finally {
      // Cancel timeout timer
      timeoutTimer.cancel();
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted || _isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    try {
      // Get auth service - Firebase is now guaranteed to be initialized
      final authService = Provider.of<AuthService>(context, listen: false);

      // Check authentication state
      Logger.i("Checking authentication state...");

      // Give Firebase Auth more time to restore session on initial app launch
      await Future.delayed(const Duration(milliseconds: 2500));

      // Check if user is already logged in
      if (authService.currentUser != null) {
        // User is already logged in through Firebase Auth
        Logger.i("User already logged in via Firebase Auth");

        // Setup notification handling first
        if (mounted) {
          final notificationService = Provider.of<NotificationService>(
            context,
            listen: false,
          );

          // Get the current user ID
          String? userId = authService.currentUser?.uid;
          if (userId != null) {
            // Ensure topic subscriptions and permissions
            notificationService.ensureTopicSubscriptions(userId);

            // Also refresh token to make sure we have the latest
            notificationService.refreshToken();
          }
        }

        // Navigate if still mounted
        if (mounted) {
          _navigateToHome();
        }
        return;
      }

      // Check if we have persistent login data
      bool isLoggedIn = await AuthPersistenceService.isLoggedIn();

      // Check if still mounted before navigating
      if (!mounted) return;

      if (isLoggedIn) {
        Logger.w(
          "User has persistent login, but Firebase session may not be ready",
        );
        // We have persistent data
        _navigateToHome();
      } else {
        // No login detected, go to login screen
        _navigateToLogin();
      }
    } catch (e) {
      Logger.e("Error during auth check: $e");
      if (mounted) {
        // On error, default to login screen
        _navigateToLogin();
      }
    }
  }

  void _navigateToHome() async {
    if (!mounted || !_isNavigating) return;

    Logger.i("🏠 Navigating to home screen...");

    // Try to preload essential data, but don't block navigation if it fails
    if (_enablePreloading) {
      try {
        await _preloadHomeData();
      } catch (e) {
        Logger.e(
          "🚨 Critical: Preload completely failed, proceeding with immediate navigation: $e",
        );
      }
    } else {
      Logger.i("⚠️ Preloading disabled - proceeding with immediate navigation");
    }

    // Fade out before navigation
    await _fadeController.reverse();

    if (!mounted) return;

    Logger.i("🏠 Performing navigation to AssignedCoursesScreen");

    // Force a frame to render before navigation (iOS Simulator fix)
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const AssignedCoursesScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToLogin() async {
    if (!mounted || !_isNavigating) return;

    Logger.i("🔐 Navigating to login/onboarding screen...");

    // Fade out before navigation
    await _fadeController.reverse();

    if (!mounted) return;

    // Check if onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete =
        prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;

    Widget nextScreen;
    if (onboardingComplete) {
      // If onboarding is done, go to login screen
      Logger.i("🔐 Performing navigation to LoginScreen");
      nextScreen = const LoginScreen();
    } else {
      // If onboarding is not done, go to onboarding screen
      Logger.i("📖 Performing navigation to OnboardingScreen");
      nextScreen = const OnboardingScreen();
    }

    // Force a frame to render before navigation (iOS cold start fix)
    await Future.delayed(const Duration(milliseconds: 100));

    // Additional iOS-specific pre-warming for OnboardingScreen
    if (ResponsiveHelper.isIOS() && nextScreen is OnboardingScreen) {
      // Force system UI update before OnboardingScreen loads
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _preloadHomeData() async {
    if (!mounted) return;

    try {
      // Add timeout protection to prevent app hanging
      await Future.any([
        _performPreload(),
        Future.delayed(const Duration(seconds: 8), () {
          Logger.w("⏰ Preload timeout reached - continuing without preload");
          throw TimeoutException("Preload timeout");
        }),
      ]);
    } catch (e) {
      Logger.e("❌ Error preloading home data: $e");
      // Always continue navigation - don't let preload block the app
      if (mounted) {
        setState(() {
          _loadingText = "Loading...";
        });
      }
    }
  }

  Future<void> _performPreload() async {
    if (!mounted) return;

    setState(() {
      _loadingText = "Loading your courses...";
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );

    Logger.i("🔄 SplashScreen: Starting preload with timeout protection...");

    // Check if user is logged in before attempting preload
    if (authService.currentUser == null) {
      Logger.w("⚠️ No current user - skipping preload");
      return;
    }

    // Preload assigned course IDs with individual timeout
    try {
      final assignedCourseIds = await authService
          .getAssignedCourseIds()
          .timeout(const Duration(seconds: 3));
      Logger.i("📚 Preloaded assigned course IDs: $assignedCourseIds");

      if (!mounted) return;

      setState(() {
        _loadingText = "Loading user data...";
      });

      // Preload user data with timeout
      final user = await authService.getUserData().timeout(
        const Duration(seconds: 3),
      );
      Logger.i("👤 Preloaded user data: ${user?.displayName} (${user?.email})");

      if (!mounted) return;

      setState(() {
        _loadingText = "Checking subscription...";
      });

      // Preload subscription data with timeout
      final userId = authService.currentUser?.uid;
      if (userId != null) {
        await subscriptionService
            .checkUserActiveSubscription(userId)
            .timeout(const Duration(seconds: 3));
        Logger.i("🔍 Preloaded subscription data");
      }

      if (!mounted) return;

      setState(() {
        _loadingText = "Loading courses...";
      });

      // Preload course data if there are assigned courses
      if (assignedCourseIds.isNotEmpty) {
        await firestoreService
            .getAssignedCourses(assignedCourseIds)
            .timeout(const Duration(seconds: 3));
        Logger.i("📋 Preloaded course data");
      }

      Logger.i("✅ SplashScreen: All home data preloaded successfully");

      if (mounted) {
        setState(() {
          _loadingText = "Ready!";
        });

        // Small delay to show "Ready!" message
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      Logger.w("⚠️ Individual preload operation failed: $e - continuing...");
      // Don't rethrow - let the app continue
    }
  }

  @override
  Widget build(BuildContext context) {
    Logger.i("🎨 SplashScreen: build method called - Rendering splash screen");

    // Force visual update immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.i(
        "🔄 SplashScreen: Post-frame callback in build - Forcing visual update",
      );
      if (mounted) {
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1A237E), // Deep blue background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF1A237E),
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E), // Deep blue
              Color(0xFF3F51B5), // Slightly lighter blue
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Text
                  Text(
                    'BRIFFINI',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: ResponsiveHelper.adaptiveFontSize(
                        context,
                        48.0,
                      ),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),

                  SizedBox(
                    height: ResponsiveHelper.getAdaptiveSpacing(
                      context,
                      compact: 16.0,
                      regular: 20.0,
                      pro: 24.0,
                      large: 28.0,
                      extraLarge: 32.0,
                    ),
                  ),

                  // Subtitle
                  Text(
                    'Academy',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: ResponsiveHelper.adaptiveFontSize(
                        context,
                        18.0,
                      ),
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 1.5,
                    ),
                  ),

                  SizedBox(
                    height: ResponsiveHelper.getAdaptiveSpacing(
                      context,
                      compact: 40.0,
                      regular: 50.0,
                      pro: 55.0,
                      large: 60.0,
                      extraLarge: 70.0,
                    ),
                  ),

                  // Loading indicator
                  if (!_isNavigating)
                    Column(
                      children: [
                        SizedBox(
                          width: ResponsiveHelper.adaptiveFontSize(
                            context,
                            32.0,
                          ),
                          height: ResponsiveHelper.adaptiveFontSize(
                            context,
                            32.0,
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.8),
                            ),
                            strokeWidth: 3.0,
                          ),
                        ),

                        SizedBox(
                          height: ResponsiveHelper.getAdaptiveSpacing(
                            context,
                            compact: 16.0,
                            regular: 20.0,
                            pro: 24.0,
                            large: 28.0,
                            extraLarge: 32.0,
                          ),
                        ),

                        // Loading text
                        Text(
                          _loadingText,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: ResponsiveHelper.adaptiveFontSize(
                              context,
                              14.0,
                            ),
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
