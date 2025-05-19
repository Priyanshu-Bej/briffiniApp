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

    return Scaffold(
      backgroundColor: const Color(0xFF1C1A5E),
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: const Color(0xFF1C1A5E),
        child: Stack(
          children: [
            // Title: "Briffini Academy"
            Positioned(
              top: screenSize.height * 0.12,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
                child: Text(
                  "Briffini Academy",
                  style: GoogleFonts.archivo(
                    fontSize: screenSize.width * 0.11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Tagline Text
            Positioned(
              top: screenSize.height * 0.22,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
                child: Text(
                  "Explore courses to empower you and your peers with endless knowledge!",
                  style: GoogleFonts.inter(
                    fontSize: screenSize.width * 0.045,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Treasure Chest Image - centered in the middle
            Center(
              child: Container(
                width: screenSize.width * 0.7,
                height: screenSize.width * 0.7,
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
              bottom: safeAreaBottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Made with ",
                      style: TextStyle(
                        fontSize: screenSize.width * 0.035,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[400],
                      ),
                    ),
                    Text(
                      "Visily",
                      style: TextStyle(
                        fontSize: screenSize.width * 0.035,
                        fontWeight: FontWeight.w600,
                        color: Colors.lightBlue[300],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 