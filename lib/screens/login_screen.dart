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
    
    // Increase field height for better visibility and prevent shrinking
    final fieldHeight = screenSize.height * 0.075;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1C1A5E),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Container(
            width: screenSize.width,
            height: screenSize.height,
            color: const Color(0xFF1C1A5E), // Background color for top section
            child: Stack(
              children: [
                // White container with rounded top corners - positioned to match design
                Positioned(
                  top: screenSize.height * 0.42,
                  left: 0,
                  right: 0,
                  child: Container(
                    width: screenSize.width,
                    height: screenSize.height * 0.58,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F171A1F),
                          offset: Offset(0, -3),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Title: "Briffini Academy"
                Positioned(
                  top: screenSize.height * 0.08,
                  left: 0,
                  right: 0,
                  child: Center(
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
                
                // Image: Treasure chest - positioned higher to match design
                Positioned(
                  top: screenSize.height * 0.16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: screenSize.width * 0.5,
                      height: screenSize.width * 0.5,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/treasure_chest.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Email Text Field - positioned in white container
                Positioned(
                  top: screenSize.height * 0.45,
                  left: screenSize.width * 0.06,
                  right: screenSize.width * 0.06,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Email",
                        style: GoogleFonts.inter(
                          fontSize: screenSize.width * 0.045,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF171A1F),
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        height: fieldHeight,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            fontSize: screenSize.width * 0.045,
                            color: const Color(0xFF171A1F),
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.04,
                              vertical: fieldHeight * 0.25,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorStyle: TextStyle(
                              color: Colors.red,
                              fontSize: screenSize.width * 0.035,
                              height: 0.5,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
                
                // Password Text Field
                Positioned(
                  top: screenSize.height * 0.57,
                  left: screenSize.width * 0.06,
                  right: screenSize.width * 0.06,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Password",
                        style: GoogleFonts.inter(
                          fontSize: screenSize.width * 0.045,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF171A1F),
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        height: fieldHeight,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: TextStyle(
                            fontSize: screenSize.width * 0.045,
                            color: const Color(0xFF171A1F),
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.04,
                              vertical: fieldHeight * 0.25,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF636AE8),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorStyle: TextStyle(
                              color: Colors.red,
                              fontSize: screenSize.width * 0.035,
                              height: 0.5,
                            ),
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
                      SizedBox(height: 8),
                    ],
                  ),
                ),
                
                // Error message display
                if (_errorMessage.isNotEmpty)
                  Positioned(
                    top: screenSize.height * 0.67,
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
                
                // Sign In Button - styled to match design
                Positioned(
                  top: screenSize.height * 0.71,
                  left: screenSize.width * 0.06,
                  right: screenSize.width * 0.06,
                  child: SizedBox(
                    width: double.infinity,
                    height: fieldHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF323483),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
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
                              fontSize: screenSize.width * 0.045,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFFFFF),
                            ),
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
