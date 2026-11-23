import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/favourite_team.dart';
import '../../data/models/match.dart';
import '../../data/models/stadium.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/glass.dart';
import '../../ui/icons.dart';
import '../../ui/spring_press.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/team_badge.dart';
import '../../ui/tokens.dart';
import '../../ui/wordmark.dart';
import '../seat_picker/booking_words.dart';

/// "Pick your team", before the stadium: a grid of club crests. The choice
/// is saved, sets the stadium (the club's home ground, or where it plays
/// next) and puts the club's matches first on the map.
class TeamPickerScreen extends ConsumerStatefulWidget {
  const TeamPickerScreen({super.key});

  @override
  ConsumerState<TeamPickerScreen> createState() => _TeamPickerScreenState();
}

class _TeamPickerScreenState extends ConsumerState<TeamPickerScreen> {
  String? _selected;
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(favouriteTeamProvider);
  }

  TeamPlan? _plan(List<Team> teams, List<FootballMatch> matches) {
    final team = teams.where((t) => t.id == _selected).firstOrNull;
    if (team == null) return null;
    return TeamPlan.of(
      team,
      matches,
      fallbackStadiumId: ref.read(currentStadiumIdProvider),
    );
  }

  Future<void> _go(TeamPlan plan) async {
    if (_going) return;
    setState(() => _going = true);
    await ref.read(favouriteTeamProvider.notifier).choose(plan.team.id);
    ref.read(currentStadiumIdProvider.notifier).select(plan.stadiumId);
    if (mounted) context.go(Routes.intro);
  }

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamsProvider);
    final matches = ref.watch(upcomingMatchesProvider).value ?? const [];
    final stadiums = ref.watch(stadiumsProvider).value ?? const <Stadium>[];
    final plan = teams.value == null ? null : _plan(teams.value!, matches);
    final stadium = stadiums.where((s) => s.id == plan?.stadiumId).firstOrNull;
    final glow = plan == null ? null : _glowColour(plan.team);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: StadiaColors.page,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The chosen club's colour washes in from the top.
          AnimatedContainer(
            duration: StadiaMotion.slow,
            curve: StadiaMotion.emphasized,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1.15),
                radius: 1.25,
                colors: [
                  (glow ?? StadiaColors.lilac).withValues(
                    alpha: glow == null ? 0.16 : 0.3,
                  ),
                  StadiaColors.page.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: switch (teams) {
              AsyncData(:final value) => CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      StadiaSpace.gutter + 4,
                      StadiaSpace.lg,
                      StadiaSpace.gutter + 4,
                      StadiaSpace.xl,
                    ),
                    sliver: SliverToBoxAdapter(child: _Header(l10n: l10n)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StadiaSpace.gutter,
                    ),
                    sliver: SliverGrid.builder(
                      itemCount: value.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.08,
                          ),
                      itemBuilder: (context, i) =>
                          _TeamTile(
                                team: value[i],
                                selected: value[i].id == _selected,
                                onTap: () =>
                                    setState(() => _selected = value[i].id),
                              )
                              .animate()
                              .fadeIn(delay: (80 + 45 * i).ms, duration: 380.ms)
                              .scale(
                                begin: const Offset(0.94, 0.94),
                                delay: (80 + 45 * i).ms,
                                curve: StadiaMotion.emphasized,
                              ),
                    ),
                  ),
                  // Room for the panel at the bottom.
                  const SliverToBoxAdapter(child: SizedBox(height: 230)),
                ],
              ),
              AsyncError(:final error) => Center(
                child: Text('$error', style: StadiaText.body),
              ),
              _ => const Center(child: TrackLoader(width: 96)),
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GoPanel(
              plan: plan,
              stadium: stadium,
              going: _going,
              onGo: plan == null ? null : () => _go(plan),
            ),
          ),
        ],
      ),
    );
  }

  /// A colour that shows on purple: the club's primary, or its secondary
  /// when the primary is near-black (ES Sétif).
  static Color _glowColour(Team team) {
    final primary = Color(team.primaryColor);
    return primary.computeLuminance() < 0.03
        ? Color(team.secondaryColor)
        : primary;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StadiaWordmark(),
            const SizedBox(height: 26),
            Text(
              l10n.pickTeamOverline,
              style: StadiaText.overline.copyWith(color: StadiaColors.green),
            ),
            const SizedBox(height: 4),
            Text(l10n.pickTeamTitle, style: StadiaText.display),
            const SizedBox(height: 6),
            Text(l10n.pickTeamBody, style: StadiaText.body),
          ],
        )
        .animate()
        .fadeIn(duration: StadiaMotion.slow)
        .slideY(begin: 0.08, end: 0, curve: StadiaMotion.emphasized);
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.team,
    required this.selected,
    required this.onTap,
  });

  final Team team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${team.name}, ${team.city}',
      excludeSemantics: true,
      child: SpringPress(
        onTap: onTap,
        pressedScale: 0.95,
        child: AnimatedContainer(
          duration: StadiaMotion.medium,
          curve: StadiaMotion.emphasized,
          decoration: BoxDecoration(
            color: selected ? StadiaColors.purple90 : StadiaColors.purple100,
            borderRadius: BorderRadius.circular(StadiaRadii.lg),
            border: Border.all(
              color: selected ? StadiaColors.green : StadiaColors.glassBorder,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: StadiaColors.green.withValues(alpha: 0.22),
                      blurRadius: 22,
                      spreadRadius: -4,
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.08 : 1,
                      duration: StadiaMotion.medium,
                      curve: Curves.easeOutBack,
                      child: TeamBadge(team: team, size: 58),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: StadiaText.label,
                    ),
                    Text(
                      team.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StadiaText.caption,
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 10,
                end: 10,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: StadiaMotion.medium,
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: StadiaColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: StadiaIcon(
                        StadiaGlyph.check,
                        size: 14,
                        color: StadiaColors.ink,
                        strokeWidth: 2.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom glass panel: where the choice leads (stadium, next match) and
/// the button that goes there.
class _GoPanel extends StatelessWidget {
  const _GoPanel({
    required this.plan,
    required this.stadium,
    required this.going,
    required this.onGo,
  });

  final TeamPlan? plan;
  final Stadium? stadium;
  final bool going;
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final plan = this.plan;
    final next = plan?.nextMatch;
    final stadium = this.stadium;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset > 0 ? bottomInset : 8),
      child: GlassSurface(
        shadow: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: StadiaMotion.medium,
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [...previous, ?current],
              ),
              child: plan == null || stadium == null
                  ? Padding(
                      key: const ValueKey('empty'),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(l10n.pickTeamFirst, style: StadiaText.body),
                    )
                  : Row(
                      key: ValueKey(plan.team.id),
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: StadiaColors.overlay10,
                            borderRadius: BorderRadius.circular(StadiaRadii.md),
                          ),
                          child: const Center(
                            child: StadiaIcon(StadiaGlyph.stadium, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stadium.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StadiaText.headline,
                              ),
                              Text(
                                next == null
                                    ? '${stadium.city} · ${l10n.noMatchYet}'
                                    : '${l10n.nextMatch}: ${l10n.match(next)} · '
                                          '${f.matchDate(next.kickoff)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: StadiaText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            StadiaButton(
              label: l10n.goToStadium,
              variant: StadiaButtonVariant.accent,
              trailing: StadiaGlyph.arrowRight,
              loading: going,
              onPressed: onGo,
            ),
          ],
        ),
      ),
    );
  }
}
