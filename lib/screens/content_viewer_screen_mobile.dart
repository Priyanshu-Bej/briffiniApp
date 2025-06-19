import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chewie/src/material/material_controls.dart';

import '../models/content_model.dart';
import '../models/course_model.dart';
import '../models/module_model.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/pdf_loader.dart';
import '../widgets/custom_pdf_viewer.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';
import 'profile_screen.dart';
import 'assigned_courses_screen.dart';
import '../utils/route_transitions.dart';
import '../widgets/custom_pdf_viewer.dart';

// Watermark overlay widget for PDFs
class BriffiniWatermark extends StatelessWidget {
  final String userName;

  const BriffiniWatermark({Key? key, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate how many watermarks to show based on screen size
            final double cellWidth = 150;
            final double cellHeight = 150;
            final int horizontalCount =
                (constraints.maxWidth / cellWidth).ceil();
            final int verticalCount =
                (constraints.maxHeight / cellHeight).ceil();

            return Stack(
              children: [
                for (int y = 0; y < verticalCount; y++)
                  for (int x = 0; x < horizontalCount; x++)
                    Positioned(
                      left: x * cellWidth,
                      top: y * cellHeight,
                      child: Opacity(
                        opacity: 0.1,
                        child: Transform.rotate(
                          angle: -0.2,
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF323483),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Full-screen PDF viewer widget
class FullScreenPdfViewer extends StatefulWidget {
  final String filePath;
  final String userName;

  const FullScreenPdfViewer({
    Key? key,
    required this.filePath,
    required this.userName,
  }) : super(key: key);

  @override
  _FullScreenPdfViewerState createState() => _FullScreenPdfViewerState();
}

class _FullScreenPdfViewerState extends State<FullScreenPdfViewer> {
  bool _isFullScreen = true;

  @override
  void initState() {
    super.initState();
    // Enter full-screen mode but keep status bar for better UX
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  @override
  void dispose() {
    // Exit full-screen mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
          _isFullScreen
              ? PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                ),
              )
              : AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                title: const Text('PDF Document'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      setState(() {
                        _isFullScreen = true;
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.manual,
                          overlays: [SystemUiOverlay.top],
                        );
                      });
                    },
                  ),
                ],
              ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isFullScreen = !_isFullScreen;
              if (_isFullScreen) {
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: [SystemUiOverlay.top],
                );
              } else {
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: SystemUiOverlay.values,
                );
              }
            });
          },
          child: Stack(
            children: [
              SizedBox.expand(
                child: CustomPDFViewer(
                  filePath: widget.filePath,
                  userName: widget.userName,
                ),
              ),
              // Overlay for tap detection (GestureDetector wraps the Stack)
              if (!_isFullScreen)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: const Icon(Icons.fullscreen),
                    onPressed: () {
                      setState(() {
                        _isFullScreen = true;
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.manual,
                          overlays: [SystemUiOverlay.top],
                        );
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContentViewerScreen extends StatefulWidget {
  final CourseModel course;
  final ModuleModel module;

  const ContentViewerScreen({
    Key? key,
    required this.course,
    required this.module,
  }) : super(key: key);

  @override
  _ContentViewerScreenState createState() => _ContentViewerScreenState();
}

class _ContentViewerScreenState extends State<ContentViewerScreen>
    with WidgetsBindingObserver {
  late Future<List<ContentModel>> _contentFuture;
  bool _isLoading = true;
  int _currentContentIndex = 0;
  int _selectedIndex = 0; // For bottom navigation
  String _userName = ""; // Store user name

  // Video player controllers
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // PDF state variables
  bool _isPdfLoading = false;
  String? _pdfPath;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Debug output for PDF loading
    print(
      "ContentViewerScreen init: Loading content for module ${widget.module.id} in course ${widget.course.id}",
    );

    // Get the user's name for the watermark
    _getUserName();

    // Clean up old PDF files
    _cleanupOldPdfFiles();

    // Load content
    _loadContent();
  }

  // Get the current user's name
  Future<void> _getUserName() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      // Use email as watermark, fall back to "User" if not available
      setState(() {
        _userName = user.email ?? "User";
      });
    }
  }

  @override
  void dispose() {
    _disposeVideoControllers();
    WidgetsBinding.instance.removeObserver(this);
    _removeScreenshotProtection();
    super.dispose();
  }

  // Setup screenshot protection
  void _setupScreenshotProtection() async {
    // Hide system UI elements
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    // For iOS we need to use the native channel to disable screen recording
    if (Platform.isIOS) {
      const MethodChannel(
        'flutter.native/screenProtection',
      ).invokeMethod('preventScreenshots', true);
    }

    // Android uses FLAG_SECURE set in MainActivity.kt
    // This is handled at the native level for both platforms now
  }

  // Remove screenshot protection when leaving the screen
  void _removeScreenshotProtection() async {
    // Restore system UI elements
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    if (Platform.isIOS) {
      const MethodChannel(
        'flutter.native/screenProtection',
      ).invokeMethod('preventScreenshots', false);
    }

    // Native FLAG_SECURE on Android remains active for the entire app
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app is resumed, re-apply screenshot protection
    if (state == AppLifecycleState.resumed) {
      _setupScreenshotProtection();
    }
  }

  void _disposeVideoControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _loadContent() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      // First verify the user has access to this course
      print("Verifying access to course: ${widget.course.id}");
      final hasAccess = await authService.hasAccessToCourse(widget.course.id);

      if (!hasAccess) {
        print(
          "Access denied: User does not have access to course ${widget.course.id}",
        );
        setState(() {
          _isLoading = false;
        });

        // Show access denied message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have access to this course content.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print("Access granted: User has access to course ${widget.course.id}");

      // Now load the content
      setState(() {
        _contentFuture = firestoreService.getModuleContent(
          widget.course.id,
          widget.module.id,
        );
      });

      final contentList = await _contentFuture;
      print("Loaded ${contentList.length} content items");

      // Print detailed info for debugging
      for (int i = 0; i < contentList.length; i++) {
        final content = contentList[i];
        print("Content item #$i:");
        print("  - ID: ${content.id}");
        print("  - Title: ${content.title}");
        print("  - Type: ${content.contentType}");
        print("  - URL/Content: ${content.content}");

        // Verify URL format for videos and PDFs
        if ((content.contentType == 'video' || content.contentType == 'pdf') &&
            content.content.isNotEmpty) {
          if (!content.content.startsWith('http')) {
            print("WARNING: Invalid URL format: ${content.content}");
          } else {
            print("URL format looks valid");
          }
        }
      }

      // If there's any content and we have a video, pre-initialize it
      if (contentList.isNotEmpty && contentList[0].contentType == 'video') {
        print("Pre-initializing video player for: ${contentList[0].content}");
        _initializeVideoPlayer(contentList[0].content);
      }
    } catch (e) {
      print("Error loading content: $e");
      // Log stack trace for better error diagnosis
      print("Stack trace: ${StackTrace.current}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation based on index
    if (index == 1) {
      // Profile navigation
      AppNavigator.navigateTo(context: context, page: const ProfileScreen());
    } else if (index == 0) {
      // Home - safely navigate to home screen instead of using pop
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AssignedCoursesScreen()),
        (route) => false, // This clears the navigation stack
      );
    }
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    // Clean up old controllers first
    _disposeVideoControllers();

    try {
      print("Initializing video player for URL: $videoUrl");

      // Check if the URL is valid
      if (!videoUrl.startsWith('http')) {
        print("ERROR: Invalid video URL format: $videoUrl");
        throw Exception("Invalid video URL format");
      }

      // Try to make a HEAD request to verify the URL is accessible
      try {
        final response = await http.head(Uri.parse(videoUrl));
        print("Video URL status code: ${response.statusCode}");

        if (response.statusCode >= 400) {
          print(
            "WARNING: Video URL returned error status: ${response.statusCode}",
          );
          print("Response headers: ${response.headers}");
        }
      } catch (e) {
        print("WARNING: Could not verify video URL: $e");
        // Continue anyway as some URLs might not support HEAD requests
      }

      // Initialize the video player
      print("Creating video controller...");
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      print("Initializing video controller...");
      await _videoController!.initialize();
      print("Video controller initialized successfully");

      // Create chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          print("Chewie error: $errorMessage");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading video: $errorMessage',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _initializeVideoPlayer(videoUrl),
                  child: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF323483),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
        // Add custom controls and fullscreen options
        customControls: const MaterialControls(),
        fullScreenByDefault: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        // Add overlay to show watermark in fullscreen mode
        overlay: BriffiniWatermark(userName: _userName),
      );

      // Rebuild the UI
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing video player: $e');
      print('Stack trace: ${StackTrace.current}');

      // Reset controllers on error
      _disposeVideoControllers();
      if (mounted) {
        setState(() {});

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load video: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _initializeVideoPlayer(videoUrl),
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  // Native platforms method to download PDF and save it locally with enhanced security
  Future<void> _loadPdf(String pdfUrl) async {
    if (_pdfPath != null) return; // Already loaded

    setState(() {
      _isPdfLoading = true;
      _pdfPath = null;
      _pdfError = null;
    });

    try {
      print("Content Viewer: Loading PDF from URL: $pdfUrl");

      // Validate the URL
      if (pdfUrl.isEmpty ||
          (!pdfUrl.startsWith('http') && !pdfUrl.startsWith('gs://'))) {
        throw Exception("Invalid PDF URL format: $pdfUrl");
      }

      // Get storage service
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );

      // Get auth service to verify access
      final authService = Provider.of<AuthService>(context, listen: false);

      // Print debug info
      print("User ID: ${authService.currentUser?.uid}");
      print("Course ID: ${widget.course.id}");
      print("Module ID: ${widget.module.id}");
      print("PDF URL: $pdfUrl");

      // Verify course access first
      final hasAccess = await authService.hasAccessToCourse(widget.course.id);
      print("Access check result: $hasAccess");

      if (!hasAccess) {
        print("Access denied to course ${widget.course.id}");
        throw Exception(
          "You don't have access to this course content. Please verify your course access.",
        );
      }

      String secureUrl;

      // Check if this is a Firebase Storage URL or direct URL
      if (pdfUrl.contains('firebasestorage') || pdfUrl.startsWith('gs://')) {
        print("Processing Firebase Storage URL");
        try {
          // Get secure URL with short expiration
          secureUrl = await storageService.getSecurePdfUrl(pdfUrl);
          print(
            "Secure URL generated: ${secureUrl.substring(0, min(50, secureUrl.length))}...",
          );
        } catch (e) {
          print("Error getting secure URL: $e");
          print("Stack trace: ${StackTrace.current}");

          if (e.toString().contains('403') ||
              e.toString().contains('permission')) {
            throw Exception(
              "Access denied: You don't have permission to access this PDF. Please verify your course access.",
            );
          }

          // Try direct download as fallback only if not a permission error
          print("Attempting direct download as fallback");
          secureUrl = pdfUrl;
        }
      } else {
        // Use the provided URL directly if it's not a Firebase Storage URL
        secureUrl = pdfUrl;
        print("Using direct URL");
      }

      // Try using the PDFLoader instead of manual download
      print("Using PDFLoader class to download and save PDF");

      final filePath = await PDFLoader.loadPDF(secureUrl);

      if (filePath == null) {
        throw Exception("Failed to load PDF through PDFLoader");
      }

      print("PDFLoader succeeded: $filePath");

      // Update state with the file path
      setState(() {
        _pdfPath = filePath;
        _isPdfLoading = false;
      });
    } catch (e) {
      print('Error loading PDF: $e');
      print('Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() {
          _isPdfLoading = false;
          _pdfError = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadPdf(pdfUrl),
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  // Update the _buildContentView method to handle PDF viewing with watermark
  Widget _buildContentView(ContentModel content) {
    switch (content.contentType) {
      case 'video':
        if (content.content.isEmpty) {
          return const Center(
            child: Text(
              'No video URL available.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        // Initialize video player if needed
        if (_videoController == null ||
            _videoController!.dataSource != content.content) {
          // Schedule initialization after the current frame
          Future.microtask(() => _initializeVideoPlayer(content.content));

          return const Center(child: CircularProgressIndicator());
        }

        // Show video player if controllers are ready
        if (_chewieController != null) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  ),
                ),
                // Add watermark overlay with the user's name
                BriffiniWatermark(userName: _userName),
              ],
            ),
          );
        }

        // Show loading while initializing
        return const Center(child: CircularProgressIndicator());

      case 'pdf':
        if (content.content.isEmpty) {
          return const Center(
            child: Text(
              'No PDF URL available.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        // Load PDF if not already loaded
        if (_pdfPath == null && !_isPdfLoading) {
          Future.microtask(() => _loadPdf(content.content));
        }

        // Show PDF viewer when PDF is loaded
        if (_pdfPath != null) {
          // Wrap in a Stack to have a floating fullscreen button
          return Stack(
            children: [
              // PDF viewer takes the full space
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: CustomPDFViewer(
                  filePath: _pdfPath!,
                  userName: _userName,
                ),
              ),
              
              // Floating fullscreen button
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF323483),
                  mini: true,
                  child: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenPdfViewer(
                          filePath: _pdfPath!,
                          userName: _userName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        // Show error message if there's an error
        if (_pdfError != null) {
          String errorMessage = _pdfError!;
          String actionMessage =
              "Please try again or contact support if the problem persists.";
          IconData errorIcon = Icons.error_outline;

          // Format user-friendly error messages
          if (_pdfError!.contains("403") || _pdfError!.contains("permission")) {
            errorMessage = "You don't have permission to access this file.";
            actionMessage =
                "Please verify that you have access to this module.";
            errorIcon = Icons.lock_outline;
          } else if (_pdfError!.contains("404") ||
              _pdfError!.contains("not found")) {
            errorMessage = "The requested PDF file could not be found.";
            actionMessage = "The file may have been moved or deleted.";
            errorIcon = Icons.find_in_page;
          } else if (_pdfError!.contains("timeout") ||
              _pdfError!.contains("timed out")) {
            errorMessage = "Connection timed out while downloading the PDF.";
            actionMessage =
                "Please check your internet connection and try again.";
            errorIcon = Icons.wifi_off;
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(errorIcon, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading PDF',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  actionMessage,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF323483),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _pdfError = null;
                      });
                      _loadPdf(content.content);
                    },
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          );
        }

        // Show loading indicator while PDF is being prepared
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF323483)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading PDF...',
                style: TextStyle(
                  color: Color(0xFF323483),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Module: ${widget.module.title}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'This may take a moment depending on your connection',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case 'text':
      default:
        return Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  content.content,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            // Add watermark overlay with the user's name
            BriffiniWatermark(userName: _userName),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      // Proper system UI handling
      extendBodyBehindAppBar: false,
      extendBody: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight:
            0, // Zero height app bar to respect status bar but not take space
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<ContentModel>>(
                  future: _contentFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            Text(
                              'Loading module content...',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(0xFF323483),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Text(
                                'Error loading content: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadContent,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF323483),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final contentList = snapshot.data ?? [];
                    if (contentList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.folder_open,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No content available for this module.',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Ensure current index is valid
                    if (_currentContentIndex >= contentList.length) {
                      _currentContentIndex = contentList.length - 1;
                    }

                    final currentContent = contentList[_currentContentIndex];

                    return Container(
                      width: screenSize.width,
                      height: screenSize.height,
                      color: Colors.white, // Page background
                      child: Stack(
                        children: [
                          // Main content area with padding
                          Padding(
                            padding: EdgeInsets.only(
                              top: screenSize.height * 0.01,
                              bottom:
                                  safeAreaBottom + 80, // Space for bottom nav
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User Profile Card - Module Title
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenSize.width * 0.04,
                                    vertical: screenSize.height * 0.01,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: screenSize.height * 0.08,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF323483),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1F171A1F),
                                          offset: Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.module.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: screenSize.height * 0.01),

                                // Content Container - Expanded to take more screen space
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenSize.width * 0.04,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF323483),
                                          width: 1,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x1A000000),
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child:
                                            currentContent.contentType ==
                                                        'video' ||
                                                    currentContent
                                                            .contentType ==
                                                        'pdf'
                                                ? _buildContentView(
                                                  currentContent,
                                                )
                                                : SingleChildScrollView(
                                                  child: _buildContentView(
                                                    currentContent,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Navigation row (prev/next) with index indicator
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: screenSize.height * 0.01,
                                    left: screenSize.width * 0.05,
                                    right: screenSize.width * 0.05,
                                    bottom: screenSize.height * 0.01,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Previous button
                                      IconButton(
                                        onPressed:
                                            _currentContentIndex > 0
                                                ? () {
                                                  setState(() {
                                                    _currentContentIndex--;
                                                    // Reset controllers when changing content
                                                    _disposeVideoControllers();
                                                    _pdfPath = null;
                                                    _isPdfLoading = false;
                                                  });
                                                }
                                                : null,
                                        icon: Icon(
                                          Icons.arrow_back,
                                          color:
                                              _currentContentIndex > 0
                                                  ? const Color(0xFF323483)
                                                  : Colors.grey,
                                          size: 30,
                                        ),
                                      ),

                                      // Progress indicator
                                      Text(
                                        '${_currentContentIndex + 1}/${contentList.length}',
                                        style: GoogleFonts.inter(
                                          fontSize: screenSize.width * 0.04,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2E2C6A),
                                        ),
                                      ),

                                      // Next button
                                      IconButton(
                                        onPressed:
                                            _currentContentIndex <
                                                    contentList.length - 1
                                                ? () {
                                                  setState(() {
                                                    _currentContentIndex++;
                                                    // Reset controllers when changing content
                                                    _disposeVideoControllers();
                                                    _pdfPath = null;
                                                    _isPdfLoading = false;
                                                  });
                                                }
                                                : null,
                                        icon: Icon(
                                          Icons.arrow_forward,
                                          color:
                                              _currentContentIndex <
                                                      contentList.length - 1
                                                  ? const Color(0xFF323483)
                                                  : Colors.grey,
                                          size: 30,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(
          left: screenSize.width * 0.05,
          right: screenSize.width * 0.05,
          bottom: safeAreaBottom + 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
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
            unselectedItemColor: const Color(0xFF565E6C),
            onTap: _onItemTapped,
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

  // Clean up old PDF files to prevent storage issues
  Future<void> _cleanupOldPdfFiles() async {
    try {
      // Get directories
      Directory? tempDir;
      Directory? appDocDir;

      try {
        tempDir = await getTemporaryDirectory();
      } catch (e) {
        print("Could not access temp directory: $e");
      }

      try {
        appDocDir = await getApplicationDocumentsDirectory();
      } catch (e) {
        print("Could not access app documents directory: $e");
      }

      // Define cleanup for a directory
      Future<void> cleanupDir(Directory dir, String subPath) async {
        final cacheDir = Directory('${dir.path}/$subPath');
        if (await cacheDir.exists()) {
          print("Cleaning up PDF cache in ${cacheDir.path}");

          // Get all files in the directory
          final files = await cacheDir.list().toList();

          // Get current time
          final now = DateTime.now();

          // Delete files older than 7 days
          for (var entity in files) {
            if (entity is File && entity.path.contains('secure_pdf_')) {
              try {
                final stat = await entity.stat();
                final fileAge = now.difference(stat.modified);

                if (fileAge.inDays > 7) {
                  print("Deleting old PDF file: ${entity.path}");
                  await entity.delete();
                }
              } catch (e) {
                print("Error checking/deleting file ${entity.path}: $e");
              }
            }
          }
        }
      }

      // Clean up both directories
      if (tempDir != null) {
        await cleanupDir(tempDir, 'pdf_cache');
      }

      if (appDocDir != null) {
        await cleanupDir(appDocDir, 'pdf_cache');
      }
    } catch (e) {
      print("Error during PDF cache cleanup: $e");
      // Non-critical operation, so just log the error
    }
  }
}
