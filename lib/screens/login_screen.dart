import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'assigned_courses_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AssignedCoursesScreen()),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    // Calculate field heights based on screen size
    final fieldHeight = screenSize.height * 0.065;
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Container(
            width: screenSize.width,
            height: screenSize.height,
            color: const Color(0xFF1C1A5E), // Background color for top section
            child: Stack(
              children: [
                // White container with rounded top corners
                Positioned(
                  top: screenSize.height * 0.37, // Responsive position
                  left: 0,
                  child: Container(
                    width: screenSize.width,
                    height: screenSize.height * 0.63,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(screenSize.width * 0.04),
                        topRight: Radius.circular(screenSize.width * 0.04),
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
                  ),
                ),
                
                // Title: "Briffini Academy"
                Positioned(
                  top: safeAreaTop + screenSize.height * 0.05, // Adjust for safe area
                  left: screenSize.width * 0.07,
                  child: Text(
                    "Briffini Academy",
                    style: GoogleFonts.archivo(
                      fontSize: screenSize.width * 0.09, // Responsive font size
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                
                // Image: Treasure chest
                Positioned(
                  top: safeAreaTop + screenSize.height * 0.01, // Adjust with safe area
                  left: screenSize.width * 0.15,
                  right: screenSize.width * 0.15,
                  child: Container(
                    height: screenSize.height * 0.2, // Responsive height
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('assets/images/treasure_chest.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                
                // "Explore courses" text - adding this from the splash screen
                Positioned(
                  top: safeAreaTop + screenSize.height * 0.15,
                  left: screenSize.width * 0.07,
                  right: screenSize.width * 0.07,
                  child: Text(
                    "Explore courses to empower you and your peers with endless knowledge!",
                    style: GoogleFonts.inter(
                      fontSize: screenSize.width * 0.043,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFFFFFF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Email Text Field
                Positioned(
                  top: screenSize.height * 0.25, // Responsive position
                  left: screenSize.width * 0.06,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Email",
                        style: GoogleFonts.inter(
                          fontSize: screenSize.width * 0.045,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF171A1F),
                        ),
                      ),
                      SizedBox(height: screenSize.height * 0.01),
                      SizedBox(
                        width: screenSize.width * 0.88, // Responsive width
                        height: fieldHeight,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.inter(
                            fontSize: screenSize.width * 0.045,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF171A1F),
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.05,
                              vertical: fieldHeight * 0.3,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(screenSize.width * 0.01),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(screenSize.width * 0.01),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(screenSize.width * 0.01),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            hoverColor: const Color(0xFF4850E4),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Password Text Field
                Positioned(
                  top: screenSize.height * 0.35, // Responsive position
                  left: screenSize.width * 0.06,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Password",
                        style: GoogleFonts.inter(
                          fontSize: screenSize.width * 0.045,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF171A1F),
                        ),
                      ),
                      SizedBox(height: screenSize.height * 0.01),
                      SizedBox(
                        width: screenSize.width * 0.88, // Responsive width
                        height: fieldHeight,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: GoogleFonts.inter(
                            fontSize: screenSize.width * 0.045,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF171A1F),
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.05,
                              vertical: fieldHeight * 0.3,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(screenSize.width * 0.01),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(screenSize.width * 0.01),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(screenSize.width * 0.01),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            hoverColor: const Color(0xFF4850E4),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF171A1F),
                                size: screenSize.width * 0.06,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Error message display
                if (_errorMessage.isNotEmpty)
                  Positioned(
                    top: screenSize.height * 0.46,
                    left: screenSize.width * 0.06,
                    right: screenSize.width * 0.06,
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: screenSize.width * 0.035,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Sign In Button
                Positioned(
                  top: screenSize.height * 0.5, // Responsive position
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: screenSize.width * 0.55, // Responsive width
                      height: screenSize.height * 0.065, // Responsive height
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF323483),
                          foregroundColor: const Color(0xFF202155), // Hover color
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.05,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(screenSize.width * 0.035),
                          ),
                          elevation: 3,
                        ),
                        child: _isLoading
                          ? SizedBox(
                              height: screenSize.width * 0.06,
                              width: screenSize.width * 0.06,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              "Sign In",
                              style: GoogleFonts.inter(
                                fontSize: screenSize.width * 0.06,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFFFFFFF),
                              ),
                            ),
                      ),
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
                        color: const Color(0xFF171A1F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
