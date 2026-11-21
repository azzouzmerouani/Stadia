import 'package:flutter/material.dart';

import '../../../ui/buttons.dart';
import '../../../ui/glass.dart';
import '../../../ui/icons.dart';
import '../../../ui/tokens.dart';
import '../../../ui/wordmark.dart';

class MapHeader extends StatelessWidget {
  const MapHeader({super.key, required this.city, required this.onRecenter});

  final String city;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StadiaSpace.gutter,
        StadiaSpace.sm,
        StadiaSpace.gutter,
        0,
      ),
      child: Row(
        children: [
          GlassSurface(
            radius: 999,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StadiaWordmark(size: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 1,
                  height: 14,
                  color: StadiaColors.hairline,
                ),
                const StadiaIcon(StadiaGlyph.pin, size: 15),
                const SizedBox(width: 5),
                Text(city, style: StadiaText.label.copyWith(fontSize: 13)),
              ],
            ),
          ),
          const Spacer(),
          GlassIconButton(
            glyph: StadiaGlyph.locate,
            onPressed: onRecenter,
            semanticLabel: 'Back to the stadium',
          ),
        ],
      ),
    );
  }
}
