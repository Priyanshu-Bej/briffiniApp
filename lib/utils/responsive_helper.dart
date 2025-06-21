import 'dart:io';
import 'package:flutter/material.dart';

/// A utility class to handle responsive design and platform-specific adjustments
class ResponsiveHelper {
  /// Determines if the current device is a tablet based on screen width
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600;
  }

  /// Returns true if the device is running iOS
  static bool isIOS() => Platform.isIOS;

  /// Returns true if the device is running Android
  static bool isAndroid() => Platform.isAndroid;

  /// Get padding that's safe for all devices including notches and system bars
  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get bottom padding for navigation (useful for bottom sheets and bottom navigation)
  static double bottomInset(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Returns appropriate font size based on screen size
  static double adaptiveFontSize(BuildContext context, double size) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375; // Using iPhone 8 as baseline

    // Ensure font doesn't get too small or too large
    return size * (scale.clamp(0.8, 1.2));
  }

  /// Returns an appropriately sized widget padding based on screen size
  static EdgeInsets adaptivePadding(
    BuildContext context, {
    double small = 8.0,
    double medium = 16.0,
    double large = 24.0,
  }) {
    if (isTablet(context)) {
      return EdgeInsets.all(large);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 400) {
      return EdgeInsets.all(medium);
    }

    return EdgeInsets.all(small);
  }

  /// Returns width percentage of screen width
  static double widthPercent(BuildContext context, double percent) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * (percent / 100);
  }

  /// Returns height percentage of screen height
  static double heightPercent(BuildContext context, double percent) {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight * (percent / 100);
  }

  /// Provides platform-specific values
  static T platformSpecific<T>({required T android, required T ios}) {
    return Platform.isIOS ? ios : android;
  }

  /// Gets current device orientation
  static Orientation getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation;
  }

  /// Checks if the device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
}
