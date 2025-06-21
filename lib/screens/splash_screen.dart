import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/auth_persistence_service.dart';
import '../utils/logger.dart';
import 'login_screen.dart';
import 'assigned_courses_screen.dart';
import 'onboarding_screen.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Check authentication status and navigate accordingly
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Reduce delay to improve user experience
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Get auth service
    final authService = Provider.of<AuthService>(context, listen: false);

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
    } else {
      // Check if we have persistent login data
      bool isLoggedIn = await AuthPersistenceService.isLoggedIn();

      // Check if still mounted before navigating
      if (!mounted) return;

      if (isLoggedIn) {
        Logger.w("User has persistent login, but Firebase session expired");
        // We have persistent data but Firebase session is gone
        // This should be rare due to Firebase's own persistence
        _navigateToHome();
      } else {
        // No login detected, go to login screen
        _navigateToLogin();
      }
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AssignedCoursesScreen()),
    );
  }

  void _navigateToLogin() async {
    if (!mounted) return;
    
    // Check if onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    
    if (!mounted) return;
    
    if (onboardingComplete) {
      // If onboarding is done, go to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // If onboarding is not done, go to onboarding screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsiveness
    final size = MediaQuery.of(context).size;

    // Calculate font size based on screen width for responsiveness
    final double fontSize = size.width * 0.15; // 15% of screen width

    return Scaffold(
      backgroundColor: const Color(0xFF1A237E), // Deep blue background
      // Use extendBodyBehindAppBar to make the app draw behind the status bar
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          // Background
          Container(
            color: const Color(0xFF1A237E), // Deep blue background
            width: double.infinity,
            height: double.infinity,
          ),
          // BRIFFINI Text - centered on screen
          Center(
            child: Text(
              'BRIFFINI',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
