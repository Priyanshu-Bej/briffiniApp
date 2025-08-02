import 'package:flutter/material.dart';
import 'pod_video_player_ios.dart';

/// Example of how to integrate the Pod Video Player into your content screens
/// This shows the usage pattern for the new iOS-optimized video player
class ExamplePodIntegration extends StatelessWidget {
  final String videoUrl;
  final String userName;
  final String videoTitle;

  const ExamplePodIntegration({
    Key? key,
    required this.videoUrl,
    required this.userName,
    required this.videoTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(videoTitle),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // iOS-optimized video player
            PodVideoPlayerIOS(
              videoUrl: videoUrl,
              userName: userName,
              title: videoTitle,
              autoPlay: false,
              showControls: true,
              onVideoCompleted: () {
                // Handle video completion
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video completed!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              onProgress: (duration) {
                // Handle progress updates if needed
                // print('Video progress: ${duration.inSeconds}s');
              },
            ),

            const SizedBox(height: 24),

            // Additional content can go here
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Title: $videoTitle'),
                    Text('User: $userName'),
                    const SizedBox(height: 12),
                    const Text(
                      'Features:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Text('• iOS-optimized performance'),
                    const Text('• Modern video controls'),
                    const Text('• Fullscreen support'),
                    const Text('• Watermark protection'),
                    const Text('• Wakelock management'),
                    const Text('• App lifecycle awareness'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How to use in your existing ContentViewerScreen:
/// 
/// Replace the existing video player widget with:
/// 
/// ```dart
/// PodVideoPlayerIOS(
///   videoUrl: content.content,
///   userName: _userName,
///   title: content.title,
///   autoPlay: false,
///   showControls: true,
///   onVideoCompleted: () {
///     // Handle completion
///   },
/// )
/// ```
/// 
/// Key improvements over the previous video player:
/// 1. Better iOS performance and compatibility
/// 2. Modern, native-feeling controls
/// 3. Smooth fullscreen transitions
/// 4. Proper orientation handling
/// 5. Integrated watermark support
/// 6. Better error handling and recovery
/// 7. Wakelock management for uninterrupted playback
/// 8. App lifecycle awareness (auto-pause on background)