import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';

enum GlassTone { dark, light }

/// Frosted surface: backdrop blur + translucent fill + 1px border.
/// Flat colour only – no gradients.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = StadiaRadii.lg,
    this.padding = EdgeInsets.zero,
    this.blur = 22,
    this.tone = GlassTone.dark,
    this.fill,
    this.borderColor,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final GlassTone tone;
  final Color? fill;
  final Color? borderColor;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final color = fill ??
        switch (tone) {
          GlassTone.dark => StadiaColors.glassDark,
          GlassTone.light => StadiaColors.glassLight,
        };
    final border = Border.all(
      color: borderColor ?? StadiaColors.glassBorder,
    );
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        border: border,
      ),
      child: Padding(padding: padding, child: child),
    );
    final filter = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: decorated,
    );
    return shape == BoxShape.circle
        ? ClipOval(child: filter)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: filter);
  }
}

/// Small rounded label, e.g. "Ligue 1" or "VIP".
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
        color: StadiaColors.glassLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StadiaColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
