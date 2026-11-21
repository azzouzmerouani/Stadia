import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../ui/glass.dart';
import '../../../ui/icons.dart';
import '../../../ui/spring_press.dart';
import '../../../ui/tokens.dart';

/// Glass label + pin with a pulsing ring at the stadium's exact location.
/// Lay it out with `Alignment.topCenter` so the dot sits on the point.
class StadiumMarker extends StatelessWidget {
  const StadiumMarker({
    super.key,
    required this.name,
    required this.caption,
    this.onTap,
  });

  static const size = Size(230, 112);

  final String name;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      semanticLabel: name,
      child: SizedBox.fromSize(
        size: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GlassSurface(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: StadiaColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: StadiaIcon(
                        StadiaGlyph.stadium,
                        size: 18,
                        color: StadiaColors.navy900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StadiaText.label,
                        ),
                        Text(
                          caption,
                          maxLines: 1,
                          style: StadiaText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1.5, height: 14, color: StadiaColors.white),
            SizedBox.square(
              dimension: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: StadiaColors.white, width: 1.5),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .scale(
                        begin: const Offset(0.3, 0.3),
                        end: const Offset(1.2, 1.2),
                        duration: 1800.ms,
                        curve: Curves.easeOut,
                      )
                      .fadeOut(duration: 1800.ms, curve: Curves.easeIn),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: StadiaColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: StadiaColors.navy900, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
