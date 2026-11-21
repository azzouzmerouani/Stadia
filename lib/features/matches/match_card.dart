import 'package:flutter/material.dart';

import '../../data/models/match.dart';
import '../../data/models/stadium.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/glass.dart';
import '../../ui/icons.dart';
import '../../ui/team_badge.dart';
import '../../ui/tokens.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.stadium,
    required this.onChooseSeats,
  });

  static const height = 236.0;

  final FootballMatch match;
  final Stadium stadium;
  final VoidCallback onChooseSeats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StadiaColors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(StadiaRadii.lg),
          border: Border.all(color: StadiaColors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GlassChip(
                        label: '${match.competition} · ${match.round}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('from ', style: StadiaText.caption),
                  Text(
                    formatPrice(match.fromPrice(stadium)),
                    style: StadiaText.numberSmall,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(child: _TeamColumn(team: match.home, label: 'Home')),
                  Column(
                    children: [
                      Text(formatTime(match.kickoff), style: StadiaText.number),
                      const SizedBox(height: 4),
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
                            formatMatchDate(match.kickoff),
                            style: StadiaText.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(child: _TeamColumn(team: match.away, label: 'Away')),
                ],
              ),
              const Spacer(),
              StadiaButton(
                label: 'Choose seats',
                trailing: StadiaGlyph.arrowRight,
                height: 50,
                onPressed: onChooseSeats,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.team, required this.label});

  final Team team;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamBadge(team: team, size: 44),
        const SizedBox(height: 8),
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
