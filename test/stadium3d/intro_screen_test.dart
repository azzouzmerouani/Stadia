import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/stadium3d/intro_screen.dart';
import 'package:stadia/features/stadium3d/stadium_scene_controller.dart';
import 'package:stadia/features/stadium3d/stadium_view.dart';
import 'package:stadia/l10n/l10n.dart';
import 'package:stadia/ui/theme.dart';

void main() {
  late StadiumSceneController scene;

  Future<void> pumpIntro(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/intro',
      routes: [
        GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
        GoRoute(path: '/map', builder: (_, _) => const Text('MAP')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stadiumRepositoryProvider.overrideWithValue(
            LocalStadiumRepository(latency: Duration.zero),
          ),
          stadiumViewBuilderProvider.overrideWithValue((context, c, mode) {
            scene = c;
            return const SizedBox.expand(key: Key('fake-3d'));
          }),
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
    await tester.pump();
  }

  testWidgets('plays until the scene reports introDone, then goes to the map', (
    tester,
  ) async {
    await pumpIntro(tester);
    expect(find.byKey(const Key('fake-3d')), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(scene.log.first, {'type': 'init', 'mode': 'intro'});

    scene.handleIncoming('{"type":"ready"}');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Stade Miloud Hadefi'), findsOneWidget);
    expect(find.text('MAP'), findsNothing);

    scene.handleIncoming('{"type":"introDone"}');
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
  });

  testWidgets('Skip tells the scene and leaves right away', (tester) async {
    await pumpIntro(tester);
    scene.handleIncoming('{"type":"ready"}');
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(scene.log.map((m) => m['type']), contains('skipIntro'));
    expect(find.text('MAP'), findsOneWidget);
  });

  testWidgets('falls through to the map if the scene never loads', (
    tester,
  ) async {
    await pumpIntro(tester);
    await tester.pump(IntroScreen.loadTimeout);
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
  });
}
