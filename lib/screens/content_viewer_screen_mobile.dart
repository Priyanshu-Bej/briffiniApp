import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/course_model.dart';
import '../models/module_model.dart';
import '../models/content_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';
import 'profile_screen.dart';
import 'assigned_courses_screen.dart';
import '../utils/route_transitions.dart';
import '../services/storage_service.dart';

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

  // Video player controllers
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // PDF state variables
  bool _isPdfLoading = false;
  String? _pdfPath;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _setupScreenshotProtection();
    WidgetsBinding.instance.addObserver(this);
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

    setState(() {
      _isLoading = true;
      _contentFuture = firestoreService.getModuleContent(
        widget.course.id,
        widget.module.id,
      );
    });

    try {
      await _contentFuture;
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
      // Initialize the video player
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();

      // Create chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error loading video: $errorMessage',
              style: TextStyle(color: Colors.red),
            ),
          );
        },
      );

      // Rebuild the UI
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing video player: $e');
      // Reset controllers on error
      _disposeVideoControllers();
      if (mounted) setState(() {});
    }
  }

  // Native platforms method to download PDF and save it locally with enhanced security
  Future<void> _loadPdf(String pdfUrl) async {
    if (_pdfPath != null) return; // Already loaded

    setState(() {
      _isPdfLoading = true;
      _pdfPath = null;
    });

    try {
      // Get storage service
      final storageService = Provider.of<StorageService>(
        context, 
        listen: false
      );
      
      String secureUrl;
      
      // Check if this is a Firebase Storage URL or direct URL
      if (pdfUrl.contains('firebasestorage') || pdfUrl.startsWith('gs://')) {
        // Extract the storage path from the URL or use the whole path if it's a gs:// URL
        String storagePath = pdfUrl;
        if (pdfUrl.contains('firebasestorage')) {
          // Extract path from https URL - this is simplified, may need adjustment
          storagePath = Uri.parse(pdfUrl).path.split('/o/').last;
          storagePath = Uri.decodeComponent(storagePath);
        } else if (pdfUrl.startsWith('gs://')) {
          // Remove gs://bucket-name/ prefix
          storagePath = pdfUrl.replaceFirst(RegExp(r'gs://[^/]+/'), '');
        }
        
        // Get secure URL with short expiration
        secureUrl = await storageService.getSecurePdfUrl(storagePath);
      } else {
        // Use the provided URL directly if it's not a Firebase Storage URL
        secureUrl = pdfUrl;
      }

      // Download the PDF file
      final response = await http.get(Uri.parse(secureUrl));

      if (response.statusCode == 200) {
        // Get temporary directory for storing the file
        final dir = await getTemporaryDirectory();
        // Generate a more secure random filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = timestamp ^ (timestamp >> 8);
        final filePath = '${dir.path}/secure_pdf_${random.toRadixString(16)}.pdf';

        // Write the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Set file permission to be readable only by the app (more secure)
        if (Platform.isLinux || Platform.isAndroid) {
          try {
            await Process.run('chmod', ['600', filePath]);
          } catch (e) {
            print('Could not set file permissions: $e');
            // Continue anyway as this is just an extra security measure
          }
        }

        // Update state with the file path
        setState(() {
          _pdfPath = filePath;
          _isPdfLoading = false;
        });
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading PDF: $e');
      setState(() {
        _isPdfLoading = false;
      });
    }
  }

  // Full-screen PDF viewer widget
  class FullScreenPdfViewer extends StatefulWidget {
    final String filePath;

    const FullScreenPdfViewer({
      Key? key,
      required this.filePath,
    }) : super(key: key);

    @override
    _FullScreenPdfViewerState createState() => _FullScreenPdfViewerState();
  }

  class _FullScreenPdfViewerState extends State<FullScreenPdfViewer> {
    bool _isFullScreen = true;

    @override
    void initState() {
      super.initState();
      // Enter full-screen mode
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
        appBar: _isFullScreen 
            ? null 
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
                        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                      });
                    },
                  ),
                ],
              ),
        body: GestureDetector(
          onTap: () {
            setState(() {
              _isFullScreen = !_isFullScreen;
              if (_isFullScreen) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              } else {
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: SystemUiOverlay.values,
                );
              }
            });
          },
          child: PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: 0,
            fitPolicy: FitPolicy.BOTH,
            // Disable link navigation to prevent downloads
            preventLinkNavigation: true,
            onRender: (_pages) {
              // PDF is rendered
            },
            onError: (error) {
              print('Error rendering PDF: $error');
            },
            onPageError: (page, error) {
              print('Error on page $page: $error');
            },
            onViewCreated: (controller) {
              // PDF controller created
            },
          ),
        ),
      );
    }
  }

  // Update the _buildContentView method to handle PDF viewing in full screen
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
          return AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Chewie(controller: _chewieController!),
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
          return Column(
            children: [
              Expanded(
                child: PDFView(
                  filePath: _pdfPath!,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                  pageSnap: true,
                  defaultPage: 0,
                  fitPolicy: FitPolicy.BOTH,
                  // Disable link navigation to prevent downloads
                  preventLinkNavigation: true,
                  onRender: (_pages) {
                    setState(() {
                      // PDF is rendered
                    });
                  },
                  onError: (error) {
                    print('Error rendering PDF: $error');
                  },
                  onPageError: (page, error) {
                    print('Error on page $page: $error');
                  },
                  onViewCreated: (controller) {
                    // PDF controller created
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Full Screen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF323483),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenPdfViewer(
                          filePath: _pdfPath!,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        // Show loading indicator while PDF is being prepared
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF323483)),
              ),
              SizedBox(height: 20),
              Text(
                'Loading PDF...',
                style: TextStyle(
                  color: Color(0xFF323483),
                  fontWeight: FontWeight.bold,
                ),
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
            // Watermark for text content
            Center(
              child: Opacity(
                opacity: 0.1, // Subtle watermark
                child: Transform.rotate(
                  angle: -0.2, // Slight rotation
                  child: const Text(
                    'Briffini Academy',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF323483),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsiveness
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    // Color Scheme:
    // - Background: #FFFFFF (White)
    // - User Profile Card:
    //   - Background: #323483 (Dark Blue)
    //   - Border: #C9C8D8 (Light Grayish-Purple)
    //   - Text: #FFFFFF (White)
    // - Content Container:
    //   - Background: #FFFFFF (White)
    //   - Border: #656BE9 (Bright Blue)
    //   - Play Button: #171A1F (Dark Gray)
    // - Bottom Navigation Bar:
    //   - Background: #FFFFFF (White)
    //   - Icons:
    //     - Unselected: #565E6C (Neutral Gray)
    //     - Selected: #778FF0 (Light Blue)

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<ContentModel>>(
                future: _contentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                          Text('Error: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadContent,
                            child: const Text('Try Again'),
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
                    return const Center(
                      child: Text('No content available for this module.'),
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
                            top: safeAreaTop + screenSize.height * 0.01,
                            bottom: safeAreaBottom + 80, // Space for bottom nav
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
                                  height: screenSize.height * 0.12,
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
                                  child: Center(
                                    child: Text(
                                      widget.module.title,
                                      style: GoogleFonts.archivo(
                                        fontSize: screenSize.width * 0.06,
                                        fontWeight: FontWeight.w700,
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
                                    horizontal: screenSize.width * 0.02,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
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
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildContentView(currentContent),
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
}
