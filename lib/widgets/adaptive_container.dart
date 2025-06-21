import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// A container that adapts its content and layout based on device orientation and screen size
class AdaptiveContainer extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? landscape;
  final Widget? portrait;

  /// Creates an adaptive container that switches between different layouts
  /// based on device orientation and screen size.
  ///
  /// - [mobile]: Default widget to display on small screens (required)
  /// - [tablet]: Widget to display on tablet-sized screens (optional)
  /// - [landscape]: Widget to display in landscape orientation (optional)
  /// - [portrait]: Widget to display in portrait orientation (optional)
  ///
  /// If [tablet] is null, [mobile] will be used on tablet devices.
  /// If [landscape] or [portrait] is null, orientation-specific layout will be ignored.
  const AdaptiveContainer({
    super.key,
    required this.mobile,
    this.tablet,
    this.landscape,
    this.portrait,
  });

  @override
  Widget build(BuildContext context) {
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final isLandscapeMode = ResponsiveHelper.isLandscape(context);

    // Check if we should use orientation-specific widgets
    if (isLandscapeMode && landscape != null) {
      return landscape!;
    }

    if (!isLandscapeMode && portrait != null) {
      return portrait!;
    }

    // If no orientation-specific widgets or they're null, use device-type specific
    if (isTabletDevice && tablet != null) {
      return tablet!;
    }

    // Default to mobile layout
    return mobile;
  }
}

/// A container that applies proper safe area padding based on the device
class SafeContainer extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final Color? backgroundColor;

  /// Creates a container that respects device safe areas (notches, system UI, etc.)
  ///
  /// - [child]: The widget to display inside the safe area
  /// - [top], [bottom], [left], [right]: Whether to apply safe area in that direction
  /// - [backgroundColor]: Optional background color for the container
  const SafeContainer({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: child,
      ),
    );
  }
}

/// A responsive padding widget that adjusts padding based on screen size
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? small;
  final EdgeInsets? medium;
  final EdgeInsets? large;

  /// Creates a padding widget that adjusts based on screen size
  ///
  /// - [child]: The widget to apply padding to
  /// - [small]: Padding for small screens (phones)
  /// - [medium]: Padding for medium screens (large phones)
  /// - [large]: Padding for large screens (tablets)
  const ResponsivePadding({
    super.key,
    required this.child,
    this.small = const EdgeInsets.all(8.0),
    this.medium = const EdgeInsets.all(16.0),
    this.large = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsets padding;

    if (ResponsiveHelper.isTablet(context)) {
      padding = large ?? const EdgeInsets.all(24.0);
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth > 400) {
        padding = medium ?? const EdgeInsets.all(16.0);
      } else {
        padding = small ?? const EdgeInsets.all(8.0);
      }
    }

    return Padding(padding: padding, child: child);
  }
}

/// A widget that provides different layouts based on orientation
class OrientationLayout extends StatelessWidget {
  final Widget portrait;
  final Widget? landscape;

  /// Creates a widget that switches between portrait and landscape layouts
  ///
  /// - [portrait]: Widget to display in portrait mode (required)
  /// - [landscape]: Widget to display in landscape mode (optional)
  ///
  /// If [landscape] is null, [portrait] will be used in landscape mode.
  const OrientationLayout({super.key, required this.portrait, this.landscape});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape && landscape != null) {
          return landscape!;
        }
        return portrait;
      },
    );
  }
}
