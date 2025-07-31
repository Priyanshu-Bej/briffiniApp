import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/auth_persistence_service.dart';
import '../utils/logger.dart';
import '../utils/responsive_helper.dart';
import 'login_screen.dart';
import 'assigned_courses_screen.dart';
import 'onboarding_screen.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingText = "Loading...";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    setState(() {
      _loadingText = "Initializing Firebase...";
    });

    try {
      await FirebaseInitState.ensureInitialized();
    } catch (e) {
      Logger.e("Firebase init error: $e");
    }

    if (!mounted) return;

    setState(() {
      _loadingText = "Checking authentication...";
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    _navigate();
  }

  void _navigate() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isLoggedIn = await AuthPersistenceService.isLoggedIn();

      if (!mounted) return;

      Widget nextScreen;
      if (authService.currentUser != null || isLoggedIn) {
        nextScreen = const AssignedCoursesScreen();
      } else {
        final prefs = await SharedPreferences.getInstance();
        final onboardingComplete =
            prefs.getBool('onboarding_complete') ?? false;
        nextScreen = onboardingComplete
            ? const LoginScreen()
            : const OnboardingScreen();
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => nextScreen));
    } catch (e) {
      Logger.e("Navigation error: $e");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'BRIFFINI',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Academy',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 50),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3.0,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _loadingText,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
