import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' hide Block;
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/payment/payment_service.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/seat_picker/booking_controller.dart';
import 'package:stadia/features/seat_picker/booking_machine.dart';
import 'package:stadia/features/seat_picker/seat_picker_screen.dart';
import 'package:stadia/features/seat_picker/seat_sheet.dart';
import 'package:stadia/features/stadium3d/stadium_scene_controller.dart';
import 'package:stadia/features/stadium3d/stadium_view.dart';
import 'package:stadia/features/ticket/ticket_screen.dart';
import 'package:stadia/features/ticket/widgets/ticket_card.dart';
import 'package:stadia/ui/format.dart';
import 'package:stadia/ui/theme.dart';

const _matchId = 'mco-mca-2026-11-28';

/// Seat picker -> real seat sheet -> mock checkout -> ticket screen, with
/// the 3D view replaced by a placeholder and scene events injected.
void main() {
  late LocalStadiumRepository repo;
  late StadiumSceneController scene;
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // The first read of the bundled JSON is real file I/O, which cannot
    // finish inside fake-async pumps: warm the repository caches first.
    await tester.runAsync(() async {
      await repo.fetchStadium();
      await repo.fetchUpcomingMatches();
      await repo.fetchAvailability(_matchId);
    });
    final router = GoRouter(
      initialLocation: '/match/$_matchId/seats',
      routes: [
        GoRoute(
          path: '/match/:matchId/seats',
          builder: (context, state) =>
              SeatPickerScreen(matchId: state.pathParameters['matchId']!),
        ),
        GoRoute(
          path: '/ticket/:ticketId',
          builder: (context, state) =>
              TicketScreen(ticketId: state.pathParameters['ticketId']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stadiumRepositoryProvider.overrideWithValue(repo),
          paymentServiceProvider.overrideWithValue(
            MockPaymentService(delay: Duration.zero),
          ),
          stadiumViewBuilderProvider.overrideWithValue((context, c, mode) {
            scene = c;
            if (!c.isAttached) c.attach((json) => _fakePage(c, json));
            return const SizedBox.expand();
          }),
        ],
        child: MaterialApp.router(
          theme: buildStadiaTheme(),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    container = ProviderScope.containerOf(
      tester.element(find.byType(SeatPickerScreen)),
    );
  }

  Future<void> fromScene(WidgetTester tester, String json) async {
    scene.handleIncoming(json);
    await settle(tester);
  }

  BookingState booking() => container.read(bookingControllerProvider(_matchId));

  /// Picks a free seat in the East Stand through the 3D events.
  Future<(Block, SeatRef)> pickEastSeat(WidgetTester tester) async {
    // Loaded by the picker. (Awaiting the repository directly would hang:
    // its latency timer only fires while the test pumps.)
    final loaded = container.read(bookingContextProvider(_matchId)).value!;
    final stadium = loaded.stadium;
    final availability = loaded.availability;
    late Block block;
    late SeatRef seat;
    search:
    for (final b in stadium.standById('E')!.blocks) {
      for (var r = 1; r <= b.rows; r++) {
        for (var s = 1; s <= b.seatsPerRow; s++) {
          final candidate = SeatRef(blockId: b.id, row: r, seat: s);
          if (availability.isSeatFree(b, candidate)) {
            (block, seat) = (b, candidate);
            break search;
          }
        }
      }
    }
    await fromScene(tester, '{"type":"ready"}');
    await fromScene(tester, '{"type":"select","level":"stand","id":"E"}');
    await fromScene(
      tester,
      '{"type":"select","level":"block","id":"${block.id}"}',
    );
    await fromScene(
      tester,
      '{"type":"select","level":"seat","id":"${seat.id}"}',
    );
    return (block, seat);
  }

  setUp(() => repo = LocalStadiumRepository(latency: Duration.zero));

  testWidgets('seat sheet -> VIP -> checkout -> "You\'re in"', (tester) async {
    await pumpApp(tester);
    final (block, seat) = await pickEastSeat(tester);
    final match = container.read(bookingContextProvider(_matchId)).value!.match;
    final price = match.priceFor(block);

    // The sheet: seat, view, block/row/seat/gate, price. (The picker's own
    // card is still in the tree behind it, so look inside the sheet only.)
    expect(booking().step, BookingStep.buy);
    expect(inSheet('Row ${seat.row} · Seat ${seat.seat}'), findsOneWidget);
    expect(inSheet('View from your seat'), findsOneWidget);
    expect(inSheet('Preview unavailable'), findsOneWidget); // no WebView
    expect(inSheet('${block.number}'), findsOneWidget);
    expect(inSheet('B'), findsOneWidget);
    expect(inSheet(formatPrice(price)), findsOneWidget);
    expect(
      scene.log.where((m) => m['type'] == 'renderView').single['seat'],
      seat.id,
    );
    // The sheet tells the scene how much of the screen it covers.
    final insets = scene.log.lastWhere((m) => m['type'] == 'insets');
    expect(insets['bottom'], greaterThan(300));

    // VIP: Gate E and the upgrade in the price.
    await tester.tap(find.textContaining('VIP upgrade'));
    await settle(tester);
    expect(booking().vip, isTrue);
    expect(inSheet('E'), findsOneWidget);
    expect(inSheet(formatPrice(price + 3000)), findsOneWidget);

    // Checkout.
    await tester.tap(find.text('Buy ticket'));
    await settle(tester);
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Pay ${formatPrice(price + 3000)}'), findsOneWidget);
    await tester.tap(find.text('Edahabia'));
    await settle(tester);
    await tester.tap(find.text('Pay ${formatPrice(price + 3000)}'));
    await settle(tester);

    // Ticket screen.
    expect(find.text("You're in"), findsOneWidget);
    final ticket = container.read(ticketWalletProvider).single;
    expect(ticket.seat, seat);
    expect(ticket.vip, isTrue);
    expect(ticket.gate.id, 'E');
    expect(ticket.total, price + 3000);
    expect(ticket.paymentReference, startsWith('MOCK-EDAHABIA-'));
    expect(
      tester.widget<TicketQr>(find.byType(TicketQr)).payload,
      ticket.qrPayload,
    );
    final sold = await tester.runAsync(() => repo.fetchAvailability(_matchId));
    expect(sold!.isSeatFree(block, seat), isFalse);
  });

  testWidgets('"Another seat" closes the sheet and goes back to seats', (
    tester,
  ) async {
    await pumpApp(tester);
    await pickEastSeat(tester);
    expect(find.text('Buy ticket'), findsOneWidget);

    await tester.tap(find.text('Another seat'));
    await settle(tester);

    expect(find.text('Buy ticket'), findsNothing);
    expect(booking().step, BookingStep.seat);
    expect(booking().seat, isNull);
    expect(container.read(ticketWalletProvider), isEmpty);
  });

  testWidgets('a seat taken before paying is not charged', (tester) async {
    await pumpApp(tester);
    final (_, seat) = await pickEastSeat(tester);
    final match = container.read(bookingContextProvider(_matchId)).value!.match;
    // Someone else books it while the sheet is open.
    await tester.runAsync(
      () => repo.issueTicket(
        match: match,
        seat: seat,
        vip: false,
        receipt: PaymentReceipt(
          reference: 'OTHER',
          amount: 1,
          method: PaymentMethod.cib,
          paidAt: DateTime(2026, 11, 22),
        ),
      ),
    );

    await tester.tap(find.text('Buy ticket'));
    await settle(tester);
    await tester.tap(find.textContaining('Pay '));
    await settle(tester);

    expect(find.text('That seat was just taken'), findsOneWidget);
    expect(find.textContaining('Nothing was charged.'), findsOneWidget);
    expect(container.read(ticketWalletProvider), isEmpty);

    await tester.tap(find.text('Pick another seat'));
    await settle(tester);
    expect(booking().step, BookingStep.seat);
  });
}

/// Stands in for the WebView page: answers seat-view renders the way the
/// page does when it cannot render (empty data URL).
void _fakePage(StadiumSceneController scene, String json) {
  final message = jsonDecode(json) as Map<String, Object?>;
  if (message['type'] != 'renderView') return;
  scheduleMicrotask(
    () => scene.handleIncoming(
      jsonEncode({
        'type': 'view',
        'requestId': message['requestId'],
        'seat': message['seat'],
        'dataUrl': '',
      }),
    ),
  );
}

Finder inSheet(String text) =>
    find.descendant(of: find.byType(SeatSheet), matching: find.text(text));

/// Frame-by-frame pumping (the scene loader animates forever, so
/// pumpAndSettle would never return).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
