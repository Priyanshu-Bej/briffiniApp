import 'dart:io';
import 'package:flutter/material.dart';

/// A utility class to handle responsive design and platform-specific adjustments
/// Optimized for iPhone 11+ compatibility including iPhone 16 lineup (5.4" to 6.9" screens)
class ResponsiveHelper {
  // iPhone screen size categories - Updated for iPhone 16 lineup
  static const double _compactWidth = 375.0; // iPhone 12/13 mini base
  static const double _regularWidth = 393.0; // iPhone 14/15/16 base (updated)
  static const double _proWidth = 402.0; // iPhone 16 Pro (6.3") - New size
  static const double _largeWidth = 428.0; // iPhone 14/15 Pro Max base
  static const double _extraLargeWidth = 440.0; // iPhone 16 Pro Max (6.9") - New size
  
  /// Determines if the current device is a tablet based on screen width
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600;
  }

  /// Returns true if the device is running iOS
  static bool isIOS() => Platform.isIOS;

  /// Returns true if the device is running Android
  static bool isAndroid() => Platform.isAndroid;

  /// Determines iPhone size category for responsive design (Updated for iPhone 16)
  static IPhoneSize getIPhoneSize(BuildContext context) {
    if (!Platform.isIOS) return IPhoneSize.regular;
    
    final width = MediaQuery.of(context).size.width;
    if (width <= _compactWidth) return IPhoneSize.compact; // iPhone 12/13 mini
    if (width <= _regularWidth) return IPhoneSize.regular; // iPhone 14/15/16 standard
    if (width <= _proWidth) return IPhoneSize.pro; // iPhone 16 Pro (6.3")
    if (width <= _largeWidth) return IPhoneSize.large; // iPhone 14/15 Pro Max
    return IPhoneSize.extraLarge; // iPhone 16 Pro Max (6.9")
  }

  /// Check if device has Dynamic Island (iPhone 14 Pro+, iPhone 15 series, iPhone 16 series)
  static bool hasDynamicIsland(BuildContext context) {
    if (!Platform.isIOS) return false;
    
    final padding = MediaQuery.of(context).padding;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Dynamic Island devices have specific characteristics
    // iPhone 16 series all have Dynamic Island, including base models
    final hasModernDimensions = screenHeight > 800 && screenWidth >= 375;
    final hasDeepStatusBar = padding.top > 47;
    
    return hasModernDimensions && hasDeepStatusBar;
  }

  /// Check if device is iPhone 16 Pro Max (largest screen)
  static bool isIPhone16ProMax(BuildContext context) {
    if (!Platform.isIOS) return false;
    final width = MediaQuery.of(context).size.width;
    return width >= _extraLargeWidth;
  }

  /// Get padding that's safe for all devices including notches and Dynamic Island
  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get bottom padding for navigation (useful for bottom sheets and bottom navigation)
  static double bottomInset(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Get status bar height accounting for notch/Dynamic Island
  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Get bottom safe area height for home indicator
  static double getBottomSafeAreaHeight(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  /// Returns appropriate font size based on iPhone screen size (Updated for iPhone 16)
  static double adaptiveFontSize(BuildContext context, double size) {
    final IPhoneSize iPhoneSize = getIPhoneSize(context);
    
    switch (iPhoneSize) {
      case IPhoneSize.compact:
        return size * 0.9; // iPhone 12/13 mini
      case IPhoneSize.regular:
        return size; // iPhone 14/15/16 standard
      case IPhoneSize.pro:
        return size * 1.05; // iPhone 16 Pro (6.3") - slightly larger
      case IPhoneSize.large:
        return size * 1.1; // iPhone 14/15 Pro Max
      case IPhoneSize.extraLarge:
        return size * 1.15; // iPhone 16 Pro Max (6.9") - largest scale
    }
  }

  /// Ensures minimum touch target size for iOS (44pt)
  static BoxConstraints getMinTouchTarget() {
    return const BoxConstraints(
      minWidth: 44.0,
      minHeight: 44.0,
    );
  }

  /// Get touch target constraints with larger size for better accessibility
  static BoxConstraints getLargeTouchTarget() {
    return const BoxConstraints(
      minWidth: 48.0,
      minHeight: 48.0,
    );
  }

  /// Returns an appropriately sized widget padding based on iPhone screen size (Updated for iPhone 16)
  static EdgeInsets adaptivePadding(
    BuildContext context, {
    double small = 8.0,
    double medium = 16.0,
    double large = 24.0,
    double extraLarge = 28.0,
  }) {
    if (isTablet(context)) {
      return EdgeInsets.all(extraLarge);
    }

    final IPhoneSize iPhoneSize = getIPhoneSize(context);
    
    switch (iPhoneSize) {
      case IPhoneSize.compact:
        return EdgeInsets.all(small);
      case IPhoneSize.regular:
      return EdgeInsets.all(medium);
      case IPhoneSize.pro:
        return EdgeInsets.all(large * 1.1); // iPhone 16 Pro
      case IPhoneSize.large:
        return EdgeInsets.all(large);
      case IPhoneSize.extraLarge:
        return EdgeInsets.all(extraLarge); // iPhone 16 Pro Max
    }
  }

  /// Get horizontal padding that adapts to screen width (Updated for iPhone 16)
  static EdgeInsets getScreenHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width <= _compactWidth) {
      return const EdgeInsets.symmetric(horizontal: 16.0); // iPhone mini
    } else if (width <= _regularWidth) {
      return const EdgeInsets.symmetric(horizontal: 20.0); // iPhone standard
    } else if (width <= _proWidth) {
      return const EdgeInsets.symmetric(horizontal: 22.0); // iPhone 16 Pro
    } else if (width <= _largeWidth) {
      return const EdgeInsets.symmetric(horizontal: 24.0); // Pro Max
    } else {
      return const EdgeInsets.symmetric(horizontal: 28.0); // iPhone 16 Pro Max
    }
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

  /// Get safe content height (total height minus status bar and bottom safe area)
  static double getSafeContentHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    return size.height - padding.top - padding.bottom;
  }

  /// Get adaptive spacing based on screen size (Updated for iPhone 16)
  static double getAdaptiveSpacing(BuildContext context, {
    double compact = 8.0,
    double regular = 12.0,
    double pro = 14.0,
    double large = 16.0,
    double extraLarge = 20.0,
  }) {
    final IPhoneSize iPhoneSize = getIPhoneSize(context);
    
    switch (iPhoneSize) {
      case IPhoneSize.compact:
        return compact;
      case IPhoneSize.regular:
        return regular;
      case IPhoneSize.pro:
        return pro; // iPhone 16 Pro
      case IPhoneSize.large:
        return large;
      case IPhoneSize.extraLarge:
        return extraLarge; // iPhone 16 Pro Max
    }
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

  /// Get adaptive border radius based on screen size (Updated for iPhone 16)
  static BorderRadius getAdaptiveBorderRadius(BuildContext context, {
    double compact = 8.0,
    double regular = 12.0,
    double pro = 14.0,
    double large = 16.0,
    double extraLarge = 18.0,
  }) {
    final radius = getAdaptiveSpacing(context, 
      compact: compact, 
      regular: regular,
      pro: pro,
      large: large,
      extraLarge: extraLarge,
    );
    return BorderRadius.circular(radius);
  }

  /// Check if current screen requires special notch/Dynamic Island handling
  static bool requiresTopSafeAreaHandling(BuildContext context) {
    return Platform.isIOS && getStatusBarHeight(context) > 20;
  }

  /// Get card elevation based on platform and screen size (Updated for iPhone 16)
  static double getAdaptiveElevation(BuildContext context) {
    if (Platform.isAndroid) return 4.0;
    
    // iOS uses subtle shadows, vary by screen size
    final IPhoneSize iPhoneSize = getIPhoneSize(context);
    switch (iPhoneSize) {
      case IPhoneSize.compact:
        return 1.0;
      case IPhoneSize.regular:
        return 2.0;
      case IPhoneSize.pro:
        return 2.5; // iPhone 16 Pro
      case IPhoneSize.large:
        return 3.0;
      case IPhoneSize.extraLarge:
        return 3.5; // iPhone 16 Pro Max
    }
  }
}

/// Enum for iPhone size categories (Updated for iPhone 16 lineup)
enum IPhoneSize {
  compact,     // iPhone 12/13 mini (5.4")
  regular,     // iPhone 14/15/16 standard (6.1")
  pro,         // iPhone 16 Pro (6.3") - New category
  large,       // iPhone 14/15 Pro Max (6.5"-6.7")
  extraLarge,  // iPhone 16 Pro Max (6.9") - New category
}
