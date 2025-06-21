import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for handling accessibility features and device accommodations
class AccessibilityHelper {
  /// Returns the current text scale factor from MediaQuery
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.of(context).textScaler.scale(1.0);
  }

  /// Determines if large text is enabled in the device accessibility settings
  static bool isLargeTextEnabled(BuildContext context) {
    final scaleFactor = getTextScaleFactor(context);
    return scaleFactor > 1.2; // Threshold for "large text"
  }

  /// Gets a font size that respects the system's accessibility settings
  /// but caps it to prevent text overflow in UI
  static double getAccessibleFontSize(
    BuildContext context,
    double baseFontSize, {
    double? minSize,
    double? maxSize,
  }) {
    final scaleFactor = getTextScaleFactor(context);
    final scaledSize = baseFontSize * scaleFactor;

    if (minSize != null && scaledSize < minSize) {
      return minSize;
    }

    if (maxSize != null && scaledSize > maxSize) {
      return maxSize;
    }

    return scaledSize;
  }

  /// Creates a TextStyle that respects accessibility settings
  static TextStyle getAccessibleTextStyle(
    BuildContext context,
    TextStyle baseStyle, {
    double? minSize,
    double? maxSize,
  }) {
    if (baseStyle.fontSize == null) {
      return baseStyle;
    }

    final accessibleSize = getAccessibleFontSize(
      context,
      baseStyle.fontSize!,
      minSize: minSize,
      maxSize: maxSize,
    );

    return baseStyle.copyWith(fontSize: accessibleSize);
  }

  /// Dismisses the keyboard when called
  static void dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Returns whether the keyboard is currently visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Sets the preferred device orientation
  static void setPreferredOrientations(List<DeviceOrientation> orientations) {
    SystemChrome.setPreferredOrientations(orientations);
  }

  /// Resets to allow all orientations
  static void resetOrientations() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Configures the status bar and navigation bar appearance
  static void configureSystemUI({
    Color? statusBarColor,
    Brightness? statusBarIconBrightness,
    Color? navigationBarColor,
    Brightness? navigationBarIconBrightness,
    bool? statusBarVisible,
  }) {
    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: statusBarIconBrightness,
      systemNavigationBarColor: navigationBarColor,
      systemNavigationBarIconBrightness: navigationBarIconBrightness,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    if (statusBarVisible != null) {
      final overlays = <SystemUiOverlay>[];
      if (statusBarVisible) {
        overlays.add(SystemUiOverlay.top);
      }
      overlays.add(SystemUiOverlay.bottom);

      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: overlays,
      );
    }
  }

  /// Shows the status bar
  static void showStatusBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  /// Hides the status bar
  static void hideStatusBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
  }
}
