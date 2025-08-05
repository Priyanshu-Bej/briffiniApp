import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/logger.dart';

/// Simple, robust video player using only video_player package
/// Fixed orientation and layout issues
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
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isTransitioning = false; // Prevent multiple transitions

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Always dispose player when widget is actually being disposed
    // The fullscreen state check is no longer needed since we keep lifecycle active
    _disposePlayer();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isInitialized && _controller != null && mounted) {
      try {
        switch (state) {
          case AppLifecycleState.paused:
          case AppLifecycleState.detached:
          case AppLifecycleState.hidden:
            _controller!.pause();
            WakelockPlus.disable();
            break;
          case AppLifecycleState.resumed:
            // Don't auto-resume to respect user's choice
            if (_controller!.value.isPlaying) {
              WakelockPlus.enable();
            }
            break;
          case AppLifecycleState.inactive:
            // Do nothing on inactive
            break;
        }
      } catch (e) {
        Logger.e('Error handling app lifecycle state change: $e');
      }
    }
  }

  void _disposePlayer() {
    try {
      _isInitialized = false;
      _isTransitioning = false; // Reset transition flag
      _controller?.removeListener(_videoListener);
      _controller?.removeListener(_onControllerStateChange);
      _controller?.dispose();
      _controller = null;
      WakelockPlus.disable();
    } catch (e) {
      Logger.w('Warning disposing video player: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted || _isInitialized || _isInitializing || _isTransitioning)
      return;

    _isInitializing = true;

    try {
      Logger.i("🎬 Initializing video player: ${widget.videoUrl}");

      // Dispose any existing controller first
      _disposePlayer();

      if (!mounted || _isTransitioning) {
        _isInitializing = false;
        return;
      }

      // Initialize video player controller
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'User-Agent': 'BriffiniAcademy/1.0',
          'Referer': 'https://briffini.academy',
        },
      );

      await _controller!.initialize();

      if (!mounted) {
        _isInitializing = false;
        return;
      }

      // Add listener for progress updates and completion
      _controller!.addListener(_videoListener);

      // Add listener for immediate UI updates (responsive controls)
      _controller!.addListener(_onControllerStateChange);

      // Auto play if requested
      if (widget.autoPlay) {
        _controller!.play();
        WakelockPlus.enable();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      Logger.i("✅ Video player initialized successfully");
    } catch (e) {
      Logger.e('❌ Error initializing video player: $e');

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
    if (!mounted || _controller == null || !_isInitialized) return;

    try {
      final controller = _controller!;
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
    } catch (e) {
      Logger.w('Error in video listener: $e');
    }
  }

  void _onControllerStateChange() {
    // Force UI update when controller state changes for responsive controls
    if (mounted && _controller != null) {
      setState(() {
        // UI will rebuild with new controller state
      });
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;

    try {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        Logger.i('⏸️ Video paused in embedded player');
      } else {
        _controller!.play();
        Logger.i('▶️ Video resumed in embedded player');
      }

      // Immediate UI update for responsive play/pause button
      setState(() {
        // Force rebuild with new controller state
      });
    } catch (e) {
      Logger.e('❌ Error toggling play/pause in embedded player: $e');
    }
  }

  void _toggleFullscreen() {
    if (!_isInitialized || _controller == null || _isTransitioning) return;

    _isTransitioning = true;
    Logger.i('🔄 Toggling fullscreen: ${!_isFullscreen}');

    if (!_isFullscreen) {
      // Enter fullscreen - navigate to fullscreen page
      _enterFullscreen();
    } else {
      // Exit fullscreen - this should be handled by the fullscreen widget itself
      Logger.w(
        '⚠️ Exit fullscreen called from main widget - this should be handled by fullscreen widget',
      );
      // Force exit fullscreen state in case of issues
      setState(() {
        _isFullscreen = false;
        _isTransitioning = false;
      });
    }
  }

  void _enterFullscreen() {
    Logger.i('🔄 Entering fullscreen - preserving controller state');

    // Store controller state before fullscreen
    final currentPosition = _controller!.value.position;
    final wasPlaying = _controller!.value.isPlaying;
    final videoUrl = widget.videoUrl;

    Logger.i(
      '📊 Storing video state: position=${currentPosition.inSeconds}s, playing=$wasPlaying',
    );

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return _FullscreenVideoPlayer(
                videoUrl: videoUrl,
                initialPosition: currentPosition,
                wasPlaying: wasPlaying,
                userName: widget.userName,
                title: widget.title,
                onExit: (Duration? exitPosition, bool wasPlayingOnExit) {
                  _exitFullscreen(exitPosition, wasPlayingOnExit);
                },
              );
            },
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
            barrierDismissible: true, // Allow tap outside to dismiss
            fullscreenDialog: true,
            opaque: false, // Allow background to show through
          ),
        )
        .then((_) {
          // Fullscreen exit might be handled by direct navigation or callback
          Logger.i(
            '🔄 Fullscreen route completed - ensuring proper state restoration',
          );

          if (mounted) {
            // Restore state in case fullscreen widget exited directly without callback
            setState(() {
              _isFullscreen = false;
              _isTransitioning = false;
            });

            // Restore system UI as fallback
            try {
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.manual,
                overlays: SystemUiOverlay.values,
              );
              Logger.i('✅ System UI restored via fallback');
            } catch (e) {
              Logger.e('❌ Error restoring system UI via fallback: $e');
            }

            // Restore orientations as fallback
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                try {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                  Logger.i('✅ All orientations restored via fallback');
                } catch (e) {
                  Logger.e('❌ Error restoring orientations via fallback: $e');
                }
              }
            });

            Logger.i('✅ Fullscreen state restoration completed');
          }
        });

    setState(() {
      _isFullscreen = true;
    });

    // Set system UI for fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullscreen(Duration? position, bool wasPlayingOnExit) {
    Logger.i('🚪 _exitFullscreen called - restoring video state');
    Logger.i(
      '📊 Received state: position=${position?.inSeconds ?? 0}s, wasPlaying=$wasPlayingOnExit',
    );

    // Check if we're still mounted before doing anything
    if (!mounted) {
      Logger.w(
        '⚠️ Widget unmounted - this is expected if parent widget was rebuilt during fullscreen',
      );
      // Don't try to restore state to unmounted widget - the new widget will handle this
      return;
    }

    // Restore system UI (this affects the global app state)
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      Logger.i('✅ System UI restored');
    } catch (e) {
      Logger.e('❌ Error restoring system UI: $e');
    }

    // Restore main controller state if we have a valid controller
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        // Seek to the position from fullscreen
        if (position != null && position > Duration.zero) {
          _controller!.seekTo(position);
          Logger.i('✅ Video position restored: ${position.inSeconds}s');
        }

        // Always pause when exiting fullscreen to prevent background audio
        _controller!.pause();
        Logger.i('⏸️ Video paused (preventing background audio)');
      } catch (e) {
        Logger.e('❌ Error restoring video state: $e');
      }
    }

    // Update widget state if still mounted
    if (mounted) {
      setState(() {
        _isFullscreen = false;
        _isTransitioning = false;
      });
      Logger.i('✅ Embedded player state restored');
    }

    // Restore all orientations (affects global app state)
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        Logger.i('✅ All orientations restored');
      } catch (e) {
        Logger.e('❌ Error restoring orientations: $e');
      }
    });

    Logger.i('✅ Exit fullscreen callback completed');
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    // Hide controls after 3 seconds if playing
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildWatermarkOverlay() {
    return Positioned(
      top: _isFullscreen ? 60 : 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    if (!_isInitialized || _controller == null || !_showControls) {
      return const SizedBox.shrink();
    }

    final controller = _controller!;
    final position = controller.value.position;
    final duration = controller.value.duration;
    final isPlaying = controller.value.isPlaying;

    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top controls
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (widget.title != null && !_isFullscreen)
                      Expanded(
                        child: Text(
                          widget.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _toggleFullscreen,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isFullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Center play/pause button
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF1A237E),
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Time indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String? error) {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error ?? 'Failed to load video',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializePlayer,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(_errorMessage);
    }

    if (!_isInitialized) {
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
          ),
        ),
      );
    }

    // Normal embedded video player
    return GestureDetector(
      onTap: _showControlsTemporarily,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            children: [
              VideoPlayer(_controller!),
              _buildWatermarkOverlay(),
              _buildVideoControls(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dedicated fullscreen video player widget with independent controller
class _FullscreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Duration initialPosition;
  final bool wasPlaying;
  final String userName;
  final String? title;
  final Function(Duration? position, bool wasPlaying) onExit;

  const _FullscreenVideoPlayer({
    required this.videoUrl,
    required this.initialPosition,
    required this.wasPlaying,
    required this.userName,
    required this.onExit,
    this.title,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _showControls = true;
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      Logger.i('🎬 Initializing fullscreen controller for: ${widget.videoUrl}');

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller!.initialize();

      if (mounted) {
        // Add listener for UI updates
        _controller!.addListener(_onControllerStateChange);

        // Seek to the initial position
        if (widget.initialPosition > Duration.zero) {
          await _controller!.seekTo(widget.initialPosition);
          Logger.i(
            '✅ Fullscreen player seeked to: ${widget.initialPosition.inSeconds}s',
          );
        }

        // Start playing if it was playing before
        if (widget.wasPlaying) {
          await _controller!.play();
          Logger.i('▶️ Fullscreen player started playing');
        }

        setState(() {
          _isInitialized = true;
        });

        // Auto-hide controls after showing for 3 seconds
        _showControlsTemporarily();

        Logger.i('✅ Fullscreen controller initialized successfully');
      }
    } catch (e) {
      Logger.e('❌ Error initializing fullscreen controller: $e');
      if (mounted) {
        _exitWithCurrentState();
      }
    }
  }

  @override
  void dispose() {
    Logger.i('🗑️ Disposing fullscreen controller');
    _controller?.removeListener(_onControllerStateChange);
    _controller?.dispose();
    super.dispose();
  }

  void _exitWithCurrentState() {
    Logger.i('🚪 Exiting fullscreen with current state');

    Duration? currentPosition;
    bool isCurrentlyPlaying = false;

    if (_controller != null && _controller!.value.isInitialized) {
      currentPosition = _controller!.value.position;
      isCurrentlyPlaying = _controller!.value.isPlaying;
      Logger.i(
        '📊 Current state: position=${currentPosition.inSeconds}s, playing=$isCurrentlyPlaying',
      );
    }

    // Navigate back immediately - don't rely on callback to unmounted widget
    try {
      if (Navigator.of(context).canPop()) {
        Logger.i('🚪 Direct navigation back from fullscreen');
        Navigator.of(context).pop();
        Logger.i('✅ Successfully navigated back from fullscreen');
      } else {
        Logger.w('⚠️ Cannot pop from fullscreen - no route to pop');
      }
    } catch (e) {
      Logger.e('❌ Error navigating back from fullscreen: $e');
    }

    // Also try the callback as backup (though main widget might be unmounted)
    try {
      widget.onExit(currentPosition, isCurrentlyPlaying);
      Logger.i('✅ Exit callback executed successfully');
    } catch (e) {
      Logger.w('⚠️ Exit callback failed (widget might be unmounted): $e');
    }
  }

  void _onControllerStateChange() {
    // Force UI update when controller state changes
    if (mounted) {
      setState(() {
        // UI will rebuild with new controller state
      });
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      try {
        if (mounted &&
            _controller != null &&
            _controller!.value.isInitialized &&
            _controller!.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      } catch (e) {
        Logger.w('Error hiding controls: $e');
      }
    });
  }

  void _togglePlayPause() {
    try {
      // Check if controller is still valid and not disposed
      if (!mounted) return;

      if (_controller == null || !_controller!.value.isInitialized) return;

      if (_controller!.value.isPlaying) {
        _controller!.pause();
        Logger.i('⏸️ Fullscreen video paused');
      } else {
        _controller!.play();
        Logger.i('▶️ Fullscreen video playing');
      }

      // Immediate UI update to eliminate delay
      setState(() {
        // Force rebuild with new controller state
      });
    } catch (e) {
      Logger.w('Error toggling play/pause in fullscreen: $e');
      // Close fullscreen if controller is disposed
      _exitWithCurrentState();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildWatermarkOverlay() {
    return Positioned(
      top: 60,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          widget.userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenControls() {
    if (!_showControls) return const SizedBox.shrink();

    try {
      // Check if controller is valid and initialized
      if (_controller == null || !_controller!.value.isInitialized) {
        return const SizedBox.shrink();
      }

      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
      final isPlaying = _controller!.value.isPlaying;

      return AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top controls
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Title
                      if (widget.title != null)
                        Expanded(
                          child: Text(
                            widget.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const Spacer(),
                      // Exit fullscreen button
                      GestureDetector(
                        onTap: () {
                          Logger.i('🔄 Exit fullscreen button pressed');
                          _exitWithCurrentState();
                        },
                        child: Container(
                          width: 56, // Larger touch area
                          height: 56,
                          padding: const EdgeInsets.all(4),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Logger.i(
                                  '🔄 InkWell Exit fullscreen button pressed',
                                );
                                _exitWithCurrentState();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.fullscreen_exit,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center play/pause button
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () {
                        Logger.i(
                          '▶️ Play/pause button pressed (currently: ${isPlaying ? 'playing' : 'paused'})',
                        );
                        _togglePlayPause();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom controls
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFF1A237E),
                          bufferedColor: Colors.grey,
                          backgroundColor: Colors.white30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Time indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      Logger.w('Error building fullscreen controls: $e');
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        Logger.i('🔙 Hardware back button pressed in fullscreen');
        if (!didPop) {
          // Try to exit fullscreen manually if automatic pop failed
          Logger.i('🔙 Hardware back - calling exit with current state');
          _exitWithCurrentState();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _showControlsTemporarily,
          onDoubleTap: () {
            Logger.i('👆 Double tap detected - exiting fullscreen');
            _exitWithCurrentState();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player centered and fitted
              if (_isInitialized && _controller != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              // Watermark overlay
              if (_isInitialized) _buildWatermarkOverlay(),
              // Fullscreen controls
              if (_isInitialized) _buildFullscreenControls(),
            ],
          ),
        ),
      ),
    );
  }
}
