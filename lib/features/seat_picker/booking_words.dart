import '../../data/models/match.dart';
import '../../data/models/stadium.dart';
import '../../data/payment/payment_service.dart';
import '../../l10n/l10n.dart';
import 'booking_machine.dart';

/// How the booking flow words things, in the current language.
extension BookingWords on AppLocalizations {
  String step(BookingStep s) => switch (s) {
    BookingStep.stand => stepStand,
    BookingStep.block => stepBlock,
    BookingStep.seat => stepSeat,
    BookingStep.buy => stepBuy,
  };

  String match(FootballMatch m) => matchTitle(m.home.name, m.away.name);

  /// "Lower tier" / "Upper tier", or "36 rows" in a single-tier bowl.
  String tier(Stand s, Block b) => !s.hasUpperTier
      ? rowCount(b.rows)
      : b.tier == 1
      ? tierLower
      : tierUpper;

  /// "Row 12 · Seat 7" / "Block 104" / "East Stand".
  String summaryTitle(SelectionSummary s) => switch (s.level) {
    SelectionLevel.seat => rowSeat(s.seat!.row, s.seat!.seat),
    SelectionLevel.block => blockNumber(s.block!.number),
    SelectionLevel.stand => s.stand.name,
  };

  /// "East Stand · Block 104" / "East Stand · Lower tier" / "Tribune Est".
  String summarySubtitle(SelectionSummary s) => switch (s.level) {
    SelectionLevel.seat => '${s.stand.name} · ${blockNumber(s.block!.number)}',
    SelectionLevel.block => '${s.stand.name} · ${tier(s.stand, s.block!)}',
    SelectionLevel.stand => s.stand.nickname,
  };

  String method(PaymentMethod m) => switch (m) {
    PaymentMethod.cib => paymentCib,
    PaymentMethod.edahabia => paymentEdahabia,
  };

  String methodCaption(PaymentMethod m) => switch (m) {
    PaymentMethod.cib => paymentCibCaption,
    PaymentMethod.edahabia => paymentEdahabiaCaption,
  };
}
