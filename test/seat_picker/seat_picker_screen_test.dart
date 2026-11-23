import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/models/availability.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/seat_picker/booking_controller.dart';
import 'package:stadia/features/seat_picker/booking_machine.dart';
import 'package:stadia/features/seat_picker/seat_panel.dart';
import 'package:stadia/features/seat_picker/seat_picker_screen.dart';
import 'package:stadia/features/stadium3d/stadium_scene_controller.dart';
import 'package:stadia/features/stadium3d/stadium_view.dart';
import 'package:stadia/l10n/l10n.dart';
import 'package:stadia/ui/theme.dart';

/// Real JSON data, but a hand-made availability: E_101 sold out and the
/// first three seats of E_104 taken.
class _FakeRepo extends LocalStadiumRepository {
  _FakeRepo() : super(latency: Duration.zero);

  @override
  Future<MatchAvailability> fetchAvailability(String matchId) async {
    final stadium = await fetchStadium();
    return MatchAvailability(
      matchId: matchId,
      blocks: {
        for (final b in stadium.blocks)
          b.id: BlockAvailability(
            blockId: b.id,
            capacity: b.capacity,
            sold: b.id == 'E_101'
                ? {for (var i = 0; i < b.capacity; i++) i}
                : b.id == 'E_104'
                ? {0, 1, 2}
                : const {},
          ),
      },
    );
  }
}

const matchId = 'mco-mca-2026-11-28';

void main() {
  late StadiumSceneController scene;

  Future<ProviderContainer> pumpPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stadiumRepositoryProvider.overrideWithValue(_FakeRepo()),
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
        child: MaterialApp(
          theme: buildStadiaTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SeatPickerScreen(matchId: matchId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return ProviderScope.containerOf(
      tester.element(find.byType(SeatPickerScreen)),
    );
  }

  Future<void> fromScene(WidgetTester tester, String json) async {
    scene.handleIncoming(json);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Map<String, Object?> lastOf(String type) =>
      scene.log.lastWhere((m) => m['type'] == type);

  testWidgets('drives the booking state machine from 3D selections', (
    tester,
  ) async {
    final container = await pumpPicker(tester);
    BookingState state() => container.read(bookingControllerProvider(matchId));

    expect(find.byKey(const Key('fake-3d')), findsOneWidget);
    expect(find.text('Tap a stand to zoom in'), findsOneWidget);
    expect(find.text('MC Oran vs MC Alger'), findsOneWidget);

    // Scene ready: Flutter pushes availability + current step.
    await fromScene(tester, '{"type":"ready"}');
    expect(lastOf('availability'), isNotNull);
    expect(lastOf('setStep')['step'], 'stand');
    expect(
      scene.log
          .where((m) => m['type'] == 'availability')
          .map((m) => m['level']),
      containsAll(['stand', 'block']),
    );

    // Stand.
    await fromScene(tester, '{"type":"select","level":"stand","id":"E"}');
    expect(state().step, BookingStep.block);
    expect(find.text('East Stand'), findsOneWidget);
    expect(lastOf('setStep'), containsPair('stand', 'E'));
    expect(find.text('Free'), findsOneWidget); // legend

    // Sold-out block: notice, no step change.
    await fromScene(tester, '{"type":"select","level":"block","id":"E_101"}');
    expect(state().step, BookingStep.block);
    expect(find.text('This block is sold out, try another'), findsOneWidget);

    // Block.
    await fromScene(tester, '{"type":"select","level":"block","id":"E_104"}');
    expect(state().step, BookingStep.seat);
    expect(find.text('Block 104'), findsOneWidget);
    expect(lastOf('setStep'), containsPair('block', 'E_104'));
    final seats = lastOf('availability');
    expect(seats['level'], 'seat');
    expect(seats['sold'], [0, 1, 2]);

    // Taken seat, then a free one.
    await fromScene(
      tester,
      '{"type":"select","level":"seat","id":"E_104_R1_S2"}',
    );
    expect(state().step, BookingStep.seat);
    expect(find.text('That seat is taken, pick a free one'), findsOneWidget);

    await fromScene(
      tester,
      '{"type":"select","level":"seat","id":"E_104_R12_S7"}',
    );
    expect(state().step, BookingStep.buy);
    // The camera goes into the seat; the panel is part of this screen (no
    // route pushed), and the 3D stays in the tree behind it.
    expect(lastOf('setStep'), containsPair('step', 'buy'));
    expect(lastOf('setStep')['seat'], 'E_104_R12_S7');
    expect(find.byType(SeatPanel), findsOneWidget);
    expect(find.byKey(const Key('fake-3d')), findsOneWidget);
    expect(find.text('Row 12 · Seat 7'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // "seat taken" toast ends
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('View from your seat · Drag to look around'),
      findsOneWidget,
    );
    expect(find.text('Tap a stand to zoom in'), findsNothing);

    // Checkout, then system back: back to the seat stage, still seated.
    await tester.tap(find.text('Buy ticket'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Checkout'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(); // starts the cross-fade
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Checkout'), findsNothing);
    expect(find.text('Buy ticket'), findsOneWidget);
    expect(state().step, BookingStep.buy);

    // "Another seat" -> back to picking a seat, camera out of the seat.
    await tester.tap(find.text('Another seat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(state().step, BookingStep.seat);
    expect(state().seat, isNull);
    expect(find.byType(SeatPanel), findsNothing);
    expect(lastOf('setStep'), containsPair('step', 'seat'));

    // Back button goes up one level.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(state().step, BookingStep.block);
    expect(find.text('East Stand'), findsOneWidget);

    // Progress bar: jump back to Stand.
    await tester.tap(find.byKey(const ValueKey('step-0')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(state(), const BookingState());
    expect(lastOf('setStep')['step'], 'stand');

    await tester.pump(const Duration(seconds: 3)); // let the toast expire
  });
}
