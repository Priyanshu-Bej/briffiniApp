import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/auth_persistence_service.dart';
import '../utils/logger.dart';
import 'assigned_courses_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    Logger.i("🔐 LoginScreen: initState called");

    // Force first frame render for iOS Simulator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Logger.i(
          "🔐 LoginScreen: Post-frame callback - ensuring visual update",
        );
        // Force the renderer to schedule a frame
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    });
  }

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
        // Store context before async operation and create a flag to track if navigation is needed
        final scaffoldContext = context;
        Logger.i("🔐 LoginScreen: Attempting to get AuthService from Provider");
        final authService = Provider.of<AuthService>(
          scaffoldContext,
          listen: false,
        );
        Logger.i("🔐 LoginScreen: AuthService obtained successfully");
        bool shouldNavigateToHome = false;

        // Try to sign in with Firebase
        final userCredential = await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        // If widget is unmounted at this point, don't continue with UI operations
        if (!mounted) return;

        // Force a token refresh to get the latest custom claims
        await authService.forceTokenRefresh();

        // Get the custom claims for logging/debugging
        final claims = await authService.getCustomClaims();
        Logger.i("User claims after login: $claims");

        // Check login status and set navigation flag instead of navigating directly
        bool isLoggedInViaToken = authService.isUserLoggedIn;
        bool hasPersistedToken = await AuthPersistenceService.isLoggedIn();
        shouldNavigateToHome = isLoggedInViaToken || hasPersistedToken;

        // If the widget is no longer in the tree, don't try to update the UI
        if (!mounted) return;

        if (shouldNavigateToHome) {
          // Use WidgetsBinding.instance.addPostFrameCallback to safely navigate after the current frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(scaffoldContext).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const AssignedCoursesScreen(),
                ),
              );
            }
          });
        } else if (userCredential == null) {
          // Handle the specific error case where login partially succeeded
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Login partial success. Please restart the app to complete login.';
          });
        }
      } catch (e) {
        // Only update state if still mounted
        if (!mounted) return;

        // Create a more user-friendly error message
        String errorMsg = e.toString();

        if (errorMsg.contains("Firebase Auth is not available")) {
          errorMsg =
              "Unable to connect to authentication service. Please check your internet connection.";
        } else if (errorMsg.contains("user-not-found")) {
          errorMsg =
              "No account found with this email. Please check your email or register.";
        } else if (errorMsg.contains("wrong-password")) {
          errorMsg = "Incorrect password. Please try again.";
        } else if (errorMsg.contains("too-many-requests")) {
          errorMsg = "Too many login attempts. Please try again later.";
        } else if (errorMsg.contains("network-request-failed")) {
          errorMsg = "Network error. Please check your internet connection.";
        }

        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Logger.i("🔐 LoginScreen: build method called");
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    Logger.i(
      "🔐 LoginScreen: Screen size: ${screenSize.width}x${screenSize.height}",
    );

    // Increase field height for better visibility and prevent shrinking
    final fieldHeight = screenSize.height * 0.075;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1A5E),
      body: SafeArea(
        // Don't add padding at the top to allow the blue background to extend fully
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Container(
              width: screenSize.width,
              // Adjust the height to account for status bar and bottom safe area
              height: screenSize.height,
              color: const Color(
                0xFF1C1A5E,
              ), // Background color for top section
              child: Stack(
                children: [
                  // White container with rounded top corners - positioned to match design
                  Positioned(
                    top: screenSize.height * 0.42,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                        boxShadow: [
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
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(
                            0.2,
                          ), // Debug background
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            0.1,
                          ), // Fallback background
                          borderRadius: BorderRadius.circular(20),
                          image: const DecorationImage(
                            image: AssetImage(
                              'assets/images/treasure_chest.png',
                            ),
                            fit: BoxFit.contain,
                            onError: null, // Handle missing image gracefully
                          ),
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 60,
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
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
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
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(
                            26,
                          ), // 0.1 opacity = 26 alpha (255 * 0.1)
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.red.withAlpha(
                              128,
                            ), // 0.5 opacity = 128 alpha (255 * 0.5)
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: screenSize.width * 0.05,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: screenSize.width * 0.035,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                        child:
                            _isLoading
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

                  // Add bottom padding to ensure content is properly spaced from bottom edge
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: safeAreaBottom > 0 ? safeAreaBottom : 20,
                    ),
                  ),

                  // Debug indicator - visible red dot to confirm rendering
                  Positioned(
                    top: 50,
                    right: 20,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          "●",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Logger.i(
      "🔐 LoginScreen: didChangeDependencies called - widget should be visible",
    );
  }
}
