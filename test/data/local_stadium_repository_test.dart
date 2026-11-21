import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/payment/payment_service.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/data/repositories/stadium_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStadiumRepository repo;

  setUp(() => repo = LocalStadiumRepository(latency: Duration.zero));

  test('stadium layout is the configured ~40k-seat Algerian stadium', () async {
    final s = await repo.fetchStadium();
    expect(s.name, 'Stade Miloud Hadefi');
    expect(s.stands.map((st) => st.id), ['N', 'E', 'S', 'W']);
    expect(s.blocks.length, 56);
    expect(s.capacity, 40320);
    expect(s.blockById('N_101')!.meshName, 'Block_N_101');
    expect(s.standById('W')!.hasVip, isTrue);
    expect(s.gates.map((g) => g.id), containsAll(['A', 'B', 'C', 'D', 'E']));
  });

  test('matches are sorted by kickoff and priced per block', () async {
    final s = await repo.fetchStadium();
    final matches = await repo.fetchUpcomingMatches();
    expect(matches, isNotEmpty);
    for (var i = 1; i < matches.length; i++) {
      expect(matches[i].kickoff.isAfter(matches[i - 1].kickoff), isTrue);
    }
    final derby = matches.firstWhere((m) => m.away.id == 'MCA');
    expect(derby.priceFor(s.blockById('W_101')!), 3000); // 2000 × 1.5
    expect(derby.fromPrice(s), 600); // 400 × 1.5 upper virage
  });

  test('availability is deterministic per match', () async {
    final m = (await repo.fetchUpcomingMatches()).first;
    final s = await repo.fetchStadium();
    final a = LocalStadiumRepository.generateAvailability(s, m);
    final b = LocalStadiumRepository.generateAvailability(s, m);
    expect(a.freeTotal, b.freeTotal);
    expect(a.block('E_104')!.sold, b.block('E_104')!.sold);
    expect(a.freeTotal, inInclusiveRange(1, s.capacity - 1));
  });

  test('issuing a ticket sells the seat and rejects double booking', () async {
    final s = await repo.fetchStadium();
    final m = (await repo.fetchUpcomingMatches()).last;
    final avail = await repo.fetchAvailability(m.id);
    final block = s.blocks.firstWhere((b) => !avail.block(b.id)!.isSoldOut);
    final index = Iterable<int>.generate(block.capacity)
        .firstWhere((i) => !avail.block(block.id)!.isSold(i));
    final seat = block.seatAt(index);

    final receipt = PaymentReceipt(
      reference: 'TEST',
      amount: 1000,
      method: PaymentMethod.cib,
      paidAt: DateTime(2026, 11, 21, 10),
    );
    final ticket = await repo.issueTicket(
      match: m,
      seat: seat,
      vip: false,
      receipt: receipt,
    );
    expect(ticket.seat, seat);
    expect(ticket.gate.id, s.standById(block.standId)!.gateId);
    expect(ticket.qrPayload, contains(seat.id));

    final after = await repo.fetchAvailability(m.id);
    expect(after.isSeatFree(block, seat), isFalse);
    expect(
      () => repo.issueTicket(match: m, seat: seat, vip: false, receipt: receipt),
      throwsA(isA<SeatUnavailableException>()),
    );
  });

  test('seat ids round-trip', () {
    const seat = SeatRef(blockId: 'E_204', row: 12, seat: 7);
    expect(seat.id, 'E_204_R12_S7');
    expect(SeatRef.tryParse(seat.id), seat);
    expect(SeatRef.tryParse('Block_E_204'), isNull);
    expect(Stadium.stripMeshPrefix('Seats_E_204'), 'E_204');
  });
}
