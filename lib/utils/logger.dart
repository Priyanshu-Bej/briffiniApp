import 'package:flutter/foundation.dart';

/// Simple logger utility to replace print statements
/// Usage: Logger.d('Debug message');
///
/// In production builds, only warning and error logs will be shown
class Logger {
  /// Log debug message (only in debug mode)
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('DEBUG: $message');
    }
  }

  /// Log info message (only in debug mode)
  static void i(String message) {
    if (kDebugMode) {
      debugPrint('INFO: $message');
    }
  }

  /// Log warning message (always shown)
  static void w(String message) {
    debugPrint('WARNING: $message');
  }

  /// Log error message (always shown)
  static void e(String message) {
    debugPrint('ERROR: $message');
  }
}
