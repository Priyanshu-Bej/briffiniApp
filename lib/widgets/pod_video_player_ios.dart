import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pod_player/pod_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/logger.dart';
import '../utils/responsive_helper.dart';

/// iOS-optimized video player using PodPlayer
/// Provides superior performance, smooth playback, and modern UI controls
class PodVideoPlayerIOS extends StatefulWidget {
  final String videoUrl;
  final String userName;
  final String? title;
  final bool autoPlay;
  final bool showControls;
  final Function()? onVideoCompleted;
  final Function(Duration)? onProgress;

  const PodVideoPlayerIOS({
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
  State<PodVideoPlayerIOS> createState() => _PodVideoPlayerIOSState();
}

class _PodVideoPlayerIOSState extends State<PodVideoPlayerIOS>
    with WidgetsBindingObserver {
  late PodPlayerController _podController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isFullscreen = false;

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
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isInitialized) {
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          _podController.pause();
          WakelockPlus.disable();
          break;
        case AppLifecycleState.resumed:
          // Don't auto-resume to respect user's choice
          if (_podController.isVideoPlaying) {
            WakelockPlus.enable();
          }
          break;
        case AppLifecycleState.inactive:
          // Do nothing for inactive state
          break;
      }
    }
  }

  void _disposePlayer() {
    try {
      _podController.dispose();
    } catch (e) {
      Logger.w('Warning disposing Pod video player: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    try {
      Logger.i("🎬 Initializing Pod video player for iOS: ${widget.videoUrl}");

      // Configure PodPlayer for optimal iOS performance
      _podController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(
          widget.videoUrl,
          httpHeaders: {
            'User-Agent': 'BriffiniAcademy/1.0',
            'Referer': 'https://briffini.academy',
          },
        ),
        podPlayerConfig: PodPlayerConfig(
          autoPlay: widget.autoPlay,
          isLooping: false,
          // iOS-specific optimizations
          forcedVideoFocus: true,
          wakelockEnabled: true,
        ),
      )..addListener(_videoListener);

      // Initialize the controller
      await _podController.initialise();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      Logger.i("✅ Pod video player initialized successfully for iOS");
    } catch (e) {
      Logger.e('❌ Error initializing Pod video player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize video player: ${e.toString()}';
          _isInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;

    final podController = _podController;

    // Handle video completion
    if (podController.currentVideoPosition == podController.totalVideoLength &&
        podController.totalVideoLength > Duration.zero) {
      widget.onVideoCompleted?.call();
      WakelockPlus.disable();
    }

    // Handle progress updates
    if (widget.onProgress != null) {
      widget.onProgress!(podController.currentVideoPosition);
    }

    // Handle fullscreen changes
    if (podController.isFullScreen != _isFullscreen) {
      setState(() {
        _isFullscreen = podController.isFullScreen;
      });

      if (_isFullscreen) {
        // iOS fullscreen optimizations
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        WakelockPlus.enable();
      } else {
        // Exit fullscreen
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }

    // Handle play/pause for wakelock
    if (podController.isVideoPlaying) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
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
              'Optimizing for iOS',
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
        if (widget.title != null && !_isFullscreen) ...[
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
          borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 12),
          child: Stack(
            children: [
              PodVideoPlayer(
                controller: _podController,
                backgroundColor: Colors.black,
                videoAspectRatio: 16 / 9,
                frameAspectRatio: 16 / 9,
                alwaysShowProgressBar: true,
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
