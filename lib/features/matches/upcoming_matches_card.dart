import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/providers.dart';
import '../../ui/glass.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/tokens.dart';
import 'match_card.dart';

/// Glass bottom card with swipeable upcoming matches.
class UpcomingMatchesCard extends ConsumerStatefulWidget {
  const UpcomingMatchesCard({super.key});

  /// Used by the map to keep the stadium visible above the card.
  static const estimatedHeight = 330.0;

  @override
  ConsumerState<UpcomingMatchesCard> createState() =>
      _UpcomingMatchesCardState();
}

class _UpcomingMatchesCardState extends ConsumerState<UpcomingMatchesCard> {
  final _pages = PageController(viewportFraction: 0.9);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  double _distanceFromCentre(int i) {
    if (!_pages.hasClients || !_pages.position.haveDimensions) {
      return i == _index ? 0 : 1;
    }
    return ((_pages.page ?? 0) - i).abs().clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(upcomingMatchesProvider);
    final stadium = ref.watch(stadiumProvider).value;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset > 0 ? bottomInset : 8),
      child: GlassSurface(
        radius: StadiaRadii.xl,
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StadiaSpace.gutter + 4,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Upcoming matches', style: StadiaText.headline),
                  ),
                  if (matches.value case final list?)
                    Text(
                      '${_index + 1} / ${list.length}',
                      style: StadiaText.caption.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: MatchCard.height,
              child: switch (matches) {
                AsyncData(:final value) when stadium != null =>
                  PageView.builder(
                    controller: _pages,
                    itemCount: value.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => AnimatedBuilder(
                      animation: _pages,
                      builder: (context, child) {
                        final d = _distanceFromCentre(i);
                        return Opacity(
                          opacity: 1 - d * 0.45,
                          child: Transform.scale(
                            scale: 1 - d * 0.05,
                            child: child,
                          ),
                        );
                      },
                      child: MatchCard(
                        match: value[i],
                        stadium: stadium,
                        onChooseSeats: () =>
                            context.push(Routes.seats(value[i].id)),
                      ),
                    ),
                  ),
                AsyncError(:final error) => Center(
                    child: Text('$error', style: StadiaText.body),
                  ),
                _ => const Center(child: TrackLoader(width: 72)),
              },
            ),
            const SizedBox(height: 12),
            if (matches.value case final list?)
              _Dots(count: list.length, index: _index),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: StadiaMotion.medium,
            curve: StadiaMotion.emphasized,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? StadiaColors.white : StadiaColors.hairline,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
