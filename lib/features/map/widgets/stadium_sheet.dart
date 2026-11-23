import 'package:flutter/material.dart';

import '../../../data/models/stadium.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/format.dart';
import '../../../ui/glass.dart';
import '../../../ui/icons.dart';
import '../../../ui/spring_press.dart';
import '../../../ui/tokens.dart';

/// Bottom sheet listing the stadiums; pops with the chosen stadium's id.
class StadiumSheet extends StatelessWidget {
  const StadiumSheet({
    super.key,
    required this.stadiums,
    required this.current,
  });

  final List<Stadium> stadiums;
  final String current;

  static Future<String?> show(
    BuildContext context, {
    required List<Stadium> stadiums,
    required String current,
  }) => showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (_) => StadiumSheet(stadiums: stadiums, current: current),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset > 0 ? bottomInset : 8),
      child: GlassSurface(
        shadow: true,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: StadiaColors.overlay15,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(l10n.stadiumsTitle, style: StadiaText.headline),
            const SizedBox(height: 10),
            for (final s in stadiums)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SpringPress(
                  onTap: () => Navigator.of(context).pop(s.id),
                  pressedScale: 0.97,
                  semanticLabel: '${s.name}, ${s.city}',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: s.id == current
                          ? StadiaColors.purple90
                          : StadiaColors.purple100,
                      borderRadius: BorderRadius.circular(StadiaRadii.md),
                      border: Border.all(
                        color: s.id == current
                            ? StadiaColors.green
                            : StadiaColors.glassBorder,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const StadiaIcon(StadiaGlyph.stadium, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: StadiaText.label),
                                Text(
                                  '${s.city} · '
                                  '${l10n.seatCount(s.capacity, f.count(s.capacity))}',
                                  style: StadiaText.caption,
                                ),
                              ],
                            ),
                          ),
                          if (s.id == current)
                            GlassChip(
                              label: l10n.youAreHere,
                              dotColor: StadiaColors.green,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
