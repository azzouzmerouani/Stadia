import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../data/favourite_team.dart';
import '../../data/models/match.dart';
import '../../data/providers.dart';
import '../stadium3d/stadium_view.dart';

/// What the splash screen waits for, and where it goes next: the team
/// picker the first time, then straight to the favourite team's stadium.
/// Kept separate so tests can override it.
class SplashTasks {
  SplashTasks(this._ref);

  final Ref _ref;
  String _next = Routes.team;

  String get nextRoute => _next;

  Future<void> run() async {
    final results = await Future.wait<Object?>([
      _ref.read(stadiumsProvider.future),
      _ref.read(teamsProvider.future),
      _ref.read(upcomingMatchesProvider.future),
      _ref.read(sceneHostProvider.future), // the 3D viewer's server, if any
      _ref.read(favouriteTeamProvider.notifier).load(),
    ]);
    final teams = results[1]! as List<Team>;
    final matches = results[2]! as List<FootballMatch>;
    final favourite = results[4] as String?;
    final team = teams.where((t) => t.id == favourite).firstOrNull;
    if (team == null) {
      _next = Routes.team;
      return;
    }
    final plan = TeamPlan.of(
      team,
      matches,
      fallbackStadiumId: _ref.read(currentStadiumIdProvider),
    );
    _ref.read(currentStadiumIdProvider.notifier).select(plan.stadiumId);
    _next = Routes.intro;
  }
}

final splashTasksProvider = Provider<SplashTasks>(SplashTasks.new);
