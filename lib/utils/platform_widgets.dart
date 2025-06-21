import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// A collection of platform-adaptive widgets that automatically
/// adjust their appearance based on the platform (iOS or Android)
class PlatformWidgets {
  /// Returns true if the device is running iOS
  static bool isIOS() => Platform.isIOS;

  /// Returns true if the device is running Android
  static bool isAndroid() => Platform.isAndroid;

  /// Returns a platform-specific button
  static Widget button({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    bool isPrimary = true,
    IconData? icon,
  }) {
    if (isIOS()) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isPrimary ? Theme.of(context).primaryColor : null,
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color:
                    isPrimary ? Colors.white : Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color:
                    isPrimary ? Colors.white : Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      );
    } else {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? Theme.of(context).primaryColor : Colors.white,
          foregroundColor:
              isPrimary ? Colors.white : Theme.of(context).primaryColor,
          elevation: isPrimary ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side:
                isPrimary
                    ? BorderSide.none
                    : BorderSide(color: Theme.of(context).primaryColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
            Text(text),
          ],
        ),
      );
    }
  }

  /// Returns a platform-specific dialog
  static Future<T?> showDialog<T>({
    required BuildContext context,
    required String title,
    required String message,
    String? cancelText,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) async {
    if (isIOS()) {
      return showCupertinoDialog<T>(
        context: context,
        builder:
            (context) => CupertinoAlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                if (cancelText != null)
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(cancelText),
                  ),
                CupertinoDialogAction(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onConfirm != null) onConfirm();
                  },
                  child: Text(confirmText),
                ),
              ],
            ),
      );
    } else {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder:
            (context, animation, secondaryAnimation) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                if (cancelText != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      cancelText,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onConfirm != null) onConfirm();
                  },
                  child: Text(
                    confirmText,
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
              ],
            ),
      );
    }
  }

  /// Returns a platform-specific loading indicator
  static Widget loadingIndicator() {
    return isIOS()
        ? const CupertinoActivityIndicator()
        : const CircularProgressIndicator();
  }

  /// Returns a platform-specific app bar
  static PreferredSizeWidget appBar({
    required BuildContext context,
    required String title,
    List<Widget>? actions,
    bool automaticallyImplyLeading = true,
    Widget? leading,
  }) {
    if (isIOS()) {
      return CupertinoNavigationBar(
        middle: Text(title),
        trailing:
            actions != null && actions.isNotEmpty
                ? Row(mainAxisSize: MainAxisSize.min, children: actions)
                : null,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
      );
    } else {
      return AppBar(
        title: Text(title),
        actions: actions,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
      );
    }
  }

  /// Returns a platform-specific switch
  static Widget toggle({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    if (isIOS()) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        thumbColor: Theme.of(context).primaryColor,
      );
    } else {
      return Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Theme.of(context).primaryColor,
      );
    }
  }

  /// Returns a platform-specific text field
  static Widget textField({
    required BuildContext context,
    required TextEditingController controller,
    String? hintText,
    String? labelText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    FocusNode? focusNode,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onChanged,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    if (isIOS()) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (labelText != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                labelText,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ),
          ],
          CupertinoTextField(
            controller: controller,
            placeholder: hintText,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            focusNode: focusNode,
            onEditingComplete: onEditingComplete,
            onChanged: onChanged,
            prefix:
                prefixIcon != null
                    ? Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: prefixIcon,
                    )
                    : null,
            suffix:
                suffixIcon != null
                    ? Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: suffixIcon,
                    )
                    : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      );
    } else {
      return TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        focusNode: focusNode,
        onEditingComplete: onEditingComplete,
        onChanged: onChanged,
      );
    }
  }

  /// Returns a platform-specific bottom sheet
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    if (isIOS()) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => Builder(builder: builder),
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        builder: builder,
        isDismissible: isDismissible,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      );
    }
  }
}
