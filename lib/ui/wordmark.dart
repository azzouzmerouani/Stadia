import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'tokens.dart';

/// "STADIA" with the stadium glyph in FPL's green-to-cyan sweep. The mark
/// stays Latin (and left-to-right) in every language, like a logo.
class StadiaWordmark extends StatelessWidget {
  const StadiaWordmark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return Semantics(
      label: 'Stadia',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => StadiaGradients.go.createShader(
                rect,
                textDirection: direction,
              ),
              child: StadiaIcon(StadiaGlyph.stadium, size: size * 1.25),
            ),
            SizedBox(width: size * 0.4),
            Text(
              'STADIA',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: StadiaText.family,
                color: StadiaColors.white,
                fontSize: size,
                fontWeight: FontWeight.w900,
                letterSpacing: size * 0.18,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
