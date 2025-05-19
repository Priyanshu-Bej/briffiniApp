import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/auth_persistence_service.dart';
import 'login_screen.dart';
import 'assigned_courses_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Check authentication status and navigate accordingly
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Delay slightly to allow UI to render
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Get auth service
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is already logged in
    if (authService.currentUser != null) {
      // User is already logged in through Firebase Auth
      print("User already logged in via Firebase Auth");
      _navigateToHome();
    } else {
      // Check if we have persistent login data
      bool isLoggedIn = await AuthPersistenceService.isLoggedIn();
      if (isLoggedIn) {
        print("User has persistent login, but Firebase session expired");
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

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsiveness
    final size = MediaQuery.of(context).size;

    // Calculate font size based on screen width for responsiveness
    final double fontSize = size.width * 0.15; // 15% of screen width

    return Scaffold(
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
