import 'package:flutter/material.dart';

import '../../../data/models/match.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/buttons.dart';
import '../../../ui/glass.dart';
import '../../../ui/icons.dart';
import '../../../ui/spring_press.dart';
import '../../../ui/team_badge.dart';
import '../../../ui/tokens.dart';
import '../../../ui/wordmark.dart';

/// Wordmark and city (tap: switch stadium), the favourite club's crest
/// (tap: change team) and re-centre.
class MapHeader extends StatelessWidget {
  const MapHeader({
    super.key,
    required this.city,
    required this.onRecenter,
    required this.onChangeStadium,
    required this.onChangeTeam,
    this.team,
  });

  final String city;
  final VoidCallback onRecenter;
  final VoidCallback onChangeStadium;
  final VoidCallback onChangeTeam;

  /// The favourite club, if one was picked.
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final team = this.team;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StadiaSpace.gutter,
        StadiaSpace.sm,
        StadiaSpace.gutter,
        0,
      ),
      child: Row(
        children: [
          Flexible(
            child: SpringPress(
              onTap: onChangeStadium,
              pressedScale: 0.96,
              semanticLabel: '${l10n.changeStadium}: $city',
              child: GlassSurface(
                radius: StadiaRadii.pill,
                shadow: true,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
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
                    Flexible(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StadiaText.label.copyWith(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: StadiaColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: StadiaSpace.sm),
          SpringPress(
            onTap: onChangeTeam,
            pressedScale: 0.88,
            semanticLabel: team == null
                ? l10n.changeTeam
                : '${l10n.yourTeam}: ${team.name}. ${l10n.changeTeam}',
            child: SizedBox.square(
              dimension: 44,
              child: GlassSurface(
                shape: BoxShape.circle,
                shadow: true,
                child: Center(
                  child: team == null
                      ? const StadiaIcon(StadiaGlyph.crown)
                      : TeamBadge(team: team, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(width: StadiaSpace.sm),
          GlassIconButton(
            glyph: StadiaGlyph.locate,
            onPressed: onRecenter,
            semanticLabel: l10n.backToStadium,
          ),
        ],
      ),
    );
  }
}
