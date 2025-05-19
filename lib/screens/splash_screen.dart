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
    final isSmallScreen = screenSize.height < 700; // For extra small devices
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF1C1A5E), // Dark blue background color
        // Use SafeArea to avoid system UI overlaps
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Title: "Briffini Academy"
                  Positioned(
                    top: constraints.maxHeight * (isSmallScreen ? 0.05 : 0.08),
                    left: constraints.maxWidth * 0.06,
                    right: constraints.maxWidth * 0.06,
                    child: Text(
                      "Briffini Academy",
                      style: GoogleFonts.archivo(
                        fontSize: constraints.maxWidth * (isSmallScreen ? 0.09 : 0.11),
                        height: 1.4, // Reduced line height for better fit
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Description: "Explore courses to empower you and your peers..."
                  Positioned(
                    top: constraints.maxHeight * (isSmallScreen ? 0.15 : 0.19),
                    left: constraints.maxWidth * 0.08,
                    right: constraints.maxWidth * 0.08,
                    child: Text(
                      "Explore courses to empower you and your peers with endless knowledge!",
                      style: GoogleFonts.inter(
                        fontSize: constraints.maxWidth * (isSmallScreen ? 0.035 : 0.042),
                        height: 1.17,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Image: Treasure chest
                  Positioned(
                    top: constraints.maxHeight * (isSmallScreen ? 0.25 : 0.3),
                    left: constraints.maxWidth * 0.045,
                    right: constraints.maxWidth * 0.045,
                    child: Container(
                      width: constraints.maxWidth * 0.91,
                      height: constraints.maxHeight * (isSmallScreen ? 0.35 : 0.4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/treasure_chest.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  
                  // Loading indicator
                  Positioned(
                    bottom: constraints.maxHeight * (isSmallScreen ? 0.1 : 0.15),
                    left: 0,
                    right: 0,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                  
                  // Footer: "Made with Visily"
                  Positioned(
                    bottom: constraints.maxHeight * 0.02,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "Made with Visily",
                        style: GoogleFonts.inter(
                          fontSize: constraints.maxWidth * 0.033,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
} 