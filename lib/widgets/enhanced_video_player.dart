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
    // Only dispose if not in fullscreen mode to prevent controller disposal during navigation
    if (!_isFullscreen) {
      _disposePlayer();
    }
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

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
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
      // Exit fullscreen
      _exitFullscreen();
    }
  }

  void _enterFullscreen() {
    // Prevent disposal during fullscreen by removing lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return _FullscreenVideoPlayer(
                controller: _controller!,
                userName: widget.userName,
                title: widget.title,
                onExit: _exitFullscreen,
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
          // When fullscreen is exited, restore lifecycle observer and ensure proper state
          Logger.i(
            '🔄 Fullscreen route completed - restoring embedded player state',
          );

          if (mounted) {
            // Restore lifecycle observer
            WidgetsBinding.instance.addObserver(this);

            // Force portrait orientation again to ensure we're not stuck in landscape
            try {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
              ]);
              Logger.i('✅ Final portrait orientation enforced');
            } catch (e) {
              Logger.e('❌ Error enforcing final portrait: $e');
            }

            // Small delay to ensure orientation takes effect, then restore all orientations
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                try {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                  Logger.i('✅ All orientations restored in .then() callback');
                } catch (e) {
                  Logger.e('❌ Error restoring orientations in callback: $e');
                }
              }
            });

            // Update state to embedded mode
            setState(() {
              _isFullscreen = false;
              _isTransitioning = false;
            });
            Logger.i('✅ Embedded player state restored');
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

  void _exitFullscreen() {
    Logger.i('🚪 _exitFullscreen called - attempting to exit fullscreen');

    // Immediately restore system UI and orientation FIRST
    Logger.i('🔧 Restoring system UI and orientation BEFORE navigation');
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      Logger.i('✅ System UI restored');

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      Logger.i('✅ Orientation preferences restored');
    } catch (e) {
      Logger.e('❌ Error restoring system UI: $e');
    }

    // Force back to portrait immediately
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      Logger.i('✅ Forced portrait orientation');
    } catch (e) {
      Logger.e('❌ Error forcing portrait: $e');
    }

    // Small delay to let orientation change take effect, then navigate
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        // Force exit fullscreen regardless of canPop status
        if (Navigator.of(context).canPop()) {
          Logger.i('✅ Navigator can pop - calling pop()');
          Navigator.of(context).pop();
        } else {
          Logger.w('⚠️ Navigator cannot pop - force popping');
          Navigator.pop(context);
        }
        Logger.i('✅ Navigation pop completed');
      } catch (e) {
        Logger.e('❌ Error during navigation pop: $e');
        // Force state reset if navigation fails
        if (mounted) {
          setState(() {
            _isFullscreen = false;
            _isTransitioning = false;
          });
          Logger.i('🔄 Forced local state reset');
        }
      }
    });

    // Final cleanup
    Future.delayed(const Duration(milliseconds: 300), () {
      _isTransitioning = false;
      // Restore all orientations after portrait is established
      try {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        Logger.i('✅ All orientations restored');
      } catch (e) {
        Logger.e('❌ Error restoring all orientations: $e');
      }

      if (!mounted) {
        _disposePlayer();
      }
    });
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

/// Dedicated fullscreen video player widget
class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String userName;
  final String? title;
  final VoidCallback onExit;

  const _FullscreenVideoPlayer({
    required this.controller,
    required this.userName,
    required this.onExit,
    this.title,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // Add listener for immediate UI updates
    widget.controller.addListener(_onControllerStateChange);
    // Auto-hide controls after showing for 3 seconds
    _showControlsTemporarily();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChange);
    super.dispose();
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
            widget.controller.value.isInitialized &&
            widget.controller.value.isPlaying) {
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

      final controller = widget.controller;
      if (!controller.value.isInitialized) return;

      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }

      // Immediate UI update to eliminate delay
      setState(() {
        // Force rebuild with new controller state
      });
    } catch (e) {
      Logger.w('Error toggling play/pause in fullscreen: $e');
      // Close fullscreen if controller is disposed
      widget.onExit();
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
      if (!widget.controller.value.isInitialized) {
        return const SizedBox.shrink();
      }

      final position = widget.controller.value.position;
      final duration = widget.controller.value.duration;
      final isPlaying = widget.controller.value.isPlaying;

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
                          Logger.i(
                            '🔄 Exit fullscreen button pressed - restoring UI and navigation',
                          );

                          // Immediate UI restoration
                          try {
                            SystemChrome.setEnabledSystemUIMode(
                              SystemUiMode.manual,
                              overlays: SystemUiOverlay.values,
                            );
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.portraitUp,
                            ]);
                            Logger.i('✅ System UI restored immediately');
                          } catch (e) {
                            Logger.e('❌ Error restoring UI: $e');
                          }

                          // Delay navigation to allow UI to settle
                          Future.delayed(const Duration(milliseconds: 50), () {
                            try {
                              if (Navigator.of(context).canPop()) {
                                Logger.i('🚪 Direct navigation pop');
                                Navigator.of(context).pop();
                              } else {
                                Logger.i('🚪 Forced navigation pop');
                                Navigator.pop(context);
                              }
                              Logger.i('✅ Navigation completed');
                            } catch (e) {
                              Logger.e(
                                '❌ Navigation failed: $e, using callback',
                              );
                              widget.onExit();
                            }
                          });
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
                                  '🔄 InkWell Exit fullscreen - immediate UI restore and navigation',
                                );

                                // Immediate UI restoration
                                try {
                                  SystemChrome.setEnabledSystemUIMode(
                                    SystemUiMode.manual,
                                    overlays: SystemUiOverlay.values,
                                  );
                                  SystemChrome.setPreferredOrientations([
                                    DeviceOrientation.portraitUp,
                                  ]);
                                  Logger.i('✅ InkWell System UI restored');
                                } catch (e) {
                                  Logger.e('❌ InkWell Error restoring UI: $e');
                                }

                                // Quick navigation
                                Future.delayed(
                                  const Duration(milliseconds: 50),
                                  () {
                                    try {
                                      if (Navigator.of(context).canPop()) {
                                        Logger.i('🚪 InkWell navigation pop');
                                        Navigator.of(context).pop();
                                      } else {
                                        Logger.i(
                                          '🚪 InkWell forced navigation pop',
                                        );
                                        Navigator.pop(context);
                                      }
                                      Logger.i(
                                        '✅ InkWell Navigation completed',
                                      );
                                    } catch (e) {
                                      Logger.e(
                                        '❌ InkWell Navigation failed: $e, using callback',
                                      );
                                      widget.onExit();
                                    }
                                  },
                                );
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
                        widget.controller,
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
          widget.onExit();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _showControlsTemporarily,
          onDoubleTap: () {
            Logger.i('👆 Double tap detected - immediate UI restore and exit');

            // Immediate UI restoration
            try {
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.manual,
                overlays: SystemUiOverlay.values,
              );
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
              ]);
              Logger.i('✅ Double tap UI restored');
            } catch (e) {
              Logger.e('❌ Double tap UI restore failed: $e');
            }

            // Quick navigation
            Future.delayed(const Duration(milliseconds: 50), () {
              try {
                Navigator.of(context).pop();
                Logger.i('✅ Double tap navigation completed');
              } catch (e) {
                Logger.w('❌ Double tap navigation failed: $e, using callback');
                widget.onExit();
              }
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player centered and fitted
              Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),
              // Watermark overlay
              _buildWatermarkOverlay(),
              // Fullscreen controls
              _buildFullscreenControls(),
            ],
          ),
        ),
      ),
    );
  }
}
