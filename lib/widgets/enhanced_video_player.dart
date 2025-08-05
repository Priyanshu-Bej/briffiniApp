import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/logger.dart';
import '../utils/responsive_helper.dart';

/// Enhanced video player with robust fullscreen support
/// Replaces the problematic Pod Player implementation
class EnhancedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String userName;
  final String? title;
  final bool autoPlay;
  final bool showControls;
  final Function()? onVideoCompleted;
  final Function(Duration)? onProgress;

  const EnhancedVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.userName,
    this.title,
    this.autoPlay = false,
    this.showControls = true,
    this.onVideoCompleted,
    this.onProgress,
  }) : super(key: key);

  @override
  State<EnhancedVideoPlayer> createState() => _EnhancedVideoPlayerState();
}

class _EnhancedVideoPlayerState extends State<EnhancedVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isInitializing = false; // Prevent multiple simultaneous initializations

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Handle async disposal - fire and forget since dispose can't be async
    _disposePlayer().catchError((e) => Logger.w('Error during disposal: $e'));
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isInitialized && _videoPlayerController != null && mounted) {
      try {
        switch (state) {
          case AppLifecycleState.paused:
          case AppLifecycleState.detached:
          case AppLifecycleState.hidden:
            _videoPlayerController!.pause();
            WakelockPlus.disable();
            break;
          case AppLifecycleState.resumed:
            // Don't auto-resume to respect user's choice
            if (_videoPlayerController!.value.isPlaying) {
              WakelockPlus.enable();
            }
            break;
          case AppLifecycleState.inactive:
            // Do nothing for inactive state
            break;
        }
      } catch (e) {
        Logger.e('Error handling app lifecycle state change: $e');
      }
    }
  }

  Future<void> _disposePlayer() async {
    try {
      // Set flags to prevent new operations
      _isInitialized = false;

      // Remove listener first to prevent callbacks during disposal
      _videoPlayerController?.removeListener(_videoListener);

      // Disable wakelock
      WakelockPlus.disable();

      // Dispose Chewie controller first with delay to let timers finish
      if (_chewieController != null) {
        await Future.delayed(const Duration(milliseconds: 50));
        _chewieController?.dispose();
        _chewieController = null;
      }

      // Then dispose video controller if it still exists
      if (_videoPlayerController != null) {
        await _videoPlayerController?.dispose();
        _videoPlayerController = null;
      }
    } catch (e) {
      Logger.w('Warning disposing video player: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted || _isInitialized || _isInitializing) return;

    _isInitializing = true;

    try {
      Logger.i("🎬 Initializing Enhanced video player: ${widget.videoUrl}");

      // Dispose any existing controllers first with proper cleanup
      await _disposePlayer();

      // Add small delay to ensure clean disposal
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) {
        _isInitializing = false;
        return;
      }

      // Initialize video player controller
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'User-Agent': 'BriffiniAcademy/1.0',
          'Referer': 'https://briffini.academy',
        },
      );

      await _videoPlayerController!.initialize();

      if (!mounted) {
        _isInitializing = false;
        return;
      }

      // Configure Chewie controller with enhanced fullscreen support
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: widget.autoPlay,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: widget.showControls,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF1A237E),
          handleColor: const Color(0xFF1A237E),
          backgroundColor: Colors.grey.shade300,
          bufferedColor: Colors.grey.shade500,
        ),
        // Enhanced fullscreen configuration
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        systemOverlaysAfterFullScreen: SystemUiOverlay.values,
        // Playlist and custom controls
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
            ),
          ),
        ),
        // Error widget
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
      );

      // Add listener for progress updates and completion
      _videoPlayerController!.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      Logger.i("✅ Enhanced video player initialized successfully");
    } catch (e) {
      Logger.e('❌ Error initializing Enhanced video player: $e');

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize video player: ${e.toString()}';
          _isInitialized = false;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _videoListener() {
    if (!mounted || _videoPlayerController == null || !_isInitialized) return;

    try {
      final controller = _videoPlayerController!;
      final value = controller.value;

      // Handle video completion
      if (value.position >= value.duration && value.duration > Duration.zero) {
        widget.onVideoCompleted?.call();
        WakelockPlus.disable();
        Logger.i('Video playback completed');
      }

      // Handle progress updates
      if (widget.onProgress != null) {
        widget.onProgress!(value.position);
      }

      // Handle wakelock based on playback state
      if (value.isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }

      // Simplified fullscreen detection - let Chewie handle it internally
      // We don't need to manually track fullscreen state
    } catch (e) {
      Logger.e('Error in video listener: $e');
    }
  }

  Widget _buildWatermarkOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Transform.rotate(
          angle: -0.2,
          child: Text(
            'Briffini Academy\n${widget.userName}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: ResponsiveHelper.isIOS() ? 28 : 24,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red[300],
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Video Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isInitialized = false;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enhanced player for better performance',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(_errorMessage ?? 'Unknown error');
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.title!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
              // Custom watermark overlay
              Positioned.fill(
                child: IgnorePointer(child: _buildWatermarkOverlay()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
