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
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: const Color(0xFF1C1A5E),
        child: Stack(
          children: [
            // Title: "Briffini Academy"
            Positioned(
              top: safeAreaTop + screenSize.height * 0.08,
              left: screenSize.width * 0.07,
              right: screenSize.width * 0.07,
              child: Text(
                "Briffini Academy",
                style: GoogleFonts.archivo(
                  fontSize: screenSize.width * 0.11,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
            
            // Tagline Text
            Positioned(
              top: safeAreaTop + screenSize.height * 0.18,
              left: screenSize.width * 0.07,
              right: screenSize.width * 0.07,
              child: Text(
                "Explore courses to empower you and your peers with endless knowledge!",
                style: GoogleFonts.inter(
                  fontSize: screenSize.width * 0.045,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
            
            // Treasure Chest Image
            Positioned(
              top: screenSize.height * 0.35,
              left: screenSize.width * 0.1,
              right: screenSize.width * 0.1,
              child: Container(
                height: screenSize.width * 0.8,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/treasure_chest.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // Loading indicator
            Positioned(
              bottom: safeAreaBottom + screenSize.height * 0.08,
              left: 0,
              right: 0,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
            
            // Footer: "Made with Visily"
            Positioned(
              bottom: safeAreaBottom + screenSize.height * 0.02,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Made with Visily",
                  style: GoogleFonts.inter(
                    fontSize: screenSize.width * 0.035,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 