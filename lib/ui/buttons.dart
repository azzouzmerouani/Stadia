import 'package:flutter/material.dart';

import 'glass.dart';
import 'icons.dart';
import 'spring_press.dart';
import 'stadia_loader.dart';
import 'tokens.dart';

/// FPL button styles, all pills:
/// * [primary] – white, purple text (the main action on purple),
/// * [accent] – green to cyan sweep, purple text (commit: Buy, Pay),
/// * [glass] – white wash, white text (over the 3D scene),
/// * [outline] – 1px white rim, white text (secondary).
enum StadiaButtonVariant { primary, accent, glass, outline }

class StadiaButton extends StatelessWidget {
  const StadiaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StadiaButtonVariant.primary,
    this.leading,
    this.trailing,
    this.loading = false,
    this.expand = true,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final StadiaButtonVariant variant;
  final StadiaGlyph? leading;
  final StadiaGlyph? trailing;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = switch (variant) {
      StadiaButtonVariant.primary ||
      StadiaButtonVariant.accent => StadiaColors.ink,
      _ => StadiaColors.white,
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          StadiaSpinner(color: fg, size: 18)
        else ...[
          if (leading != null) ...[
            StadiaIcon(leading!, color: fg, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StadiaText.label.copyWith(
                color: fg,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            StadiaIcon(trailing!, color: fg, size: 18),
          ],
        ],
      ],
    );

    final padded = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        // widthFactor 1 lets a non-expanding button hug its label.
        child: Center(widthFactor: expand ? null : 1, child: content),
      ),
    );

    final pill = BorderRadius.circular(StadiaRadii.pill);
    final Widget surface = switch (variant) {
      StadiaButtonVariant.primary => DecoratedBox(
        decoration: BoxDecoration(
          color: StadiaColors.white,
          borderRadius: pill,
        ),
        child: padded,
      ),
      StadiaButtonVariant.accent => DecoratedBox(
        decoration: BoxDecoration(
          gradient: StadiaGradients.go,
          borderRadius: pill,
        ),
        child: padded,
      ),
      StadiaButtonVariant.glass => GlassSurface(
        radius: StadiaRadii.pill,
        tone: GlassTone.light,
        borderColor: Colors.transparent,
        child: padded,
      ),
      StadiaButtonVariant.outline => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: pill,
          border: Border.all(color: StadiaColors.white),
        ),
        child: padded,
      ),
    };

    return AnimatedOpacity(
      duration: StadiaMotion.fast,
      opacity: enabled || loading ? 1 : 0.4,
      child: SpringPress(
        onTap: enabled ? onPressed : null,
        semanticLabel: label,
        child: surface,
      ),
    );
  }
}

/// Round glass button with a single glyph (back, close, recenter…).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.glyph,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
  });

  final StadiaGlyph glyph;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onPressed,
      pressedScale: 0.88,
      semanticLabel: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: GlassSurface(
          shape: BoxShape.circle,
          child: Center(child: StadiaIcon(glyph, size: size * 0.45)),
        ),
      ),
    );
  }
}
