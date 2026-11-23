import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/match.dart';

/// Where the favourite club is kept between launches. On the device for
/// now; with accounts it belongs on the user's profile.
abstract interface class FavouriteTeamStore {
  Future<String?> read();

  Future<void> write(String teamId);
}

class PrefsFavouriteTeamStore implements FavouriteTeamStore {
  static const key = 'favouriteTeam';

  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read() => _prefs.getString(key);

  @override
  Future<void> write(String teamId) => _prefs.setString(key, teamId);
}

/// For tests, and a fallback if the platform store fails.
class MemoryFavouriteTeamStore implements FavouriteTeamStore {
  MemoryFavouriteTeamStore([this.teamId]);

  String? teamId;

  @override
  Future<String?> read() async => teamId;

  @override
  Future<void> write(String teamId) async => this.teamId = teamId;
}

final favouriteTeamStoreProvider = Provider<FavouriteTeamStore>(
  (ref) => PrefsFavouriteTeamStore(),
);

/// Id of the user's favourite club, or null until they pick one.
class FavouriteTeam extends Notifier<String?> {
  @override
  String? build() => null;

  /// Reads the saved choice (the splash screen calls this once).
  Future<String?> load() async {
    try {
      return state = await ref.read(favouriteTeamStoreProvider).read();
    } on Object catch (e) {
      debugPrint('favourite team: could not read ($e)');
      return state;
    }
  }

  Future<void> choose(String teamId) async {
    state = teamId;
    try {
      await ref.read(favouriteTeamStoreProvider).write(teamId);
    } on Object catch (e) {
      // Still chosen for this session; it just won't survive a restart.
      debugPrint('favourite team: could not save ($e)');
    }
  }
}

final favouriteTeamProvider = NotifierProvider<FavouriteTeam, String?>(
  FavouriteTeam.new,
);

/// Where a club takes its fan: its home ground when the app sells tickets
/// there, otherwise the ground of its next match.
class TeamPlan {
  const TeamPlan({required this.team, required this.stadiumId, this.nextMatch});

  final Team team;
  final String stadiumId;

  /// The club's next match at [stadiumId], if there is one.
  final FootballMatch? nextMatch;

  /// [matches] soonest first.
  static TeamPlan of(
    Team team,
    List<FootballMatch> matches, {
    required String fallbackStadiumId,
  }) {
    final theirs = matches.where((m) => m.involves(team.id));
    final stadiumId =
        team.homeStadiumId ??
        theirs.firstOrNull?.stadiumId ??
        fallbackStadiumId;
    return TeamPlan(
      team: team,
      stadiumId: stadiumId,
      nextMatch: theirs.where((m) => m.stadiumId == stadiumId).firstOrNull,
    );
  }
}
