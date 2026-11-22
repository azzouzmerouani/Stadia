import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/payment/payment_service.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/seat_picker/booking_controller.dart';
import 'package:stadia/features/ticket/checkout.dart';

/// Records every request and answers with [answer].
class _Payments implements PaymentService {
  _Payments(this.answer);

  final PaymentResult Function(PaymentRequest request) answer;
  final requests = <PaymentRequest>[];

  @override
  Future<PaymentResult> pay(PaymentRequest request) async {
    requests.add(request);
    return answer(request);
  }
}

PaymentResult _approve(PaymentRequest r) => PaymentSucceeded(
  PaymentReceipt(
    reference: 'TEST-${r.method.name}',
    amount: r.amount,
    method: r.method,
    paidAt: DateTime(2026, 11, 22, 10, 30),
  ),
);

const _matchId = 'mco-mca-2026-11-28';

void main() {
  // The repository reads the bundled JSON through rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStadiumRepository repo;

  setUp(() => repo = LocalStadiumRepository(latency: Duration.zero));

  ProviderContainer containerWith(PaymentService payments) =>
      ProviderContainer.test(
        overrides: [
          stadiumRepositoryProvider.overrideWithValue(repo),
          paymentServiceProvider.overrideWithValue(payments),
        ],
      );

  /// A free seat in the East Stand and the context the sheet would pass.
  Future<(BookingContext, Block, SeatRef)> freeEastSeat() async {
    final stadium = await repo.fetchStadium();
    final availability = await repo.fetchAvailability(_matchId);
    final context = BookingContext(
      stadium: stadium,
      match: await repo.fetchMatch(_matchId),
      availability: availability,
    );
    for (final block in stadium.standById('E')!.blocks) {
      for (var row = 1; row <= block.rows; row++) {
        for (var seat = 1; seat <= block.seatsPerRow; seat++) {
          final ref = SeatRef(blockId: block.id, row: row, seat: seat);
          if (availability.isSeatFree(block, ref)) return (context, block, ref);
        }
      }
    }
    fail('No free seat in the East Stand');
  }

  test(
    'pays the seat price, issues the ticket and marks the seat sold',
    () async {
      final payments = _Payments(_approve);
      final container = containerWith(payments);
      final (ctx, block, seat) = await freeEastSeat();

      final outcome = await container
          .read(checkoutProvider)
          .buy(
            context: ctx,
            seat: seat,
            vip: false,
            method: PaymentMethod.edahabia,
          );

      expect(outcome, isA<CheckoutDone>());
      final ticket = (outcome as CheckoutDone).ticket;
      final request = payments.requests.single;
      expect(request.amount, ctx.match.priceFor(block));
      expect(request.method, PaymentMethod.edahabia);
      expect(request.orderId, startsWith('ORD-${seat.id}'));
      expect(ticket.seat, seat);
      expect(ticket.gate.id, 'B');
      expect(ticket.total, request.amount);
      expect(ticket.paymentReference, 'TEST-edahabia');
      expect(ticket.qrPayload, contains(seat.id));

      expect(container.read(ticketWalletProvider), [ticket]);
      final after = await repo.fetchAvailability(_matchId);
      expect(after.isSeatFree(block, seat), isFalse);
    },
  );

  test(
    'VIP adds the upgrade to the charge and routes through Gate E',
    () async {
      final payments = _Payments(_approve);
      final container = containerWith(payments);
      final (ctx, block, seat) = await freeEastSeat();

      final outcome = await container
          .read(checkoutProvider)
          .buy(context: ctx, seat: seat, vip: true, method: PaymentMethod.cib);

      final ticket = (outcome as CheckoutDone).ticket;
      expect(
        payments.requests.single.amount,
        ctx.match.priceFor(block) + ctx.stadium.vipUpgradePrice,
      );
      expect(payments.requests.single.description, endsWith('VIP'));
      expect(ticket.vip, isTrue);
      expect(ticket.gate.id, 'E');
      expect(ticket.total, payments.requests.single.amount);
    },
  );

  test('a declined payment issues nothing and keeps the seat free', () async {
    final container = containerWith(
      _Payments((_) => const PaymentFailed('Card declined by the bank')),
    );
    final (ctx, block, seat) = await freeEastSeat();

    final outcome = await container
        .read(checkoutProvider)
        .buy(context: ctx, seat: seat, vip: false, method: PaymentMethod.cib);

    expect(outcome, isA<CheckoutFailed>());
    expect((outcome as CheckoutFailed).message, 'Card declined by the bank');
    expect(container.read(ticketWalletProvider), isEmpty);
    final after = await repo.fetchAvailability(_matchId);
    expect(after.isSeatFree(block, seat), isTrue);
  });

  test('a cancelled payment issues nothing', () async {
    final container = containerWith(_Payments((_) => const PaymentCancelled()));
    final (ctx, _, seat) = await freeEastSeat();

    final outcome = await container
        .read(checkoutProvider)
        .buy(context: ctx, seat: seat, vip: false, method: PaymentMethod.cib);

    expect(outcome, isA<CheckoutCancelled>());
    expect(container.read(ticketWalletProvider), isEmpty);
  });

  test('a seat sold in the meantime is never charged', () async {
    final payments = _Payments(_approve);
    final container = containerWith(payments);
    final (ctx, _, seat) = await freeEastSeat();
    // Someone else buys it after the picker loaded its availability.
    await repo.issueTicket(
      match: ctx.match,
      seat: seat,
      vip: false,
      receipt: PaymentReceipt(
        reference: 'OTHER',
        amount: 1,
        method: PaymentMethod.cib,
        paidAt: DateTime(2026, 11, 22, 10),
      ),
    );

    final outcome = await container
        .read(checkoutProvider)
        .buy(context: ctx, seat: seat, vip: false, method: PaymentMethod.cib);

    expect(outcome, isA<CheckoutSeatTaken>());
    expect((outcome as CheckoutSeatTaken).refundReference, isNull);
    expect(payments.requests, isEmpty);
    expect(container.read(ticketWalletProvider), isEmpty);
  });
}
