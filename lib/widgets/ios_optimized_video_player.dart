import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import '../utils/logger.dart';
import '../utils/responsive_helper.dart';

/// iOS-optimized video player widget using better_player
/// Provides enhanced performance and compatibility on iOS devices
class IOSOptimizedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String userName;
  final String? title;
  final bool autoPlay;
  final bool showControls;

  const IOSOptimizedVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.userName,
    this.title,
    this.autoPlay = false,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<IOSOptimizedVideoPlayer> createState() =>
      _IOSOptimizedVideoPlayerState();
}

class _IOSOptimizedVideoPlayerState extends State<IOSOptimizedVideoPlayer>
    with WidgetsBindingObserver {
  BetterPlayerController? _betterPlayerController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposePlayer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_betterPlayerController != null) {
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          _betterPlayerController?.pause();
          break;
        case AppLifecycleState.resumed:
          // Don't auto-resume to respect user's choice
          break;
        case AppLifecycleState.inactive:
          // Do nothing for inactive state
          break;
      }
    }
  }

  void _disposePlayer() {
    try {
      _betterPlayerController?.dispose();
      _betterPlayerController = null;
    } catch (e) {
      Logger.w('Warning disposing video player: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    try {
      Logger.i(
        "🎬 Initializing iOS optimized video player for: ${widget.videoUrl}",
      );

      // Configure better player for iOS optimization
      final betterPlayerConfiguration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        autoPlay: widget.autoPlay,
        looping: false,
        fit: BoxFit.contain,
        errorBuilder: (context, errorMessage) {
          Logger.e("Better Player error: $errorMessage");
          return _buildErrorWidget(errorMessage ?? 'Unknown video error');
        },
        // iOS-specific optimizations
        deviceOrientationsOnFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        // Enhanced controls for iOS
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enableMute: true,
          enablePlayPause: true,
          enableProgressBar: true,
          enableProgressText: true,
          enableSkips: false,
          enableAudioTracks: false,
          enableSubtitles: false,
          enableQualities: false,
          enablePlaybackSpeed: true,
          // iOS-specific control styling
          controlBarColor: Colors.black.withOpacity(0.8),
          iconsColor: Colors.white,
          progressBarPlayedColor: const Color(0xFF1A237E),
          progressBarHandleColor: const Color(0xFF1A237E),
          progressBarBufferedColor: Colors.grey,
          progressBarBackgroundColor: Colors.grey.withOpacity(0.3),
          textColor: Colors.white,
          // Better touch responsiveness on iOS
          controlBarHeight: ResponsiveHelper.isIOS() ? 60 : 50,
          loadingColor: const Color(0xFF1A237E),
          overflowMenuIconsColor: Colors.white,
        ),
        // iOS-specific player optimizations
        allowedScreenSleep: false,
        autoDetectFullscreenDeviceOrientation: true,
        autoDetectFullscreenAspectRatio: true,
        // Event handling
        eventListener: (BetterPlayerEvent event) {
          Logger.d("Video player event: ${event.betterPlayerEventType}");

          if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Video playback error occurred';
            });
          }
        },
        // Hide subtitle tracks for cleaner interface
        subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(
          fontSize: 16,
          fontColor: Colors.white,
          backgroundColor: Colors.black.withOpacity(0.7),
        ),
      );

      // Configure data source
      final betterPlayerDataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.videoUrl,
        // Video metadata
        videoFormat: BetterPlayerVideoFormat.other,
        notificationConfiguration: BetterPlayerNotificationConfiguration(
          showNotification: false, // Disable for security
        ),
        // Headers for authentication if needed
        headers: {'User-Agent': 'BriffiniAcademy/1.0'},
      );

      // Create controller
      _betterPlayerController = BetterPlayerController(
        betterPlayerConfiguration,
        betterPlayerDataSource: betterPlayerDataSource,
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      Logger.i("✅ iOS optimized video player initialized successfully");
    } catch (e) {
      Logger.e('❌ Error initializing iOS video player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize video player: ${e.toString()}';
          _isInitialized = false;
        });
      }
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 200,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              'Video Error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initializePlayer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermarkOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Transform.rotate(
              angle: -0.3,
              child: Text(
                'Briffini Academy\n${widget.userName}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(_errorMessage ?? 'Unknown error');
    }

    if (!_isInitialized || _betterPlayerController == null) {
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: _betterPlayerController!),
            ),
            // Add watermark overlay
            _buildWatermarkOverlay(),
          ],
        ),
      ],
    );
  }
}
