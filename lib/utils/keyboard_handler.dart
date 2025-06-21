import 'package:flutter/material.dart';
import 'dart:io';

/// Utility class to handle keyboard display across platforms
class KeyboardHandler {
  /// Dismiss the keyboard when called
  static void dismiss(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Check if the keyboard is currently visible
  static bool isVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Get the current keyboard height
  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Wrap your widget with this to automatically handle keyboard avoidance
  static Widget wrapWithAvoidKeyboard({
    required Widget child,
    required BuildContext context,
    bool scrollable = true,
  }) {
    if (scrollable) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      );
    } else {
      // Use Padding to raise the widget when keyboard appears
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: child,
      );
    }
  }

  /// Gets a widget that includes platform-specific keyboard avoidance
  static Widget avoidKeyboard({
    required Widget child,
    bool autoScroll = true,
    bool expandable = true,
  }) {
    if (Platform.isIOS) {
      // iOS specific handling
      return _IOSKeyboardAvoider(
        autoScroll: autoScroll,
        expandable: expandable,
        child: child,
      );
    } else {
      // Android specific handling
      return _AndroidKeyboardAvoider(
        autoScroll: autoScroll,
        expandable: expandable,
        child: child,
      );
    }
  }
}

/// Android-specific keyboard avoider widget
class _AndroidKeyboardAvoider extends StatelessWidget {
  final Widget child;
  final bool autoScroll;
  final bool expandable;

  const _AndroidKeyboardAvoider({
    required this.child,
    this.autoScroll = true,
    this.expandable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (autoScroll) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child:
            expandable
                ? SizedBox(
                  width: double.infinity,
                  // Set minimum height to viewport height minus keyboard
                  child: child,
                )
                : child,
      );
    } else {
      return child;
    }
  }
}

/// iOS-specific keyboard avoider widget
class _IOSKeyboardAvoider extends StatelessWidget {
  final Widget child;
  final bool autoScroll;
  final bool expandable;

  const _IOSKeyboardAvoider({
    required this.child,
    this.autoScroll = true,
    this.expandable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (autoScroll) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          // Add bottom padding to ensure content is above keyboard
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom
                    : 0,
          ),
          child:
              expandable
                  ? SizedBox(
                    width: double.infinity,
                    // Set minimum height to viewport height minus keyboard and padding
                    child: child,
                  )
                  : child,
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: child,
      );
    }
  }
}
