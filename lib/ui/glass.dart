import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';

enum GlassTone { dark, light }

/// Floating panel over the map / 3D scene: FPL's purple110 at 90 % with a
/// light backdrop blur and a faint white rim.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = StadiaRadii.lg,
    this.padding = EdgeInsets.zero,
    this.blur = 16,
    this.tone = GlassTone.dark,
    this.fill,
    this.borderColor,
    this.shape = BoxShape.rectangle,
    this.shadow = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final GlassTone tone;
  final Color? fill;
  final Color? borderColor;
  final BoxShape shape;

  /// FPL's card shadow, for panels that float high over busy content.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final color =
        fill ??
        switch (tone) {
          GlassTone.dark => StadiaColors.glassDark,
          GlassTone.light => StadiaColors.glassLight,
        };
    final circle = shape == BoxShape.circle;
    final borderRadius = circle ? null : BorderRadius.circular(radius);
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? StadiaColors.glassBorder),
      ),
      child: Padding(padding: padding, child: child),
    );
    final filter = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: decorated,
    );
    final clipped = circle
        ? ClipOval(child: filter)
        : ClipRRect(borderRadius: borderRadius!, child: filter);
    if (!shadow) return clipped;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: StadiaShadows.card,
      ),
      child: clipped,
    );
  }
}

/// Small pill label, e.g. "Ligue 1" or "VIP".
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.leading,
    this.dotColor,
  });

  final String label;
  final Widget? leading;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StadiaColors.overlay10,
        borderRadius: BorderRadius.circular(StadiaRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StadiaText.caption.copyWith(
                  color: StadiaColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
