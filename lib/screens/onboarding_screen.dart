import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isFromSettings;

  const OnboardingScreen({super.key, this.isFromSettings = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 2; // Welcome page + Terms page
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();

    // Force immediate UI build for iOS cold start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // Trigger rebuild to ensure UI appears immediately
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // If from settings, show only the terms and conditions text
    if (widget.isFromSettings) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Terms and Conditions'),
          backgroundColor: const Color(0xFF323483),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTermsContent(screenSize),
          ),
        ),
      );
    }

    // Regular onboarding experience
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Page view for onboarding slides
            PageView(
              controller: _pageController,
              physics:
                  _currentPage == 1 && !_termsAccepted
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                // Welcome page
                _buildWelcomePage(screenSize),

                // Terms and conditions page
                _buildTermsPage(screenSize),
              ],
            ),

            // Bottom navigation
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x1A000000),
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _numPages,
                        (index) => _buildDot(index),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back button (if not on first page)
                        _currentPage > 0
                            ? TextButton(
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: const Text(
                                "Back",
                                style: TextStyle(
                                  color: Color(0xFF323483),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            : const SizedBox(
                              width: 80,
                            ), // Empty space if on first page
                        // Continue/Get Started button
                        ElevatedButton(
                          onPressed:
                              _currentPage == _numPages - 1
                                  ? _termsAccepted
                                      ? _completeOnboarding
                                      : null
                                  : () {
                                    _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF323483),
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentPage == _numPages - 1
                                ? "Get Started"
                                : "Continue",
                            style: TextStyle(
                              color:
                                  _currentPage == _numPages - 1 &&
                                          !_termsAccepted
                                      ? Colors.grey.shade500
                                      : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildWelcomePage(Size screenSize) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon or logo
          Container(
            height: screenSize.width * 0.5,
            width: screenSize.width * 0.5,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/logo/app_logo.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Welcome text
          Text(
            "Welcome to Briffini Academy",
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF323483),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // App description
          Text(
            "Your trusted learning companion for nursing students studying abroad.",
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTermsPage(Size screenSize) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        100,
      ), // Extra bottom padding for buttons
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Terms and Conditions",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF323483),
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable terms content
          Expanded(child: _buildTermsContent(screenSize)),

          // Accept checkbox
          if (!widget.isFromSettings)
            Row(
              children: [
                Checkbox(
                  value: _termsAccepted,
                  activeColor: const Color(0xFF323483),
                  onChanged: (value) {
                    setState(() {
                      _termsAccepted = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    "I have read and accept the Terms and Conditions",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTermsContent(Size screenSize) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTermSection(
            "1. For Students Only",
            "This app is for nursing students studying abroad who are 18 years or older.",
          ),
          _buildTermSection(
            "2. Personal Use",
            "Use this app only for your own learning. Don't share your account with others.",
          ),
          _buildTermSection(
            "3. Privacy",
            "We collect your basic details (like name, email) to give you the best learning experience. Your information is safe with us.",
          ),
          _buildTermSection(
            "4. No Copying",
            "All videos, notes, and materials are protected. Don't copy, download, or share them without permission.",
          ),
          _buildTermSection(
            "5. No Cheating",
            "Using this app for cheating or unfair practices is not allowed.",
          ),
          _buildTermSection(
            "6. Account Rules",
            "If you break the rules, your account may be blocked or removed.",
          ),
          _buildTermSection(
            "7. App Availability",
            "Sometimes the app may be down for updates or due to technical issues.",
          ),
          _buildTermSection(
            "8. Updates to Terms",
            "We may update these rules. If you keep using the app, it means you agree to the latest terms.",
          ),
          _buildTermSection(
            "9. Laws",
            "These terms follow the law of the country where our app is managed.",
          ),
        ],
      ),
    );
  }

  Widget _buildTermSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF4D4D4D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color:
            _currentPage == index
                ? const Color(0xFF323483)
                : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    // Save that onboarding is complete and the terms version
    if (!widget.isFromSettings) {
      await prefs.setBool('onboarding_complete', true);
      await prefs.setInt('terms_version', 1); // Set current terms version

      // Navigate to login screen safely with mounted check
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }
}
