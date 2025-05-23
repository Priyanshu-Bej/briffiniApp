import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// Safe to use web libraries in this file
import 'dart:html' as html;
// Import ui_web for platformViewRegistry
import 'dart:ui_web' as ui_web;

import '../models/course_model.dart';
import '../models/module_model.dart';
import '../models/content_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';
import 'profile_screen.dart';
import '../utils/route_transitions.dart';

// Watermark overlay widget for PDFs
class BriffiniWatermark extends StatelessWidget {
  const BriffiniWatermark({Key? key}) : super(key: key);

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
                          child: const Text(
                            'BRIFFINI',
                            style: TextStyle(
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
  String? _pdfViewId; // For web PDF viewer

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

  // Setup screenshot protection for web
  void _setupScreenshotProtection() {
    // For web, we can use JavaScript to disable right-click and add CSS to prevent selection
    html.document.onContextMenu.listen((event) => event.preventDefault());

    // Add CSS to prevent selection and dragging
    final style = html.StyleElement();
    style.id = 'screenshot-protection-style';
    style.innerHtml = '''
      body {
        -webkit-user-select: none;
        -moz-user-select: none;
        -ms-user-select: none;
        user-select: none;
        -webkit-touch-callout: none;
      }
      img, video {
        -webkit-user-drag: none;
        -khtml-user-drag: none;
        -moz-user-drag: none;
        -o-user-drag: none;
        user-drag: none;
        pointer-events: none;
      }
    ''';
    html.document.head?.children.add(style);
  }

  // Remove screenshot protection when leaving the screen
  void _removeScreenshotProtection() {
    final styleElement = html.document.getElementById(
      'screenshot-protection-style',
    );
    if (styleElement != null) {
      styleElement.remove();
    }
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

  // Web-specific method to load PDF in an iframe
  void _loadPdf(String pdfUrl) {
    if (_pdfViewId != null) return; // Already loaded

    setState(() {
      _isPdfLoading = true;
    });

    try {
      // Generate a unique ID for the iframe
      final viewId = 'pdf-view-${DateTime.now().millisecondsSinceEpoch}';
      _pdfViewId = viewId;

      // Register the view
      ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
        final iframe =
            html.IFrameElement()
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.border = 'none'
              ..src = pdfUrl;

        // Handle loaded event
        iframe.onLoad.listen((event) {
          setState(() {
            _isPdfLoading = false;
          });
        });

        return iframe;
      });

      setState(() {
        // This will rebuild UI with the iframe view
      });
    } catch (e) {
      print('Error creating web PDF viewer: $e');
      setState(() {
        _isPdfLoading = false;
        _pdfViewId = null;
      });
    }
  }

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
        if (_pdfViewId == null && !_isPdfLoading) {
          Future.microtask(() => _loadPdf(content.content));
        }

        // Show web PDF viewer when available
        if (_pdfViewId != null) {
          return Stack(
            children: [
              HtmlElementView(viewType: _pdfViewId!),
              // Add watermark overlay
              const BriffiniWatermark(),
            ],
          );
        }

        // Show loading indicator while PDF is being prepared
        // Use a container with fixed dimensions to prevent layout shifting
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
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
    return Scaffold(
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

                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            // Header with course and module title
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1C1A5E,
                                ), // Dark blue background
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  widget.module.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Content viewer area - Expanded with less padding
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF323483),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: _buildContentView(currentContent),
                              ),
                            ),

                            // Navigation
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Previous button
                                  ElevatedButton.icon(
                                    onPressed:
                                        _currentContentIndex > 0
                                            ? () {
                                              setState(() {
                                                _currentContentIndex--;
                                                // Reset controllers when changing content
                                                _disposeVideoControllers();
                                                _pdfViewId = null;
                                                _isPdfLoading = false;
                                              });
                                            }
                                            : null,
                                    icon: const Icon(Icons.arrow_back),
                                    label: const Text('Previous'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF323483),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),

                                  // Progress indicator
                                  Column(
                                    children: [
                                      Text(
                                        '${_currentContentIndex + 1}/${contentList.length}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        contentList[_currentContentIndex]
                                            .contentType
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Next button
                                  ElevatedButton.icon(
                                    onPressed:
                                        _currentContentIndex <
                                                contentList.length - 1
                                            ? () {
                                              setState(() {
                                                _currentContentIndex++;
                                                // Reset controllers when changing content
                                                _disposeVideoControllers();
                                                _pdfViewId = null;
                                                _isPdfLoading = false;
                                              });
                                            }
                                            : null,
                                    icon: const Icon(Icons.arrow_forward),
                                    label: const Text('Next'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF323483),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Floating navigation bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 30,
                        child: Center(
                          child: Container(
                            width:
                                180, // Increased width for more space between icons
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
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
                                    color:
                                        _selectedIndex == 0
                                            ? Colors.blue
                                            : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                const SizedBox(
                                  width: 20,
                                ), // Added space between icons
                                IconButton(
                                  icon: Icon(
                                    Icons.person,
                                    color:
                                        _selectedIndex == 1
                                            ? Colors.blue
                                            : Colors.grey,
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
