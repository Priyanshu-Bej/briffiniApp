import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/course_model.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';
import 'module_list_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../utils/route_transitions.dart';

class AssignedCoursesScreen extends StatefulWidget {
  const AssignedCoursesScreen({Key? key}) : super(key: key);

  @override
  _AssignedCoursesScreenState createState() => _AssignedCoursesScreenState();
}

class _AssignedCoursesScreenState extends State<AssignedCoursesScreen> {
  late Future<List<CourseModel>> _coursesFuture;
  late Future<UserModel?> _userFuture;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _userFuture = authService.getUserData();
    });
    
    try {
      final user = await _userFuture;
      if (user != null) {
        setState(() {
          _coursesFuture = firestoreService.getAssignedCourses(user.assignedCourseIds);
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  // Course card with new design
  Widget _buildCourseCard(CourseModel course, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double cardHeight = screenSize.height * 0.08; // Responsive height
    
    return Container(
      width: screenSize.width * 0.9,
      height: cardHeight,
      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF656BE9),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26171A1F),
            offset: Offset(0, 8),
            blurRadius: 17,
          ),
          BoxShadow(
            color: Color(0x1F171A1F),
            offset: Offset(0, 0),
            blurRadius: 2,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          AppNavigator.navigateTo(
            context: context,
            page: ModuleListScreen(course: course),
          );
        },
        child: Stack(
          children: [
            Positioned(
              top: cardHeight * 0.35, // Position vertically centered
              left: screenSize.width * 0.06,
              child: SizedBox(
                width: screenSize.width * 0.8,
                child: Text(
                  course.title,
                  style: GoogleFonts.inter(
                    fontSize: screenSize.width * 0.05, // Responsive font size
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF2E2C6A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: FutureBuilder<UserModel?>(
                future: _userFuture,
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (userSnapshot.hasError) {
                    return Center(
                      child: Text('Error: ${userSnapshot.error}'),
                    );
                  }
                  
                  final user = userSnapshot.data;
                  if (user == null) {
                    return const Center(
                      child: Text('No user data available.'),
                    );
                  }
                  
                  return FutureBuilder<List<CourseModel>>(
                    future: _coursesFuture,
                    builder: (context, courseSnapshot) {
                      if (courseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (courseSnapshot.hasError) {
                        return Center(
                          child: Text('Error: ${courseSnapshot.error}'),
                        );
                      }
                      
                      final courses = courseSnapshot.data ?? [];
                      
                      return Container(
                        width: screenSize.width,
                        height: screenSize.height,
                        color: const Color(0xFFFFFFFF),
                        child: SafeArea(
                          child: Stack(
                            children: [
                              // Welcome Text
                              Positioned(
                                top: screenSize.height * 0.02,
                                left: screenSize.width * 0.05,
                                child: Text(
                                  "Welcome",
                                  style: GoogleFonts.inter(
                                    fontSize: screenSize.width * 0.045,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF171A1F),
                                  ),
                                ),
                              ),
                              
                              // User Profile Card
                              Positioned(
                                top: screenSize.height * 0.06,
                                left: screenSize.width * 0.05,
                                right: screenSize.width * 0.05,
                                child: Container(
                                  width: screenSize.width * 0.9,
                                  height: screenSize.height * 0.13,
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
                                      // User's Name
                                      Positioned(
                                        top: screenSize.height * 0.013,
                                        left: screenSize.width * 0.03,
                                        child: Text(
                                          user.displayName.isNotEmpty ? user.displayName : 'User',
                                          style: GoogleFonts.archivo(
                                            fontSize: screenSize.width * 0.06,
                                            height: 1.4,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFFFFFFF),
                                          ),
                                        ),
                                      ),
                                      // Email
                                      Positioned(
                                        top: screenSize.height * 0.05,
                                        left: screenSize.width * 0.03,
                                        child: SizedBox(
                                          width: screenSize.width * 0.55,
                                          child: Text(
                                            user.email,
                                            style: GoogleFonts.archivo(
                                              fontSize: screenSize.width * 0.04,
                                              height: 1.3,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFFFFFFFF),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      // Role
                                      Positioned(
                                        top: screenSize.height * 0.08,
                                        left: screenSize.width * 0.03,
                                        child: Text(
                                          user.role,
                                          style: GoogleFonts.archivo(
                                            fontSize: screenSize.width * 0.04,
                                            height: 1.3,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFFFFFFF),
                                          ),
                                        ),
                                      ),
                                      // Image
                                      Positioned(
                                        top: screenSize.height * 0.015,
                                        right: screenSize.width * 0.03,
                                        child: Container(
                                          width: screenSize.width * 0.22,
                                          height: screenSize.width * 0.22,
                                          decoration: const BoxDecoration(
                                            image: DecorationImage(
                                              image: AssetImage('assets/images/id.png'),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // My Courses Text
                              Positioned(
                                top: screenSize.height * 0.22,
                                left: screenSize.width * 0.06,
                                child: Text(
                                  "My Courses",
                                  style: GoogleFonts.inter(
                                    fontSize: screenSize.width * 0.06,
                                    height: 0.85,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF3B3974),
                                  ),
                                ),
                              ),
                              
                              // Course List
                              Positioned(
                                top: screenSize.height * 0.27,
                                left: screenSize.width * 0.05,
                                right: screenSize.width * 0.05,
                                bottom: screenSize.height * 0.1, // Leave space for bottom navigation
                                child: courses.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.book_outlined,
                                            size: screenSize.width * 0.2,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: screenSize.height * 0.02),
                                          Text(
                                            'No courses assigned yet',
                                            style: GoogleFonts.inter(
                                              fontSize: screenSize.width * 0.045,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: screenSize.height * 0.01),
                                          Text(
                                            'Contact your administrator for help',
                                            style: GoogleFonts.inter(
                                              fontSize: screenSize.width * 0.04,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.only(bottom: screenSize.height * 0.02),
                                      itemCount: courses.length,
                                      itemBuilder: (context, index) {
                                        return _buildCourseCard(courses[index], context);
                                      },
                                    ),
                              ),
                              
                              // Footer: "Made with Visily"
                              Positioned(
                                bottom: screenSize.height * 0.02,
                                left: screenSize.width * 0.05,
                                child: Text(
                                  "Made with Visily",
                                  style: GoogleFonts.inter(
                                    fontSize: screenSize.width * 0.035,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF171A1F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
      bottomNavigationBar: Container(
        width: screenSize.width * 0.8,
        height: screenSize.height * 0.07,
        margin: EdgeInsets.only(
          left: screenSize.width * 0.1,
          right: screenSize.width * 0.1,
          bottom: screenSize.height * 0.02,
          top: screenSize.height * 0.01,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(screenSize.width * 0.08),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26171A1F),
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Color(0x1F171A1F),
              offset: Offset(0, 0),
              blurRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(screenSize.width * 0.08),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home, size: screenSize.width * 0.07),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, size: screenSize.width * 0.07),
                label: '',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFF778FF0),
            unselectedItemColor: const Color(0xFF565E6C),
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
              if (index == 1) {
                AppNavigator.navigateTo(
                  context: context,
                  page: const ProfileScreen(),
                );
              }
            },
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