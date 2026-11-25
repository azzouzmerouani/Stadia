import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/seat_picker/seat_picker_screen.dart';
import 'package:stadia/features/seat_picker/widgets/selection_card.dart';
import 'package:stadia/features/stadium3d/stadium_scene_controller.dart';
import 'package:stadia/features/stadium3d/stadium_view.dart';
import 'package:stadia/l10n/l10n.dart';
import 'package:stadia/ui/stage_frame.dart';
import 'package:stadia/ui/step_progress.dart';
import 'package:stadia/ui/theme.dart';

// Its own file: rootBundle caches asset loads across the tests of a file,
// and a load another screen started under an earlier test's fake clock
// never completes under this one's.

void main() {
  testWidgets('a wide seat picker: steps in the top bar, the selection in '
      'the side panel, the 3D beside it, uncovered', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late StadiumSceneController scene;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stadiumRepositoryProvider.overrideWithValue(
            LocalStadiumRepository(latency: Duration.zero),
          ),
          stadiumViewBuilderProvider.overrideWithValue((
            context,
            controller,
            mode,
            stadiumId,
          ) {
            scene = controller;
            return const SizedBox.expand(key: Key('fake-3d'));
          }),
        ],
        // Arabic, as shipped: the side panel on the right.
        child: MaterialApp(
          theme: buildStadiaTheme(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SeatPickerScreen(matchId: 'mco-mca-2026-11-28'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.descendant(
        of: find.byType(WideTopBar),
        matching: find.byType(StepProgressBar),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(WideSidebar),
        matching: find.byType(SelectionCard),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(const Key('fake-3d'))),
      const Rect.fromLTRB(0, StadiaLayout.topBarHeight, 840, 800),
    );

    await tester.pump(const Duration(milliseconds: 500));
    final insets = scene.log.where((m) => m['type'] == 'insets');
    expect(insets.last, {'type': 'insets', 'top': 16, 'bottom': 16});
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
