import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    // Color Scheme:
    // - Background: #1C1A5E (Dark Blue)
    // - Text (Title, Description, Footer): #FFFFFF (White)
    // - Treasure Chest:
    //   - Wooden Part: #4A4E6B (Dark Blue-Gray)
    //   - Metal Parts: #A0A4B5 (Metallic Gray)
    // - Book Pages: #D9C2E6 (Light Pinkish-Purple)
    // - Glow Effect: #636AE8 (Bright Blue)
    // - Floating Gems/Stars: #A48EEB (Light Purple), #7A5DE1 (Darker Purple)
    // - Base Circle: #8F7BE3 (Purple)

    return Scaffold(
      backgroundColor: const Color(0xFF1C1A5E),
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: const Color(0xFF1C1A5E), // Background color
        child: Stack(
          children: [
            // Title: "Briffini Academy"
            Positioned(
              top: safeAreaTop + screenSize.height * 0.05,
              left: screenSize.width * 0.06,
              child: Text(
                "Briffini Academy",
                style: GoogleFonts.archivo(
                  fontSize: screenSize.width * 0.09,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
            
            // Description: "Explore courses to empower you and your peers..."
            Positioned(
              top: safeAreaTop + screenSize.height * 0.14,
              left: screenSize.width * 0.11,
              width: screenSize.width * 0.78,
              child: Text(
                "Explore courses to empower you and your peers with endless knowledge!",
                style: GoogleFonts.inter(
                  fontSize: screenSize.width * 0.04,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
            
            // Image: Treasure chest - centered
            Center(
              child: Container(
                width: screenSize.width * 0.8,
                height: screenSize.width * 0.6,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/treasure_chest.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // Loading indicator near bottom
            Positioned(
              bottom: screenSize.height * 0.1,
              left: 0,
              right: 0,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            
            // Footer: "Made with Visily"
            Positioned(
              bottom: safeAreaBottom + screenSize.height * 0.02,
              left: screenSize.width * 0.05,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Made with ",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                  Text(
                    "Visily",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.lightBlue[300],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 