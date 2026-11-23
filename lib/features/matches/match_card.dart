import 'package:flutter/material.dart';

import '../../data/models/match.dart';
import '../../data/models/stadium.dart';
import '../../l10n/l10n.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/glass.dart';
import '../../ui/icons.dart';
import '../../ui/team_badge.dart';
import '../../ui/tokens.dart';

/// FPL-style fixture card: competition chip and price, the two crests
/// either side of the kick-off pill, then "Choose seats".
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.stadium,
    required this.onChooseSeats,
    this.featured = false,
  });

  static const height = 236.0;

  final FootballMatch match;
  final Stadium stadium;
  final VoidCallback onChooseSeats;

  /// The user's favourite club plays: a green rim.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StadiaColors.purple100,
          borderRadius: BorderRadius.circular(StadiaRadii.lg),
          border: Border.all(
            color: featured
                ? StadiaColors.green.withValues(alpha: 0.75)
                : StadiaColors.glassBorder,
            width: featured ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: GlassChip(
                        label: '${match.competition} · ${match.round}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${l10n.priceFrom} ', style: StadiaText.caption),
                  Text(
                    f.price(match.fromPrice(stadium)),
                    style: StadiaText.numberSmall,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(child: _TeamColumn(team: match.home)),
                  Column(
                    children: [
                      _KickoffPill(time: f.time(match.kickoff)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StadiaIcon(
                            StadiaGlyph.calendar,
                            size: 13,
                            color: StadiaColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            f.matchDate(match.kickoff),
                            style: StadiaText.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(child: _TeamColumn(team: match.away)),
                ],
              ),
              const Spacer(),
              StadiaButton(
                label: l10n.chooseSeats,
                trailing: StadiaGlyph.arrowRight,
                height: 48,
                onPressed: onChooseSeats,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White pill with the kick-off time, like FPL's fixture times.
class _KickoffPill extends StatelessWidget {
  const _KickoffPill({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StadiaColors.white,
        borderRadius: BorderRadius.circular(StadiaRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Text(
          time,
          style: StadiaText.number.copyWith(
            color: StadiaColors.ink,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamBadge(team: team, size: 50),
        const SizedBox(height: 6),
        Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StadiaText.label.copyWith(fontSize: 13.5),
        ),
      ],
    );
  }
}
