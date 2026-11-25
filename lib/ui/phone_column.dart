import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Stadia is phone-first. In a wide browser window it runs in a centred,
/// phone-width column (its own MediaQuery size, so sheets, dialogs and the
/// 3D view lay out as on a phone) over the page colour, instead of
/// stretching across the screen. Phones and tablets get [child] as is.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({super.key, required this.child, this.enabled = kIsWeb});

  final Widget child;

  /// Only the web gets the column by default: the native apps fill the
  /// device.
  final bool enabled;

  static const width = 440.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!enabled || media.size.width < width + 120) return child;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.4,
          colors: [StadiaColors.purple100, StadiaColors.page],
        ),
      ),
      child: Center(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: StadiaColors.page,
            border: Border.symmetric(
              vertical: BorderSide(color: StadiaColors.glassBorder),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 80,
                spreadRadius: 10,
              ),
            ],
          ),
          child: SizedBox(
            width: width,
            child: ClipRect(
              child: MediaQuery(
                data: media.copyWith(size: Size(width, media.size.height)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
