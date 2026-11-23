import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/models/match.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/matches/match_card.dart';
import 'package:stadia/l10n/l10n.dart';
import 'package:stadia/ui/theme.dart';

void main() {
  testWidgets('match card shows teams, time, price and Choose seats', (
    tester,
  ) async {
    final repo = LocalStadiumRepository(latency: Duration.zero);
    Stadium? stadium;
    List<FootballMatch>? matches;
    await tester.runAsync(() async {
      stadium = await repo.fetchStadium();
      matches = await repo.fetchUpcomingMatches();
    });
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStadiaTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: MatchCard.height,
              child: MatchCard(
                match: matches!.firstWhere((m) => m.stadiumId == stadium!.id),
                stadium: stadium!,
                onChooseSeats: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('MC Oran'), findsOneWidget);
    expect(find.text('MC Alger'), findsOneWidget);
    expect(find.text('17:45'), findsOneWidget);
    expect(find.text('Sat 28 Nov'), findsOneWidget);
    expect(find.textContaining('600'), findsOneWidget);

    await tester.tap(find.text('Choose seats'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
