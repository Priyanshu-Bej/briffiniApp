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
                  top: screenSize.height * 0.36, // Responsive position
                  left: 0,
                  child: Container(
                    width: screenSize.width,
                    height: screenSize.height * 0.64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      boxShadow: [
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
                  top: screenSize.height * 0.094, // Responsive position
                  left: screenSize.width * 0.07, // Responsive position
                  child: Text(
                    "Briffini Academy",
                    style: GoogleFonts.archivo(
                      fontSize: screenSize.width * 0.11, // Responsive font size
                      height: 1.71,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                
                // Image: Treasure chest
                Positioned(
                  top: screenSize.height * -0.05, // Responsive position
                  left: screenSize.width * 0.05, // Responsive position
                  right: screenSize.width * 0.05, // Responsive position
                  child: Container(
                    height: screenSize.height * 0.3, // Responsive height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/treasure_chest.png'), // Keep existing asset path
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                
                // Email Text Field
                Positioned(
                  top: screenSize.height * 0.2, // Responsive position
                  left: screenSize.width * 0.06, // Responsive position
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Email",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          height: 28 / 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF171A1F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: screenSize.width * 0.88, // Responsive width
                        height: 52,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF171A1F),
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
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
                  top: screenSize.height * 0.3, // Responsive position
                  left: screenSize.width * 0.06, // Responsive position
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Password",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          height: 28 / 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF171A1F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: screenSize.width * 0.88, // Responsive width
                        height: 52,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF171A1F),
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
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
                    top: screenSize.height * 0.38,
                    left: screenSize.width * 0.06,
                    right: screenSize.width * 0.06,
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Sign In Button
                Positioned(
                  top: screenSize.height * 0.43, // Responsive position
                  left: screenSize.width * 0.23, // Responsive position
                  child: SizedBox(
                    width: screenSize.width * 0.55, // Responsive width
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF323483),
                        foregroundColor: const Color(0xFF202155), // Hover color
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Sign In",
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              height: 48 / 32,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                    ),
                  ),
                ),
                
                // Footer: "Made with Visily"
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Text(
                    "Made with Visily",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF171A1F),
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
