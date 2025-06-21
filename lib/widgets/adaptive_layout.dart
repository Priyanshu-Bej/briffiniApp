import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../utils/responsive_helper.dart';

/// A widget that adapts to screen orientation and platform differences
class AdaptiveLayout extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final bool extendBodyBehindAppBar;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final EdgeInsets? padding;

  const AdaptiveLayout({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.extendBodyBehindAppBar = false,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = ResponsiveHelper.isLandscape(context);

    // Different padding for landscape and portrait modes
    final effectivePadding =
        padding ??
        (isLandscape
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 16));

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      // SafeArea provides padding for system UI elements
      body: SafeArea(
        // Apply adaptive padding based on orientation
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
  }
}

/// A responsive container that adapts to different screen sizes
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final Alignment alignment;
  final Color? backgroundColor;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding = const EdgeInsets.all(16),
    this.alignment = Alignment.center,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A platform-adaptive bottom navigation bar
class AdaptiveBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;

  const AdaptiveBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    // Adjust padding for iOS vs Android
    final bottomMargin = Platform.isIOS ? bottomPadding : bottomPadding + 8;

    return Container(
      margin: EdgeInsets.only(left: 20, right: 20, bottom: bottomMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26), // 0.1 opacity
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          items: items,
          currentIndex: currentIndex,
          selectedItemColor: const Color(0xFF778FF0),
          unselectedItemColor: const Color(0xFF565E6C),
          onTap: onTap,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 0,
          unselectedFontSize: 0,
          showSelectedLabels: false,
          showUnselectedLabels: false,
        ),
      ),
    );
  }
}

/// A platform-adaptive loading indicator
class AdaptiveLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;

  const AdaptiveLoadingIndicator({super.key, this.color, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).primaryColor;

    if (Platform.isIOS) {
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Theme(
            data: ThemeData(
              cupertinoOverrideTheme: CupertinoThemeData(
                primaryColor: effectiveColor,
              ),
            ),
            child: const CircularProgressIndicator.adaptive(),
          ),
        ),
      );
    } else {
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
            strokeWidth: 3.0,
          ),
        ),
      );
    }
  }
}

/// A card with adaptive styling based on platform
class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? Colors.white;
    final borderRadius = BorderRadius.circular(12);

    // Different card styling based on platform
    final elevation = Platform.isIOS ? 1.0 : 2.0;
    final shadowColor =
        Platform.isIOS
            ? Colors.black.withAlpha(26) // 0.1 opacity
            : Colors.black.withAlpha(51); // 0.2 opacity

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 2),
              blurRadius: elevation * 2,
              spreadRadius: elevation / 2,
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
