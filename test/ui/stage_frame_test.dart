import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/models/match.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/map/map_screen.dart';
import 'package:stadia/features/map/widgets/map_header.dart';
import 'package:stadia/features/matches/match_card.dart';
import 'package:stadia/features/matches/upcoming_matches_card.dart';
import 'package:stadia/l10n/l10n.dart';
import 'package:stadia/ui/stage_frame.dart';
import 'package:stadia/ui/theme.dart';

void setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Arabic, as shipped: the side panel belongs on the right.
Widget app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: buildStadiaTheme(),
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  ),
);

/// Unmounts, then lets flutter_animate's entrance timers run out.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

class _Stage extends StatefulWidget {
  const _Stage();

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  testWidgets('the stage keeps its state when the window crosses the '
      'breakpoint', (tester) async {
    setWindow(tester, const Size(1400, 900));
    final wide = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: wide,
          builder: (context, isWide, _) => StageFrame(
            wide: isWide,
            stage: const _Stage(),
            overlay: const [Text('floating card')],
            topBar: const Text('top bar'),
            sidebar: const Text('side panel'),
          ),
        ),
      ),
    );
    final state = tester.state(find.byType(_Stage));
    // Left to right here: the side panel (440 at this width) on the left.
    expect(
      tester.getRect(find.byType(_Stage)),
      const Rect.fromLTRB(440, StadiaLayout.topBarHeight, 1400, 900),
    );

    wide.value = false;
    await tester.pump();
    expect(find.text('floating card'), findsOneWidget);
    expect(find.text('side panel'), findsNothing);
    expect(
      tester.getRect(find.byType(_Stage)),
      Offset.zero & const Size(1400, 900),
    );
    expect(tester.state(find.byType(_Stage)), same(state));

    wide.value = true;
    await tester.pump();
    expect(find.text('side panel'), findsOneWidget);
    expect(tester.state(find.byType(_Stage)), same(state));
  });

  group('map', () {
    late Stadium stadium;
    late List<FootballMatch> matches;

    Future<void> pumpMap(WidgetTester tester) async {
      final repo = LocalStadiumRepository(latency: Duration.zero);
      await tester.runAsync(() async {
        stadium = await repo.fetchStadium();
        matches = await repo.fetchUpcomingMatches();
      });
      await tester.pumpWidget(
        app(
          const MapScreen(),
          overrides: [
            stadiumProvider.overrideWithValue(AsyncData(stadium)),
            upcomingMatchesProvider.overrideWithValue(AsyncData(matches)),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('a wide window: top bar, matches in a side panel on the '
        'right, the map filling the rest', (tester) async {
      setWindow(tester, const Size(1440, 900));
      await pumpMap(tester);

      expect(find.byType(MapTopBar), findsOneWidget);
      expect(find.byType(UpcomingMatchesList), findsOneWidget);
      expect(find.byType(UpcomingMatchesCard), findsNothing);
      expect(
        matches.where((m) => m.stadiumId == stadium.id),
        isNotEmpty,
        reason: 'the fixture stadium has matches to list',
      );
      expect(find.byType(MatchCard), findsWidgets);
      expect(
        tester.getRect(find.byType(WideSidebar)),
        const Rect.fromLTRB(1000, StadiaLayout.topBarHeight, 1440, 900),
      );
      expect(
        tester.getRect(find.byType(FlutterMap)),
        const Rect.fromLTRB(0, StadiaLayout.topBarHeight, 1000, 900),
      );
      await unmount(tester);
    });

    testWidgets('a phone: the map full screen under the floating carousel', (
      tester,
    ) async {
      setWindow(tester, const Size(390, 844));
      await pumpMap(tester);

      expect(find.byType(MapTopBar), findsNothing);
      expect(find.byType(UpcomingMatchesCard), findsOneWidget);
      expect(
        tester.getRect(find.byType(FlutterMap)),
        Offset.zero & const Size(390, 844),
      );
      await unmount(tester);
    });
  });
}
