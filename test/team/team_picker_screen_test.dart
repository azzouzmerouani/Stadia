import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stadia/app/routes.dart';
import 'package:stadia/data/favourite_team.dart';
import 'package:stadia/data/models/match.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/team/team_picker_screen.dart';
import 'package:stadia/l10n/l10n.dart';
import 'package:stadia/ui/theme.dart';

void main() {
  late MemoryFavouriteTeamStore store;

  Future<void> pumpPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    store = MemoryFavouriteTeamStore();
    // Loaded for real outside the fake clock: the asset bundle caches its
    // futures, and one made inside a test's fake zone never completes in
    // the next test.
    final repo = LocalStadiumRepository(latency: Duration.zero);
    late List<Stadium> stadiums;
    late List<Team> teams;
    late List<FootballMatch> matches;
    await tester.runAsync(() async {
      stadiums = await repo.fetchStadiums();
      teams = await repo.fetchTeams();
      matches = await repo.fetchUpcomingMatches();
    });
    final router = GoRouter(
      initialLocation: Routes.team,
      routes: [
        GoRoute(path: Routes.team, builder: (_, _) => const TeamPickerScreen()),
        GoRoute(path: Routes.intro, builder: (_, _) => const Text('INTRO')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stadiumsProvider.overrideWithValue(AsyncData(stadiums)),
          teamsProvider.overrideWithValue(AsyncData(teams)),
          upcomingMatchesProvider.overrideWithValue(AsyncData(matches)),
          favouriteTeamStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp.router(
          theme: buildStadiaTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every club; nothing to go to until one is picked', (
    tester,
  ) async {
    await pumpPicker(tester);
    expect(find.text('Pick your team'), findsOneWidget);
    for (final club in [
      'MC Oran',
      'MC Alger',
      'JS Kabylie',
      'ES Sétif',
      'USM Alger',
      'CR Belouizdad',
      'CS Constantine',
    ]) {
      expect(find.text(club), findsOneWidget, reason: club);
    }
    expect(find.text('Pick a team to continue'), findsOneWidget);

    await tester.tap(find.text('Go to the stadium'));
    await tester.pumpAndSettle();
    expect(find.text('INTRO'), findsNothing);
    expect(store.teamId, isNull);
  });

  testWidgets('picking ES Sétif saves it and goes to 8 Mai 1945', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.text('ES Sétif'));
    await tester.pumpAndSettle();
    expect(find.text('8 May 1945 Stadium'), findsOneWidget);
    expect(
      find.text('Next match: ES Sétif vs CR Belouizdad · Sat 28 Nov'),
      findsOneWidget,
    );

    await tester.tap(find.text('Go to the stadium'));
    await tester.pumpAndSettle();
    expect(find.text('INTRO'), findsOneWidget);
    expect(store.teamId, 'ESS');
    final container = ProviderScope.containerOf(
      tester.element(find.text('INTRO')),
    );
    expect(container.read(currentStadiumIdProvider), '8-mai-1945');
    expect(container.read(favouriteTeamProvider), 'ESS');
  });

  testWidgets('a visiting club goes where it plays next', (tester) async {
    await pumpPicker(tester);
    await tester.tap(find.text('JS Kabylie'));
    await tester.pumpAndSettle();
    expect(find.text('Stade Miloud Hadefi'), findsOneWidget);
    expect(
      find.text('Next match: MC Oran vs JS Kabylie · Sat 5 Dec'),
      findsOneWidget,
    );
  });
}
