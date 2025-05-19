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
    
    AppNavigator.navigateWithFade(
      context: context,
      page: const LoginScreen(),
      replace: true,
    );
  }

  // Course card with new design
  Widget _buildCourseCard(CourseModel course, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Container(
      width: screenSize.width * 0.9,
      height: 75,
      margin: const EdgeInsets.only(bottom: 16),
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
              top: 25,
              left: 26,
              child: Text(
                course.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  height: 26 / 20,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF2E2C6A),
                ),
                overflow: TextOverflow.ellipsis,
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
                        child: Stack(
                          children: [
                            // Welcome Text
                            Positioned(
                              top: screenSize.height * 0.06,
                              left: screenSize.width * 0.05,
                              child: Text(
                                "Welcome",
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF171A1F),
                                ),
                              ),
                            ),
                            
                            // User Profile Card
                            Positioned(
                              top: screenSize.height * 0.1,
                              left: screenSize.width * 0.05,
                              child: Container(
                                width: screenSize.width * 0.9,
                                height: screenSize.height * 0.15,
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
                                      top: 8,
                                      left: 11,
                                      child: Text(
                                        user.displayName.isNotEmpty ? user.displayName : 'User',
                                        style: GoogleFonts.archivo(
                                          fontSize: 24,
                                          height: 42 / 24,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ),
                                    // Email
                                    Positioned(
                                      top: 37,
                                      left: 11,
                                      child: SizedBox(
                                        width: screenSize.width * 0.45,
                                        child: Text(
                                          user.email,
                                          style: GoogleFonts.archivo(
                                            fontSize: 16,
                                            height: 42 / 16,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFFFFFFF),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    // Role
                                    Positioned(
                                      top: 59,
                                      left: 11,
                                      child: Text(
                                        user.role,
                                        style: GoogleFonts.archivo(
                                          fontSize: 16,
                                          height: 42 / 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ),
                                    // Image
                                    Positioned(
                                      top: 11,
                                      right: 11,
                                      child: Container(
                                        width: screenSize.width * 0.28,
                                        height: screenSize.width * 0.28,
                                        decoration: const BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage('assets/images/id.png'), // Keep existing asset
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
                              top: screenSize.height * 0.28,
                              left: screenSize.width * 0.06,
                              child: Text(
                                "My Courses",
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  height: 20 / 24,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF3B3974),
                                ),
                              ),
                            ),
                            
                            // Course List
                            Positioned(
                              top: screenSize.height * 0.32,
                              left: screenSize.width * 0.05,
                              right: screenSize.width * 0.05,
                              bottom: 100, // Leave space for bottom navigation
                              child: courses.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.book_outlined,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No courses assigned yet',
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Contact your administrator for help',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    itemCount: courses.length,
                                    itemBuilder: (context, index) {
                                      return _buildCourseCard(courses[index], context);
                                    },
                                  ),
                            ),
                            
                            // Footer: "Made with Visily"
                            Positioned(
                              bottom: screenSize.height * 0.11,
                              left: screenSize.width * 0.05,
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
                      );
                    },
                  );
                },
              ),
            ),
      bottomNavigationBar: Container(
        width: screenSize.width * 0.82,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(10),
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
        margin: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.09,
          vertical: 10,
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
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
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF35336F),
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            color: const Color(0xFF1C1A5E),
          ),
        ),
      ),
    );
  }
} 