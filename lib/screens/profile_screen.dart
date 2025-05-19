import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../utils/route_transitions.dart';

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
  
  void _showChangePasswordDialog() {
    final TextEditingController _currentPasswordController = TextEditingController();
    final TextEditingController _newPasswordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();
    bool _isLoading = false;
    String _errorMessage = '';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF323483),
                    ),
                    onPressed: () async {
                      // Validate inputs
                      if (_currentPasswordController.text.isEmpty ||
                          _newPasswordController.text.isEmpty ||
                          _confirmPasswordController.text.isEmpty) {
                        setState(() {
                          _errorMessage = 'All fields are required';
                        });
                        return;
                      }
                      
                      if (_newPasswordController.text != _confirmPasswordController.text) {
                        setState(() {
                          _errorMessage = 'New passwords do not match';
                        });
                        return;
                      }
                      
                      // Set loading state
                      setState(() {
                        _isLoading = true;
                        _errorMessage = '';
                      });
                      
                      try {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        await authService.changePassword(
                          _currentPasswordController.text,
                          _newPasswordController.text,
                        );
                        
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setState(() {
                          _errorMessage = e.toString();
                          _isLoading = false;
                        });
                      }
                    },
                    child: const Text('Change Password'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 0) {
      // Home tab - navigate back
      Navigator.pop(context);
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
    
    // Color Scheme:
    // - Background: #FFFFFF (White)
    // - User Profile Card:
    //   - Background: #323483 (Dark Blue)
    //   - Border: #C9C8D8 (Light Grayish-Purple)
    //   - Icon: #FFFFFF (White)
    //   - Text: #FFFFFF (White)
    // - Change Password Button:
    //   - Background: #FFFFFF (White)
    //   - Border: #E6E6E6 (Light Gray)
    //   - Icon: #171A1F (Dark Gray)
    //   - Text: #171A1F (Dark Gray)
    // - Log Out Button:
    //   - Background: #323483 (Dark Blue)
    
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
                    padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
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
                              Icons.person_circle,
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
                  
                  // Change Password Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
                    child: InkWell(
                      onTap: _showChangePasswordDialog,
                      child: Container(
                        width: double.infinity,
                        height: screenSize.height * 0.07,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE6E6E6),
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
                        child: Row(
                          children: [
                            SizedBox(width: screenSize.width * 0.05),
                            Icon(
                              Icons.vpn_key,
                              size: screenSize.width * 0.06,
                              color: const Color(0xFF171A1F),
                            ),
                            SizedBox(width: screenSize.width * 0.03),
                            Text(
                              "Change Password",
                              style: GoogleFonts.inter(
                                fontSize: screenSize.width * 0.05,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF171A1F),
                              ),
                            ),
                          ],
                        ),
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
                  
                  const Spacer(),
                  
                  // Footer: "Made with Visily"
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: screenSize.height * 0.02,
                      left: screenSize.width * 0.05,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Made with ",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF171A1F),
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