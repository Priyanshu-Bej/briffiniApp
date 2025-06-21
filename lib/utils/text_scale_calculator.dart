import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A utility for managing text scaling across different devices and platforms
class TextScaleCalculator {
  /// The default scale factor for mobile text (1.0)
  static const double defaultScaleFactor = 1.0;

  /// The maximum recommended scale factor to prevent layout issues (1.5)
  static const double maxScaleFactor = 1.5;

  /// The minimum recommended scale factor to ensure readability (0.8)
  static const double minScaleFactor = 0.8;

  /// Calculate a constrained text scale factor to prevent layout issues while respecting accessibility
  static double getConstrainedTextScaleFactor(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaler.scale(1.0);

    // Constrain the scale factor between minimum and maximum values
    return math.max(minScaleFactor, math.min(maxScaleFactor, textScaleFactor));
  }

  /// Apply a constrained text scale factor to the provided text style
  static TextStyle getScaledTextStyle(
    BuildContext context,
    TextStyle baseStyle,
  ) {
    final scaleFactor = getConstrainedTextScaleFactor(context);

    if (baseStyle.fontSize == null) {
      return baseStyle;
    }

    return baseStyle.copyWith(fontSize: baseStyle.fontSize! * scaleFactor);
  }

  /// Wrap a widget with a MediaQuery that applies a constrained text scale factor
  static Widget wrapWithConstrainedTextScale({
    required BuildContext context,
    required Widget child,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final constrainedTextScaleFactor = getConstrainedTextScaleFactor(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(constrainedTextScaleFactor),
      ),
      child: child,
    );
  }

  /// Get a responsive font size based on screen width
  static double getResponsiveFontSize(
    BuildContext context, {
    required double baseFontSize,
    double? minFontSize,
    double? maxFontSize,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0; // iPhone 8 as baseline

    // Calculate responsive font size
    final responsiveFontSize = baseFontSize * scaleFactor;

    // Apply constraints if provided
    if (minFontSize != null && responsiveFontSize < minFontSize) {
      return minFontSize;
    }

    if (maxFontSize != null && responsiveFontSize > maxFontSize) {
      return maxFontSize;
    }

    return responsiveFontSize;
  }

  /// Get a text style with responsive font size
  static TextStyle getResponsiveTextStyle(
    BuildContext context, {
    required TextStyle baseStyle,
    required double baseFontSize,
    double? minFontSize,
    double? maxFontSize,
  }) {
    if (baseStyle.fontSize == null) {
      return baseStyle.copyWith(
        fontSize: getResponsiveFontSize(
          context,
          baseFontSize: baseFontSize,
          minFontSize: minFontSize,
          maxFontSize: maxFontSize,
        ),
      );
    }

    return baseStyle.copyWith(
      fontSize: getResponsiveFontSize(
        context,
        baseFontSize: baseStyle.fontSize!,
        minFontSize: minFontSize,
        maxFontSize: maxFontSize,
      ),
    );
  }
}
