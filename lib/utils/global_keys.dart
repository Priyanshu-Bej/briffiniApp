import 'package:flutter/material.dart';

/// Global navigator key to avoid circular imports and early service instantiation
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();
