import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'tokens.dart';

class StadiaWordmark extends StatelessWidget {
  const StadiaWordmark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stadia',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StadiaIcon(StadiaGlyph.stadium, size: size * 1.25),
            SizedBox(width: size * 0.4),
            Text(
              'STADIA',
              style: TextStyle(
                color: StadiaColors.white,
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: size * 0.22,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
