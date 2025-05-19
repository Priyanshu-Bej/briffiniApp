import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to login screen after 2 seconds
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
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
          // Loading indicator - positioned at the bottom
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 