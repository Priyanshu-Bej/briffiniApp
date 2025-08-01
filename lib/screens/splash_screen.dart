import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/auth_persistence_service.dart';
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

  @override
  void initState() {
    super.initState();

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

    // Start the fade-in animation
    _fadeController.forward();

    // Wait for Firebase initialization and then check auth
    _waitForFirebaseAndNavigate();
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
    Timer? timeoutTimer = Timer(const Duration(seconds: 15), () {
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

      // Actually wait for Firebase to be initialized
      bool firebaseReady = false;
      try {
        firebaseReady = await FirebaseInitState.ensureInitialized();
      } catch (e) {
        Logger.e("Firebase initialization error in splash: $e");
        firebaseReady = false;
      }

      if (!mounted || _isNavigating) return;

      if (!firebaseReady) {
        // Handle Firebase initialization failure
        setState(() {
          _loadingText = "Connection failed. Retrying...";
        });

        // Wait and retry
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted && !_isNavigating) {
          // Try again or show error
          _waitForFirebaseAndNavigate();
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

      // Give Firebase Auth a moment to restore session if available
      await Future.delayed(const Duration(milliseconds: 1500));

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

    // Force a frame to render before navigation (iOS Simulator fix)
    await Future.delayed(const Duration(milliseconds: 100));

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

  @override
  Widget build(BuildContext context) {
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
