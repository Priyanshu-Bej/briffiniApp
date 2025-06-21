import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          child: SingleChildScrollView(
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
          ),
        ),
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
}
