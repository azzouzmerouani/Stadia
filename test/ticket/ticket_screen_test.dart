import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stadia/data/models/match.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/models/ticket.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/features/ticket/ticket_screen.dart';
import 'package:stadia/features/ticket/widgets/ticket_card.dart';
import 'package:stadia/ui/format.dart';
import 'package:stadia/ui/theme.dart';

const _home = Team(
  id: 'MCO',
  name: 'MC Oran',
  shortName: 'MCO',
  city: 'Oran',
  primaryColor: 0xFFD71920,
  secondaryColor: 0xFFFFFFFF,
);
const _away = Team(
  id: 'MCA',
  name: 'MC Alger',
  shortName: 'MCA',
  city: 'Algiers',
  primaryColor: 0xFFC8102E,
  secondaryColor: 0xFF00843D,
);

Ticket _ticket({bool vip = false}) {
  final id = vip ? 'STD-VIP42' : 'STD-ABC123';
  final gate = vip
      ? const Gate(
          id: 'E',
          name: 'Gate E · VIP',
          position: GeoPoint(35.7, -0.6),
        )
      : const Gate(id: 'B', name: 'Gate B', position: GeoPoint(35.7, -0.6));
  return Ticket(
    id: id,
    match: FootballMatch(
      id: 'mco-mca',
      stadiumId: 'oran',
      home: _home,
      away: _away,
      kickoff: DateTime(2026, 11, 28, 20),
      competition: 'Ligue 1',
      round: 'Matchday 12',
      priceMultiplier: 1,
      demand: 0.5,
    ),
    stadiumName: 'Stade Miloud Hadefi',
    standName: 'East Stand',
    blockNumber: 105,
    seat: const SeatRef(blockId: 'E_105', row: 10, seat: 21),
    gate: gate,
    price: 1500,
    vip: vip,
    vipPrice: 3000,
    gatesOpenAt: DateTime(2026, 11, 28, 18),
    issuedAt: DateTime(2026, 11, 22, 10),
    paymentReference: 'MOCK-CIB-1',
    qrPayload: 'STADIA:1:$id:mco-mca:E_105_R10_S21:${gate.id}',
  );
}

class _Wallet extends TicketWallet {
  _Wallet(this.seed);

  final List<Ticket> seed;

  @override
  List<Ticket> build() => seed;
}

Future<void> _pump(
  WidgetTester tester, {
  required String ticketId,
  List<Ticket> tickets = const [],
}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/ticket/$ticketId',
    routes: [
      GoRoute(
        path: '/ticket/:ticketId',
        builder: (context, state) =>
            TicketScreen(ticketId: state.pathParameters['ticketId']!),
      ),
      GoRoute(path: '/map', builder: (context, state) => const Text('MAP')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ticketWalletProvider.overrideWith(() => _Wallet(tickets))],
      child: MaterialApp.router(
        theme: buildStadiaTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the booked seat, the gate and the entry QR', (
    tester,
  ) async {
    final ticket = _ticket();
    await _pump(tester, ticketId: ticket.id, tickets: [ticket]);

    expect(find.text("You're in"), findsOneWidget);
    expect(find.text('MC Oran'), findsOneWidget);
    expect(find.text('MC Alger'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Stade Miloud Hadefi'), findsOneWidget);

    expect(find.text('East Stand'), findsOneWidget);
    expect(find.text('105'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text(formatPrice(1500)), findsOneWidget);
    expect(find.text('VIP'), findsNothing);

    final qr = tester.widget<TicketQr>(find.byType(TicketQr));
    expect(qr.payload, 'STADIA:1:STD-ABC123:mco-mca:E_105_R10_S21:B');
    expect(find.text('STD-ABC123'), findsOneWidget);
    expect(find.text('Scan at Gate B'), findsOneWidget);

    expect(find.text('Gates open at 18:00'), findsOneWidget);
    expect(
      find.textContaining('2 h before kick-off. Use Gate B'),
      findsOneWidget,
    );
  });

  testWidgets('a VIP ticket includes the upgrade and uses Gate E', (
    tester,
  ) async {
    final ticket = _ticket(vip: true);
    await _pump(tester, ticketId: ticket.id, tickets: [ticket]);

    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.text(formatPrice(4500)), findsOneWidget);
    expect(find.textContaining('VIP fast lane'), findsOneWidget);
    expect(
      tester.widget<TicketQr>(find.byType(TicketQr)).payload,
      endsWith(':E'),
    );
  });

  testWidgets('an unknown ticket id shows a way back', (tester) async {
    await _pump(tester, ticketId: 'STD-NOPE', tickets: [_ticket()]);

    expect(find.text('Ticket not found'), findsOneWidget);
    expect(find.byType(TicketQr), findsNothing);
  });

  testWidgets('"Back to the map" leaves the booking flow', (tester) async {
    final ticket = _ticket();
    await _pump(tester, ticketId: ticket.id, tickets: [ticket]);

    await tester.tap(find.text('Back to the map'));
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
  });

  test('the ticket halves are notched at the tear line', () {
    const size = Size(300, 200);
    final top = const TicketClipper(notchAt: NotchEdge.bottom).getClip(size);
    final bottom = const TicketClipper(notchAt: NotchEdge.top).getClip(size);

    // Notch: cut out at both ends of the tear line, solid in between.
    expect(top.contains(const Offset(3, 197)), isFalse);
    expect(top.contains(const Offset(297, 197)), isFalse);
    expect(top.contains(const Offset(150, 197)), isTrue);
    expect(bottom.contains(const Offset(3, 3)), isFalse);
    expect(bottom.contains(const Offset(297, 3)), isFalse);
    expect(bottom.contains(const Offset(150, 3)), isTrue);
    // The outer corners stay rounded, the sides straight.
    expect(top.contains(const Offset(1, 1)), isFalse);
    expect(top.contains(const Offset(1, 100)), isTrue);
  });
}
