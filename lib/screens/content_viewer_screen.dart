// This file provides conditional exports for platform-specific implementations
// For web, it will use content_viewer_screen_web.dart
// For all other platforms, it will use content_viewer_screen_mobile.dart

export 'content_viewer_screen_mobile.dart'
    if (dart.library.html) 'content_viewer_screen_web.dart';
