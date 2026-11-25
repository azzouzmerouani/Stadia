import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lists and carousels scroll by dragging with a mouse or trackpad too,
/// as they do with a finger (the web build is used with a mouse).
class StadiaScrollBehavior extends MaterialScrollBehavior {
  const StadiaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
