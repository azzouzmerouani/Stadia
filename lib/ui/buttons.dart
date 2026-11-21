import 'package:flutter/material.dart';

import 'glass.dart';
import 'icons.dart';
import 'spring_press.dart';
import 'stadia_loader.dart';
import 'tokens.dart';

enum StadiaButtonVariant { primary, glass, outline }

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
    this.height = 54,
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
    final fg = variant == StadiaButtonVariant.primary
        ? StadiaColors.navy900
        : StadiaColors.white;

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
                fontSize: 15.5,
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
        child: Center(child: content),
      ),
    );

    final Widget surface = switch (variant) {
      StadiaButtonVariant.primary => DecoratedBox(
          decoration: BoxDecoration(
            color: StadiaColors.white,
            borderRadius: BorderRadius.circular(StadiaRadii.md + 2),
          ),
          child: padded,
        ),
      StadiaButtonVariant.glass => GlassSurface(
          radius: StadiaRadii.md + 2,
          tone: GlassTone.light,
          child: padded,
        ),
      StadiaButtonVariant.outline => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StadiaRadii.md + 2),
            border: Border.all(color: StadiaColors.glassBorder),
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
