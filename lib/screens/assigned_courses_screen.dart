import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/course_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';
import '../utils/logger.dart';
import '../utils/responsive_helper.dart';
import '../utils/route_transitions.dart';
import '../widgets/custom_bottom_navigation.dart';
import 'module_list_screen.dart';

class AssignedCoursesScreen extends StatefulWidget {
  const AssignedCoursesScreen({super.key});

  @override
  State<AssignedCoursesScreen> createState() => _AssignedCoursesScreenState();
}

class _AssignedCoursesScreenState extends State<AssignedCoursesScreen>
    with WidgetsBindingObserver {
  late Future<List<CourseModel>> _coursesFuture;
  late Future<UserModel?> _userFuture;
  bool _isLoading = true;
  int _selectedIndex = 0;
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    Logger.i("🚀 AssignedCoursesScreen: initState called");
    WidgetsBinding.instance.addObserver(this);

    // Use post-frame callback to ensure the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.i("🚀 AssignedCoursesScreen: Post-frame callback triggered");

      // Force first frame render for iOS Simulator
      if (mounted) {
        Logger.i("🚀 AssignedCoursesScreen: Ensuring visual update");
        WidgetsBinding.instance.ensureVisualUpdate();
      }

      if (mounted && !_hasLoadedData) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    Logger.i("📱 AssignedCoursesScreen: App lifecycle changed to $state");

    if (state == AppLifecycleState.resumed && mounted && !_hasLoadedData) {
      Logger.i("🔄 AssignedCoursesScreen: App resumed, retrying data load");
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted || _hasLoadedData) {
      Logger.w(
        "⚠️ AssignedCoursesScreen: Skipping _loadData (mounted: $mounted, hasLoadedData: $_hasLoadedData)",
      );
      return;
    }

    Logger.i("🔄 AssignedCoursesScreen: Starting _loadData");

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      // Wait for Firebase Auth session to be fully ready
      Logger.i("Waiting for Firebase Auth session to be ready...");
      int attempts = 0;
      const maxAttempts = 20; // 10 seconds maximum wait

      while (authService.currentUser == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        Logger.d("Waiting for auth session... attempt $attempts/$maxAttempts");
      }

      if (authService.currentUser == null) {
        Logger.e(
          "Auth session not ready after ${maxAttempts * 500}ms, proceeding anyway",
        );
      } else {
        Logger.i("Auth session ready, user: ${authService.currentUser?.uid}");
      }

      // Get assigned course IDs directly from custom claims
      final assignedCourseIds = await authService.getAssignedCourseIds();
      Logger.i("📚 Assigned course IDs: $assignedCourseIds");

      // Also get user data for display purposes
      final user = await authService.getUserData();
      Logger.i("👤 User data loaded: ${user?.displayName} (${user?.email})");

      setState(() {
        _userFuture = Future.value(user);

        if (assignedCourseIds.isNotEmpty) {
          Logger.i("🔄 Fetching courses from Firestore...");
          _coursesFuture = firestoreService.getAssignedCourses(
            assignedCourseIds,
          );
        } else {
          Logger.w("⚠️ No courses assigned to this user");
          _coursesFuture = Future.value([]);
        }
      });
    } catch (e) {
      Logger.e("Error loading data: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        Logger.i("✅ AssignedCoursesScreen: Data loading completed, showing UI");
        setState(() {
          _isLoading = false;
          _hasLoadedData =
              true; // Mark data as loaded to prevent duplicate calls
        });
      }
    }
  }

  // Course card with responsive design for all iPhone models including iPhone 16 lineup
  Widget _buildCourseCard(CourseModel course, BuildContext context) {
    final horizontalPadding = ResponsiveHelper.getScreenHorizontalPadding(
      context,
    );
    final cardSpacing = ResponsiveHelper.getAdaptiveSpacing(
      context,
      compact: 12.0,
      regular: 16.0,
      pro: 18.0,
      large: 20.0,
      extraLarge: 24.0,
    );
    final borderRadius = ResponsiveHelper.getAdaptiveBorderRadius(
      context,
      compact: 8.0,
      regular: 10.0,
      pro: 12.0,
      large: 12.0,
      extraLarge: 14.0,
    );

    return Container(
      width: double.infinity,
      height: ResponsiveHelper.adaptiveFontSize(context, 60.0),
      margin: EdgeInsets.only(bottom: cardSpacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFF656BE9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: ResponsiveHelper.getAdaptiveElevation(context),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () {
            AppNavigator.navigateTo(
              context: context,
              page: ModuleListScreen(course: course),
            );
          },
          child: Container(
            constraints: ResponsiveHelper.getMinTouchTarget(),
            child: Center(
              child: Padding(
                padding: horizontalPadding,
                child: Text(
                  course.title,
                  style: GoogleFonts.inter(
                    fontSize: ResponsiveHelper.adaptiveFontSize(context, 16.0),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF323483),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading courses...'),
                    ],
                  ),
                ),
              )
              : SafeArea(
                child: RefreshIndicator(
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
                          Logger.i(
                            "📋 Course data received: ${courses.length} courses",
                          );
                          Logger.i(
                            "🎨 AssignedCoursesScreen: Building main UI with ${courses.length} courses",
                          );

                          return Container(
                            color: Colors.white, // Failsafe background
                            child: Padding(
                              padding:
                                  ResponsiveHelper.getScreenHorizontalPadding(
                                    context,
                                  ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: ResponsiveHelper.getAdaptiveSpacing(
                                      context,
                                    ),
                                  ),

                                  // Welcome Text
                                  Text(
                                    "Welcome",
                                    style: GoogleFonts.inter(
                                      fontSize:
                                          ResponsiveHelper.adaptiveFontSize(
                                            context,
                                            24.0,
                                          ),
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),

                                  SizedBox(
                                    height: ResponsiveHelper.getAdaptiveSpacing(
                                      context,
                                      compact: 8.0,
                                      regular: 12.0,
                                      large: 16.0,
                                    ),
                                  ),

                                  // User Profile Card with responsive design
                                  Container(
                                    width: double.infinity,
                                    height: ResponsiveHelper.adaptiveFontSize(
                                      context,
                                      100.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF323483),
                                      borderRadius:
                                          ResponsiveHelper.getAdaptiveBorderRadius(
                                            context,
                                          ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // User's Name
                                        Positioned(
                                          top:
                                              ResponsiveHelper.getAdaptiveSpacing(
                                                context,
                                              ),
                                          left:
                                              ResponsiveHelper.getAdaptiveSpacing(
                                                context,
                                                compact: 16.0,
                                                regular: 20.0,
                                                large: 24.0,
                                              ),
                                          child: Text(
                                            user.displayName,
                                            style: GoogleFonts.inter(
                                              fontSize:
                                                  ResponsiveHelper.adaptiveFontSize(
                                                    context,
                                                    20.0,
                                                  ),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),

                                        // Email
                                        Positioned(
                                          top:
                                              ResponsiveHelper.adaptiveFontSize(
                                                context,
                                                44.0,
                                              ),
                                          left:
                                              ResponsiveHelper.getAdaptiveSpacing(
                                                context,
                                                compact: 16.0,
                                                regular: 20.0,
                                                large: 24.0,
                                              ),
                                          child: Text(
                                            user.email,
                                            style: GoogleFonts.inter(
                                              fontSize:
                                                  ResponsiveHelper.adaptiveFontSize(
                                                    context,
                                                    14.0,
                                                  ),
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),

                                        // Student label
                                        Positioned(
                                          top:
                                              ResponsiveHelper.adaptiveFontSize(
                                                context,
                                                64.0,
                                              ),
                                          left:
                                              ResponsiveHelper.getAdaptiveSpacing(
                                                context,
                                                compact: 16.0,
                                                regular: 20.0,
                                                large: 24.0,
                                              ),
                                          child: Text(
                                            "student",
                                            style: GoogleFonts.inter(
                                              fontSize:
                                                  ResponsiveHelper.adaptiveFontSize(
                                                    context,
                                                    12.0,
                                                  ),
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ),

                                        // Profile icon - positioned responsively
                                        Positioned(
                                          top:
                                              ResponsiveHelper.getAdaptiveSpacing(
                                                context,
                                              ),
                                          right:
                                              ResponsiveHelper.getAdaptiveSpacing(
                                                context,
                                                compact: 16.0,
                                                regular: 20.0,
                                                large: 24.0,
                                              ),
                                          child: Container(
                                            width:
                                                ResponsiveHelper.adaptiveFontSize(
                                                  context,
                                                  48.0,
                                                ),
                                            height:
                                                ResponsiveHelper.adaptiveFontSize(
                                                  context,
                                                  48.0,
                                                ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                            child: Icon(
                                              Icons.person_outline,
                                              color: Colors.white,
                                              size:
                                                  ResponsiveHelper.adaptiveFontSize(
                                                    context,
                                                    24.0,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(
                                    height: ResponsiveHelper.getAdaptiveSpacing(
                                      context,
                                      compact: 20.0,
                                      regular: 24.0,
                                      pro: 28.0,
                                      large: 32.0,
                                      extraLarge: 36.0,
                                    ),
                                  ),

                                  // My Courses Text with iPhone 16 Pro Max optimization
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "My Courses",
                                        style: GoogleFonts.inter(
                                          fontSize:
                                              ResponsiveHelper.adaptiveFontSize(
                                                context,
                                                20.0,
                                              ),
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF323483),
                                        ),
                                      ),
                                      // Show course count on larger screens
                                      if (ResponsiveHelper.getIPhoneSize(
                                                context,
                                              ) ==
                                              IPhoneSize.extraLarge ||
                                          ResponsiveHelper.getIPhoneSize(
                                                context,
                                              ) ==
                                              IPhoneSize.large)
                                        FutureBuilder<List<CourseModel>>(
                                          future: _coursesFuture,
                                          builder: (context, snapshot) {
                                            final courseCount =
                                                snapshot.data?.length ?? 0;
                                            return Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    ResponsiveHelper.getAdaptiveSpacing(
                                                      context,
                                                      compact: 8.0,
                                                      regular: 10.0,
                                                      pro: 12.0,
                                                      large: 12.0,
                                                      extraLarge: 14.0,
                                                    ),
                                                vertical:
                                                    ResponsiveHelper.getAdaptiveSpacing(
                                                      context,
                                                      compact: 4.0,
                                                      regular: 6.0,
                                                      pro: 6.0,
                                                      large: 6.0,
                                                      extraLarge: 8.0,
                                                    ),
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    ResponsiveHelper.getAdaptiveBorderRadius(
                                                      context,
                                                    ),
                                              ),
                                              child: Text(
                                                '$courseCount ${courseCount == 1 ? 'Course' : 'Courses'}',
                                                style: GoogleFonts.inter(
                                                  fontSize:
                                                      ResponsiveHelper.adaptiveFontSize(
                                                        context,
                                                        12.0,
                                                      ),
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),

                                  SizedBox(
                                    height: ResponsiveHelper.getAdaptiveSpacing(
                                      context,
                                    ),
                                  ),

                                  // Courses List
                                  Expanded(
                                    child:
                                        courses.isEmpty
                                            ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.school_outlined,
                                                    size:
                                                        ResponsiveHelper.adaptiveFontSize(
                                                          context,
                                                          64.0,
                                                        ),
                                                    color: Colors.grey[400],
                                                  ),
                                                  SizedBox(
                                                    height:
                                                        ResponsiveHelper.getAdaptiveSpacing(
                                                          context,
                                                        ),
                                                  ),
                                                  Text(
                                                    'No courses assigned',
                                                    style: GoogleFonts.inter(
                                                      fontSize:
                                                          ResponsiveHelper.adaptiveFontSize(
                                                            context,
                                                            18.0,
                                                          ),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height:
                                                        ResponsiveHelper.getAdaptiveSpacing(
                                                          context,
                                                          compact: 4.0,
                                                          regular: 6.0,
                                                          large: 8.0,
                                                        ),
                                                  ),
                                                  Text(
                                                    'Contact your administrator to get courses assigned.',
                                                    style: GoogleFonts.inter(
                                                      fontSize:
                                                          ResponsiveHelper.adaptiveFontSize(
                                                            context,
                                                            14.0,
                                                          ),
                                                      color: Colors.grey[500],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            )
                                            : ListView.builder(
                                              physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                              itemCount: courses.length,
                                              itemBuilder: (context, index) {
                                                return _buildCourseCard(
                                                  courses[index],
                                                  context,
                                                );
                                              },
                                            ),
                                  ),

                                  // Bottom padding for safe area
                                  SizedBox(
                                    height:
                                        ResponsiveHelper.getBottomSafeAreaHeight(
                                          context,
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
              ),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          CustomBottomNavigation.handleNavigation(context, index);
        },
      ),
    );
  }
}
