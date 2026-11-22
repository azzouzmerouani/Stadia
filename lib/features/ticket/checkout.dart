import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/stadium.dart';
import '../../data/models/ticket.dart';
import '../../data/payment/payment_service.dart';
import '../../data/providers.dart';
import '../../data/repositories/stadium_repository.dart';
import '../seat_picker/booking_controller.dart';

/// What happened when the fan pressed Pay.
sealed class CheckoutOutcome {
  const CheckoutOutcome();
}

class CheckoutDone extends CheckoutOutcome {
  const CheckoutDone(this.ticket);
  final Ticket ticket;
}

/// Someone else got the seat first. [refundReference] is set when the
/// payment had already gone through and has to be refunded.
class CheckoutSeatTaken extends CheckoutOutcome {
  const CheckoutSeatTaken({this.refundReference});
  final String? refundReference;
}

enum CheckoutFailure { seatGone, payment }

class CheckoutFailed extends CheckoutOutcome {
  const CheckoutFailed(this.reason, [this.message]);

  /// What the fan is told (translated by the UI).
  final CheckoutFailure reason;

  /// The payment provider's own wording, for logs and support.
  final String? message;
}

class CheckoutCancelled extends CheckoutOutcome {
  const CheckoutCancelled();
}

/// Price lines for one seat plus the optional VIP upgrade.
class OrderQuote {
  const OrderQuote({
    required this.seatPrice,
    required this.vipPrice,
    required this.vip,
  });

  factory OrderQuote.of(
    BookingContext context,
    SeatRef seat, {
    required bool vip,
  }) {
    final block = context.stadium.blockById(seat.blockId);
    return OrderQuote(
      seatPrice: block == null ? 0 : context.match.priceFor(block),
      vipPrice: context.stadium.vipUpgradePrice,
      vip: vip,
    );
  }

  final int seatPrice;
  final int vipPrice;
  final bool vip;

  int get total => seatPrice + (vip ? vipPrice : 0);
}

/// Pay -> issue ticket -> wallet. Talks only to [PaymentService] and
/// [StadiumRepository], so the mock and the Chargily/Supabase versions are
/// interchangeable.
///
/// Production note: the seat should be held server-side (with a TTL) before
/// the fan is sent to Chargily, and the ticket issued by the webhook. The
/// availability re-check below only narrows the race for the mock.
class Checkout {
  Checkout(this._ref);

  final Ref _ref;

  Future<CheckoutOutcome> buy({
    required BookingContext context,
    required SeatRef seat,
    required bool vip,
    required PaymentMethod method,
  }) async {
    final repository = _ref.read(stadiumRepositoryProvider);
    final match = context.match;
    final block = context.stadium.blockById(seat.blockId);
    final stand = block == null
        ? null
        : context.stadium.standById(block.standId);
    if (block == null || stand == null) {
      return const CheckoutFailed(CheckoutFailure.seatGone);
    }

    // The picker's availability may be minutes old: check before charging.
    final latest = await repository.fetchAvailability(match.id);
    if (!latest.isSeatFree(block, seat)) {
      _refreshAvailability(match.id);
      return const CheckoutSeatTaken();
    }

    final quote = OrderQuote.of(context, seat, vip: vip);
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final request = PaymentRequest(
      orderId: 'ORD-${seat.id}-$stamp'.toUpperCase(),
      amount: quote.total,
      method: method,
      // Language-neutral: shown on Chargily's page and in bank statements.
      description:
          '${match.home.shortName} v ${match.away.shortName} · '
          '${stand.id}${block.number} R${seat.row} S${seat.seat}'
          '${vip ? ' · VIP' : ''}',
    );

    final result = await _ref.read(paymentServiceProvider).pay(request);
    return switch (result) {
      PaymentCancelled() => const CheckoutCancelled(),
      PaymentFailed(:final message) => CheckoutFailed(
        CheckoutFailure.payment,
        message,
      ),
      PaymentSucceeded(:final receipt) => await _issue(
        context: context,
        seat: seat,
        vip: vip,
        receipt: receipt,
      ),
    };
  }

  Future<CheckoutOutcome> _issue({
    required BookingContext context,
    required SeatRef seat,
    required bool vip,
    required PaymentReceipt receipt,
  }) async {
    final matchId = context.match.id;
    try {
      final ticket = await _ref
          .read(stadiumRepositoryProvider)
          .issueTicket(
            match: context.match,
            seat: seat,
            vip: vip,
            receipt: receipt,
          );
      _ref.read(ticketWalletProvider.notifier).add(ticket);
      _refreshAvailability(matchId);
      return CheckoutDone(ticket);
    } on SeatUnavailableException {
      _refreshAvailability(matchId);
      return CheckoutSeatTaken(refundReference: receipt.reference);
    }
  }

  /// The seat map should show the new sale (or the seat someone else took).
  void _refreshAvailability(String matchId) =>
      _ref.invalidate(availabilityProvider(matchId));
}

final checkoutProvider = Provider<Checkout>(Checkout.new);
