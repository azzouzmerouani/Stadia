import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/models/match.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/map/map_screen.dart';
import 'package:stadia/ui/theme.dart';

void main() {
  // Regression: the map's fly controller used to be created lazily, so a
  // user who never re-centred built it inside dispose(). That threw while
  // go_router unmounted the map together with the seat picker after a
  // purchase, aborted the unmount and kept the old booking alive.
  testWidgets('the map can be left without ever re-centring', (tester) async {
    final repo = LocalStadiumRepository(latency: Duration.zero);
    late Stadium stadium;
    late List<FootballMatch> matches;
    await tester.runAsync(() async {
      stadium = await repo.fetchStadium();
      matches = await repo.fetchUpcomingMatches();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stadiumProvider.overrideWithValue(AsyncData(stadium)),
          upcomingMatchesProvider.overrideWithValue(AsyncData(matches)),
        ],
        child: MaterialApp(theme: buildStadiaTheme(), home: const MapScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(stadium.name), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    // flutter_animate's entrance delays are plain timers; let them run out.
    await tester.pump(const Duration(seconds: 5));
  });
}
