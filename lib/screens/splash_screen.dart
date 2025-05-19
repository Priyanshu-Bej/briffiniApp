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
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safeAreaTop = mediaQuery.padding.top;
    final safeAreaBottom = mediaQuery.padding.bottom;

    // Calculate responsive sizes
    final double titleFontSize = screenSize.width < 600 ? 36 : 48;
    final double subtitleFontSize = screenSize.width < 600 ? 16 : 20;
    final double imageSize = screenSize.width < 600 ? 200 : 300;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2A44), // Dark blue background
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2), // Push content down
              // Title
              Text(
                'Briffini Academy',
                style: GoogleFonts.archivo(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: screenSize.height * 0.01),
              // Subtitle
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.1,
                ),
                child: Text(
                  'Explore courses to empower you and your peers with endless knowledge!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: subtitleFontSize,
                    color: Colors.white70,
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),
              // Treasure chest image
              Container(
                width: imageSize,
                height: imageSize,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/treasure_chest.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // Loading indicator
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const Spacer(flex: 1),
              SizedBox(height: screenSize.height * 0.02),
            ],
          ),
        ),
      ),
    );
  }
}
