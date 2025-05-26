import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'assigned_courses_screen.dart';
import '../utils/route_transitions.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 1; // Profile tab selected by default

  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();

    if (!mounted) return;

    // Clear entire navigation stack and navigate to login screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, // This prevents going back
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // Home tab - navigate to home screen safely
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AssignedCoursesScreen()),
        (route) => false, // This clears the navigation stack
      );
    }
    // Index 1 is profile tab - already on this screen
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    // Get screen dimensions for responsiveness
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.white,
        child: Stack(
          children: [
            // Main content with padding
            Padding(
              padding: EdgeInsets.only(
                top: safeAreaTop + 16,
                bottom: safeAreaBottom + 80, // Space for bottom nav
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User Profile Card
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.05,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: screenSize.height * 0.18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF323483),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFC9C8D8),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F171A1F),
                            offset: Offset(0, 0),
                            blurRadius: 2,
                          ),
                          BoxShadow(
                            color: Color(0x12171A1F),
                            offset: Offset(0, 0),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // User icon
                          Positioned(
                            top: screenSize.height * 0.045,
                            left: screenSize.width * 0.05,
                            child: Icon(
                              Icons.account_circle,
                              size: screenSize.width * 0.12,
                              color: Colors.white,
                            ),
                          ),

                          // User's name
                          Positioned(
                            top: screenSize.height * 0.05,
                            left: screenSize.width * 0.2,
                            child: Text(
                              currentUser?.displayName ?? "User",
                              style: GoogleFonts.archivo(
                                fontSize: screenSize.width * 0.06,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // Email
                          Positioned(
                            top: screenSize.height * 0.09,
                            left: screenSize.width * 0.2,
                            child: Text(
                              currentUser?.email ?? "user@example.com",
                              style: GoogleFonts.inter(
                                fontSize: screenSize.width * 0.04,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.03),

                  // Chat Card
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.05,
                    ),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: const Color(0xFFC9C8D8),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF323483).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            color: const Color(0xFF323483),
                            size: screenSize.width * 0.06,
                          ),
                        ),
                        title: Text(
                          'Chat',
                          style: GoogleFonts.inter(
                            fontSize: screenSize.width * 0.045,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF323483),
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: const Color(0xFF323483),
                          size: screenSize.width * 0.05,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.03),

                  // Log Out Button
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF323483),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.08,
                        vertical: screenSize.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      "Log Out",
                      style: GoogleFonts.inter(
                        fontSize: screenSize.width * 0.04,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(
          left: screenSize.width * 0.05,
          right: screenSize.width * 0.05,
          bottom: safeAreaBottom + 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home, size: 28),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, size: 28),
                label: '',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFF778FF0),
            unselectedItemColor: const Color(0xFF565E6C),
            onTap: _onItemTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 0,
            unselectedFontSize: 0,
            showSelectedLabels: false,
            showUnselectedLabels: false,
          ),
        ),
      ),
    );
  }
}
