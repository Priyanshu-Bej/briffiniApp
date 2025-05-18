import 'package:flutter/material.dart';
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
  final TextEditingController _emailController = TextEditingController(text: 'winner@email.com');
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      final userCredential = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Even if userCredential is null due to our Firebase Auth error handling,
      // we'll continue and try to navigate to courses screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AssignedCoursesScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenSize = MediaQuery.of(context).size;
    final headerHeight = screenSize.height * 0.25;  // 25% of screen height
    
    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView( // Added for scrollability on smaller screens
          child: Column(
            children: [
              // Header section with dark blue background
              Container(
                width: double.infinity,
                height: headerHeight,
                color: const Color(0xFF1C1A5E), // Dark blue background
                child: Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: Center(
                    child: Text(
                      'Briffini Academy',
                      style: TextStyle(
                        fontSize: screenSize.width * 0.08, // Responsive font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Treasure chest image
              Transform.translate(
                offset: Offset(0, -headerHeight * 0.3), // Position relative to header height
                child: Container(
                  width: screenSize.width * 0.6, // 60% of screen width
                  height: screenSize.width * 0.45, // 45% of screen width (maintain aspect ratio)
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  // Replace the placeholder with the actual image
                  child: Image.asset(
                    'assets/images/treasure_chest.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Adjust spacing to account for overlapping image
              SizedBox(height: -(headerHeight * 0.2)),
              // Login form
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF6B38FB),
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                          tooltip: 'Toggle password visibility',
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: screenSize.width * 0.7, // 70% of screen width
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B38FB), // Purple button color
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              // Add flexible space that expands to fill available space
              SizedBox(height: screenSize.height * 0.05),
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Made with Visily',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom), // Bottom padding for notches
            ],
          ),
        ),
      ),
    );
  }
}
