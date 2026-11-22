import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../ui/format.dart';
import '../../../ui/glass.dart';
import '../../../ui/icons.dart';
import '../../../ui/tokens.dart';
import '../booking_machine.dart';
import '../booking_words.dart';

Color availabilityColour(double freeRatio) {
  if (freeRatio <= 0) return StadiaColors.sold;
  if (freeRatio < 0.2) return StadiaColors.limited;
  return StadiaColors.free;
}

/// Floating card: name, free seats and price of the tapped element.
class SelectionCard extends StatelessWidget {
  const SelectionCard({super.key, required this.summary, this.hint});

  final SelectionSummary? summary;

  /// Shown when nothing is selected yet ("Tap a stand").
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final id = s == null
        ? 'hint'
        : '${s.level.name}-${s.seat?.id ?? s.block?.id ?? s.stand.id}';
    return GlassSurface(
      shadow: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: AnimatedSize(
        duration: StadiaMotion.medium,
        curve: StadiaMotion.emphasized,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: StadiaMotion.medium,
          switchInCurve: StadiaMotion.emphasized,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: s == null
              ? _Hint(key: ValueKey(id), text: hint ?? '')
              : _Details(key: ValueKey(id), summary: s),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const StadiaIcon(StadiaGlyph.orbit, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: StadiaText.label)),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({super.key, required this.summary});

  final SelectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);
    final s = summary;
    final colour = availabilityColour(s.freeRatio);
    final level = switch (s.level) {
      SelectionLevel.stand => l10n.levelStand,
      SelectionLevel.block => l10n.levelBlock,
      SelectionLevel.seat => l10n.levelYourSeat,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(level, style: StadiaText.overline),
              Text(
                l10n.summaryTitle(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StadiaText.headline,
              ),
              Text(
                l10n.summarySubtitle(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StadiaText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.level != SelectionLevel.seat)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colour,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.free == 0
                        ? l10n.soldOut
                        : l10n.freeCount(f.count(s.free)),
                    style: StadiaText.caption.copyWith(
                      color: StadiaColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  if (s.priceIsFrom)
                    TextSpan(
                      text: '${l10n.priceFrom} ',
                      style: StadiaText.caption,
                    ),
                  TextSpan(text: f.price(s.price), style: StadiaText.number),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
