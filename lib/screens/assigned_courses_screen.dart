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
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    setState(() {
      _isLoading = true;
      _userFuture = authService.getUserData();
    });

    try {
      final user = await _userFuture;
      if (user != null) {
        // Only fetch courses that are assigned to the student
        if (user.assignedCourseIds.isNotEmpty) {
          setState(() {
            _coursesFuture = firestoreService.getAssignedCourses(
              user.assignedCourseIds,
            );
          });
        } else {
          // No courses assigned to this user
          setState(() {
            _coursesFuture = Future.value([]);
          });
        }
      } else {
        // Handle case where user is null
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user data. Please try again.'),
          ),
        );
      }
    } catch (e) {
      print("Error loading data: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  // Course card with new design to match the original
  Widget _buildCourseCard(CourseModel course, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Container(
      width: screenSize.width * 0.9,
      height: 60,
      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF656BE9), width: 1),
      ),
      child: InkWell(
        onTap: () {
          AppNavigator.navigateTo(
            context: context,
            page: ModuleListScreen(course: course),
          );
        },
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                course.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF2E2C6A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: FutureBuilder<UserModel?>(
                  future: _userFuture,
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
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
                        if (courseSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (courseSnapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 80,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Error loading courses',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  courseSnapshot.error.toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: Text('Try Again'),
                                ),
                              ],
                            ),
                          );
                        }

                        final courses = courseSnapshot.data ?? [];

                        return SafeArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 16),

                                // Welcome Text
                                Text(
                                  "Welcome",
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),

                                SizedBox(height: 12),

                                // User Profile Card
                                Container(
                                  width: double.infinity,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF323483),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Stack(
                                    children: [
                                      // User's Name
                                      Positioned(
                                        top: 16,
                                        left: 20,
                                        child: Text(
                                          user.displayName,
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Email
                                      Positioned(
                                        top: 48,
                                        left: 20,
                                        child: Text(
                                          user.email,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Role
                                      Positioned(
                                        top: 70,
                                        left: 20,
                                        child: Text(
                                          user.role,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // ID Card Image
                                      Positioned(
                                        top: 10,
                                        right: 20,
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: const BoxDecoration(
                                            image: DecorationImage(
                                              image: AssetImage(
                                                'assets/images/id.png',
                                              ),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 24),

                                // My Courses Text
                                Text(
                                  "My Courses",
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF3B3974),
                                  ),
                                ),

                                SizedBox(height: 16),

                                // Course List
                                Expanded(
                                  child:
                                      courses.isEmpty
                                          ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.book_outlined,
                                                  size: 80,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(height: 16),
                                                Text(
                                                  'No courses assigned yet',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 18,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          : ListView.builder(
                                            padding: EdgeInsets.only(
                                              bottom: 100,
                                            ),
                                            itemCount:
                                                courses
                                                    .length, // Show all courses instead of just one
                                            itemBuilder: (context, index) {
                                              return _buildCourseCard(
                                                courses[index],
                                                context,
                                              );
                                            },
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
        margin: EdgeInsets.only(left: 20, right: 20, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
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
            unselectedItemColor: Colors.grey[400],
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
            backgroundColor: Colors.white,
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
