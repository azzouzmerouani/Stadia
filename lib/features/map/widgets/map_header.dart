import 'package:flutter/material.dart';

import '../../../data/models/match.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/buttons.dart';
import '../../../ui/glass.dart';
import '../../../ui/icons.dart';
import '../../../ui/spring_press.dart';
import '../../../ui/stage_frame.dart';
import '../../../ui/team_badge.dart';
import '../../../ui/tokens.dart';
import '../../../ui/wordmark.dart';

/// Phone layout: wordmark and city (tap: switch stadium), the favourite
/// club's crest (tap: change team) and re-centre, floating over the map.
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
                    Flexible(child: _Place(label: city)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: StadiaSpace.sm),
          TeamButton(team: team, onTap: onChangeTeam),
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

/// Wide layout: the bar across the top. Wordmark, the stadium (tap: switch
/// stadium) and the favourite club's crest (tap: change team).
class MapTopBar extends StatelessWidget {
  const MapTopBar({
    super.key,
    required this.stadium,
    required this.city,
    required this.onChangeStadium,
    required this.onChangeTeam,
    this.team,
  });

  final String stadium;
  final String city;
  final VoidCallback onChangeStadium;
  final VoidCallback onChangeTeam;
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WideTopBar(
      child: Row(
        children: [
          const StadiaWordmark(size: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            width: 1,
            height: 22,
            color: StadiaColors.hairline,
          ),
          // The rest of the bar; the pill hugs its text at the start.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SpringPress(
                onTap: onChangeStadium,
                pressedScale: 0.97,
                semanticLabel: '${l10n.changeStadium}: $stadium, $city',
                child: GlassSurface(
                  radius: StadiaRadii.pill,
                  tone: GlassTone.light,
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 9, 10, 9),
                  child: _Place(label: '$stadium · $city'),
                ),
              ),
            ),
          ),
          const SizedBox(width: StadiaSpace.lg),
          TeamButton(team: team, onTap: onChangeTeam),
        ],
      ),
    );
  }
}

/// Pin, place name and a chevron: "tap to switch stadium".
class _Place extends StatelessWidget {
  const _Place({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const StadiaIcon(StadiaGlyph.pin, size: 15),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
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
    );
  }
}

/// The favourite club's crest in a glass circle (a crown before one is
/// picked). Tap: change team.
class TeamButton extends StatelessWidget {
  const TeamButton({super.key, required this.team, required this.onTap});

  final Team? team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final team = this.team;
    return SpringPress(
      onTap: onTap,
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
    );
  }
}
