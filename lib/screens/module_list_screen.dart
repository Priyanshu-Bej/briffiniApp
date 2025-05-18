import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_model.dart';
import '../models/module_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';
import 'content_viewer_screen.dart';
import 'profile_screen.dart';
import '../utils/route_transitions.dart';

class ModuleListScreen extends StatefulWidget {
  final CourseModel course;

  const ModuleListScreen({Key? key, required this.course}) : super(key: key);

  @override
  _ModuleListScreenState createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  late Future<List<ModuleModel>> _modulesFuture;
  bool _isLoading = true;
  int _selectedIndex = 0; // For bottom navigation

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _modulesFuture = firestoreService.getModules(widget.course.id);
    });
    
    try {
      await _modulesFuture;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<ModuleModel>>(
              future: _modulesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final modules = snapshot.data ?? [];
                
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadModules,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            // Header with user name (course title)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1A5E), // Dark blue background
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  widget.course.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Module list
                            modules.isEmpty
                                ? Expanded(
                                    child: Center(
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
                                            'No modules available for this course.',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Expanded(
                                    child: ListView.builder(
                                      // Add bottom padding to make room for the floating nav bar
                                      padding: const EdgeInsets.only(bottom: 70),
                                      itemCount: modules.length,
                                      itemBuilder: (context, index) {
                                        final module = modules[index];
                                        return Card(
                                          elevation: 2,
                                          margin: const EdgeInsets.only(bottom: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            side: const BorderSide(color: Color(0xFF323483), width: 0.5),
                                          ),
                                          child: InkWell(
                                            onTap: () {
                                              // Use smooth transitions
                                              AppNavigator.navigateTo(
                                                context: context,
                                                page: ContentViewerScreen(
                                                  course: widget.course,
                                                  module: module,
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          module.title,
                                                          style: const TextStyle(
                                                            fontSize: 16, 
                                                            fontWeight: FontWeight.bold
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.black,
                                                    size: 30,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Floating navigation bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 30,
                      child: Center(
                        child: Container(
                          width: 180,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.home,
                                  color: _selectedIndex == 0 ? Colors.blue : Colors.grey,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: Icon(
                                  Icons.person,
                                  color: _selectedIndex == 1 ? Colors.blue : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedIndex = 1;
                                  });
                                  // Navigate to profile screen with smooth animation
                                  AppNavigator.navigateTo(
                                    context: context,
                                    page: const ProfileScreen(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
} 