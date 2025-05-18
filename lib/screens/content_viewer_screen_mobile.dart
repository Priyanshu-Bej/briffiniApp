import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/course_model.dart';
import '../models/module_model.dart';
import '../models/content_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';

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

class _ContentViewerScreenState extends State<ContentViewerScreen> {
  late Future<List<ContentModel>> _contentFuture;
  bool _isLoading = true;
  int _currentContentIndex = 0;

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
  }

  @override
  void dispose() {
    _disposeVideoControllers();
    super.dispose();
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

  // Native platforms method to download PDF and save it locally
  Future<void> _loadPdf(String pdfUrl) async {
    if (_pdfPath != null) return; // Already loaded

    setState(() {
      _isPdfLoading = true;
      _pdfPath = null;
    });

    try {
      // Download the PDF file
      final response = await http.get(Uri.parse(pdfUrl));

      if (response.statusCode == 200) {
        // Get temporary directory for storing the file
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.pdf';

        // Write the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

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
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
              const SizedBox(height: 20),
              Text(
                content.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
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
                  preventLinkNavigation: false,
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
                child: Text(
                  content.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          );
        }

        // Show loading indicator while PDF is being prepared
        if (_isPdfLoading) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading PDF...'),
            ],
          );
        }

        // Show error if PDF couldn't be loaded
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
            SizedBox(height: 20),
            Text('Could not load PDF file.'),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _loadPdf(content.content),
              child: Text('Retry'),
            ),
          ],
        );

      case 'text':
      default:
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content.content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
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
                    return Center(child: Text('Error: ${snapshot.error}'));
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

                  return Column(
                    children: [
                      // Content title bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[100],
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              radius: 16,
                              child: Text(
                                '${_currentContentIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentContent.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    'Content Type: ${currentContent.contentType}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Expanded(
                        child: Center(child: _buildContentView(currentContent)),
                      ),

                      // Navigation
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Previous button
                            ElevatedButton.icon(
                              onPressed:
                                  _currentContentIndex > 0
                                      ? () {
                                        setState(() {
                                          _currentContentIndex--;
                                        });
                                      }
                                      : null,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Previous'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                              ),
                            ),

                            // Progress indicator
                            Text(
                              '${_currentContentIndex + 1}/${contentList.length}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            // Next button
                            ElevatedButton.icon(
                              onPressed:
                                  _currentContentIndex < contentList.length - 1
                                      ? () {
                                        setState(() {
                                          _currentContentIndex++;
                                        });
                                      }
                                      : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }
}
