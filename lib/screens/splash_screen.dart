import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
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
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    // Add a delay for the splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Listen for auth state changes and navigate accordingly
    authService.authStateChanges.first.then((user) {
      if (user != null) {
        // User is logged in, navigate to the courses screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AssignedCoursesScreen()),
        );
      } else {
        // User is not logged in, navigate to the login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF1C1A5E), // Dark blue background color
        child: Stack(
          children: [
            // Title: "Briffini Academy"
            Positioned(
              top: screenSize.height * 0.08, // Responsive top position
              left: screenSize.width * 0.06, // Responsive left position
              child: Text(
                "Briffini Academy",
                style: GoogleFonts.archivo(
                  fontSize: screenSize.width * 0.11, // Responsive font size
                  height: 1.7, // Line height ratio (82/48)
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Description: "Explore courses to empower you and your peers..."
            Positioned(
              top: screenSize.height * 0.19, // Responsive top position
              left: screenSize.width * 0.11, // Responsive left position
              width: screenSize.width * 0.78, // Responsive width
              child: Text(
                "Explore courses to empower you and your peers with endless knowledge!",
                style: GoogleFonts.inter(
                  fontSize: screenSize.width * 0.042, // Responsive font size
                  height: 1.17, // Line height ratio (21/18)
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Image: Treasure chest
            Positioned(
              top: screenSize.height * 0.36, // Responsive top position
              left: screenSize.width * 0.045, // Responsive left position
              child: Container(
                width: screenSize.width * 0.91, // Responsive width
                height: screenSize.height * 0.31, // Responsive height
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/treasure_chest.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            
            // Loading indicator (from existing functionality)
            Positioned(
              bottom: screenSize.height * 0.15, // Responsive bottom position
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            
            // Footer: "Made with Visily"
            Positioned(
              bottom: screenSize.height * 0.02, // Responsive bottom position
              left: screenSize.width * 0.05, // Responsive left position
              child: Text(
                "Made with Visily",
                style: GoogleFonts.inter(
                  fontSize: screenSize.width * 0.033, // Responsive font size
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 