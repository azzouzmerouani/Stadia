import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stadia/data/models/match.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/matches/match_card.dart';
import 'package:stadia/l10n/l10n.dart';
import 'package:stadia/ui/format.dart';
import 'package:stadia/ui/theme.dart';

/// The app ships in Arabic (Algeria): data, numbers, dates and layout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ar_DZ'));

  test('repository resolves Arabic names, falls back to English', () async {
    final repo = LocalStadiumRepository(
      latency: Duration.zero,
      languageCode: 'ar',
    );
    final stadium = await repo.fetchStadium();
    expect(stadium.name, 'ملعب ميلود هدفي');
    expect(stadium.city, 'وهران');
    expect(stadium.standById('N')!.name, 'المدرج الشمالي');

    final match = (await repo.fetchUpcomingMatches()).first;
    expect(match.home.name, 'مولودية وهران');
    expect(match.home.shortName, 'MCO'); // codes stay Latin, like FPL's

    expect(
      LocalStadiumRepository.text({'en': 'Gate A'}, 'ar'),
      'Gate A',
      reason: 'a missing translation falls back to English',
    );
  });

  test('every club has a crest asset on disk', () async {
    final repo = LocalStadiumRepository(latency: Duration.zero);
    final teams = {
      for (final m in await repo.fetchUpcomingMatches()) ...[m.home, m.away],
    };
    expect(teams, isNotEmpty);
    for (final t in teams) {
      expect(t.logo, isNotNull, reason: t.id);
      expect(File(t.logo!).existsSync(), isTrue, reason: t.logo);
    }
  });

  test('Algerian Arabic formatting: Latin digits, Maghreb months, DA', () {
    const f = StadiaFormat.ar;
    final july = DateTime(2026, 7, 4, 17, 45);
    expect(f.matchDateLong(july), 'السبت 4 جويلية');
    expect(f.time(july), '17:45');
    // Narrow no-break space groups thousands without reading as a decimal.
    expect(f.price(1500), '1 500 د.ج');
    expect(f.count(40320), '40 320');
    expect(StadiaFormat.en.count(40320), '40,320');
  });

  testWidgets('match card lays out right-to-left in Arabic', (tester) async {
    final repo = LocalStadiumRepository(
      latency: Duration.zero,
      languageCode: 'ar',
    );
    Stadium? stadium;
    List<FootballMatch>? matches;
    await tester.runAsync(() async {
      stadium = await repo.fetchStadium();
      matches = await repo.fetchUpcomingMatches();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStadiaTheme(),
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: MatchCard.height,
              child: MatchCard(
                match: matches!.first,
                stadium: stadium!,
                onChooseSeats: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cta = find.text('اختر مقعدك');
    expect(cta, findsOneWidget);
    expect(Directionality.of(tester.element(cta)), TextDirection.rtl);

    // Home side reads first, so in RTL it sits on the right.
    final home = tester.getCenter(find.text('مولودية وهران'));
    final away = tester.getCenter(find.text('مولودية الجزائر'));
    expect(home.dx, greaterThan(away.dx));
    expect(find.textContaining('د.ج'), findsOneWidget);
  });
}
