import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'assigned_courses_screen.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Check authentication state after 2 seconds
    Timer(const Duration(seconds: 2), () {
      _checkAuthAndNavigate();
    });
  }

  // Check if user is already logged in and navigate accordingly
  void _checkAuthAndNavigate() {
    // Get the AuthService instance
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Check if user is already logged in
    if (authService.isUserLoggedIn) {
      // Navigate to the assigned courses screen if logged in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AssignedCoursesScreen()),
      );
    } else {
      // Navigate to login screen if not logged in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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