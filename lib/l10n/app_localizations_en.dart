// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stadia';

  @override
  String get loadingStadium => 'Loading the stadium';

  @override
  String get preparingSeats => 'Preparing stands, blocks and seats';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try again';

  @override
  String seatCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String get backToStadium => 'Back to the stadium';

  @override
  String get osmCredit => '© OpenStreetMap contributors';

  @override
  String get osmCreditSemantics => 'Map data © OpenStreetMap contributors';

  @override
  String get upcomingMatches => 'Upcoming matches';

  @override
  String get priceFrom => 'from';

  @override
  String get chooseSeats => 'Choose seats';

  @override
  String matchTitle(String home, String away) {
    return '$home vs $away';
  }

  @override
  String get stepStand => 'Stand';

  @override
  String get stepBlock => 'Block';

  @override
  String get stepSeat => 'Seat';

  @override
  String get stepBuy => 'Buy';

  @override
  String stepProgress(int current, int total, String label) {
    return 'Step $current of $total: $label';
  }

  @override
  String backToStep(String label) {
    return 'Back to $label';
  }

  @override
  String get standSoldOut => 'This stand is sold out';

  @override
  String get blockSoldOut => 'This block is sold out, try another';

  @override
  String get seatTakenNotice => 'That seat is taken, pick a free one';

  @override
  String get tapStandHint => 'Tap a stand to zoom in';

  @override
  String get back => 'Back';

  @override
  String get backToMatches => 'Back to matches';

  @override
  String get legendFree => 'Free';

  @override
  String get legendFewLeft => 'Few left';

  @override
  String get legendSold => 'Sold';

  @override
  String get levelStand => 'Stand';

  @override
  String get levelBlock => 'Block';

  @override
  String get levelYourSeat => 'Your seat';

  @override
  String get soldOut => 'Sold out';

  @override
  String freeCount(String count) {
    return '$count free';
  }

  @override
  String rowSeat(int row, int seat) {
    return 'Row $row · Seat $seat';
  }

  @override
  String blockNumber(int number) {
    return 'Block $number';
  }

  @override
  String get tierLower => 'Lower tier';

  @override
  String get tierUpper => 'Upper tier';

  @override
  String get perTicket => 'per ticket';

  @override
  String get inclVip => 'incl. VIP';

  @override
  String get labelStand => 'Stand';

  @override
  String get labelBlock => 'Block';

  @override
  String get labelRow => 'Row';

  @override
  String get labelSeat => 'Seat';

  @override
  String get labelGate => 'Gate';

  @override
  String get labelPaid => 'Paid';

  @override
  String get vipUpgrade => 'VIP upgrade';

  @override
  String get vipPerks => 'Lounge access · Gate E fast lane';

  @override
  String get anotherSeat => 'Another seat';

  @override
  String get buyTicket => 'Buy ticket';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get testMode => 'Test mode · no card is charged';

  @override
  String get backToSeat => 'Back to seat';

  @override
  String get total => 'Total';

  @override
  String get payWith => 'Pay with';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get seatJustTaken => 'That seat was just taken';

  @override
  String seatTakenBody(String money) {
    return 'Someone booked it a moment before you. $money';
  }

  @override
  String get nothingCharged => 'Nothing was charged.';

  @override
  String willBeRefunded(String reference) {
    return 'Payment $reference will be refunded.';
  }

  @override
  String get pickAnotherSeat => 'Pick another seat';

  @override
  String get viewFromSeat => 'View from your seat';

  @override
  String get dragToLookAround => 'Drag to look around';

  @override
  String get paymentCib => 'CIB';

  @override
  String get paymentCibCaption => 'Interbank card';

  @override
  String get paymentEdahabia => 'Edahabia';

  @override
  String get paymentEdahabiaCaption => 'Algérie Poste';

  @override
  String get errorSeatGone => 'This seat does not exist any more.';

  @override
  String get errorPayment =>
      'The payment did not go through. Nothing was charged.';

  @override
  String get youreIn => 'You\'re in';

  @override
  String paidRef(String amount, String reference) {
    return 'Paid $amount · Ref $reference';
  }

  @override
  String get backToMap => 'Back to the map';

  @override
  String gatesOpenAt(String time) {
    return 'Gates open at $time';
  }

  @override
  String gatesLead(String lead, String where) {
    return 'That\'s $lead before kick-off. $where';
  }

  @override
  String leadHours(int count) {
    return '$count h';
  }

  @override
  String leadMinutes(int count) {
    return '$count min';
  }

  @override
  String useGateVip(String gate) {
    return 'Use Gate $gate, the VIP fast lane. The lounge opens with the gates.';
  }

  @override
  String useGateStand(String gate, String stand) {
    return 'Use Gate $gate, the entrance for the $stand.';
  }

  @override
  String get ticketNotFound => 'Ticket not found';

  @override
  String get ticketNotFoundBody =>
      'Tickets are kept on this device for the session. Book again from the map.';

  @override
  String scanAt(String gate) {
    return 'Scan at $gate';
  }

  @override
  String ticketSemantics(String id) {
    return 'Ticket $id';
  }

  @override
  String get entryQr => 'Entry QR code';

  @override
  String get matchdayAt => 'Matchday at';

  @override
  String get skip => 'Skip';
}
