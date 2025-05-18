import 'package:flutter/material.dart';

// Custom page route for smooth transitions
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  @override
  final RouteSettings settings;

  SlidePageRoute({required this.page, required this.settings})
    : super(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
}

// Fade transition route
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  @override
  final RouteSettings settings;

  FadePageRoute({required this.page, required this.settings})
    : super(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      );
}

// Main navigation helper class
class AppNavigator {
  // Navigate to a new screen with slide animation
  static Future<T?> navigateTo<T>({
    required BuildContext context,
    required Widget page,
    bool replace = false,
    RouteSettings? settings,
  }) {
    final route = SlidePageRoute<T>(
      page: page,
      settings: settings ?? const RouteSettings(),
    );

    if (replace) {
      return Navigator.pushReplacement(context, route);
    } else {
      return Navigator.push<T>(context, route);
    }
  }

  // Navigate to a new screen with fade animation
  static Future<T?> navigateWithFade<T>({
    required BuildContext context,
    required Widget page,
    bool replace = false,
    RouteSettings? settings,
  }) {
    final route = FadePageRoute<T>(
      page: page,
      settings: settings ?? const RouteSettings(),
    );

    if (replace) {
      return Navigator.pushReplacement(context, route);
    } else {
      return Navigator.push<T>(context, route);
    }
  }
}
