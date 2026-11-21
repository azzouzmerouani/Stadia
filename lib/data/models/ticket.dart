import 'match.dart';
import 'stadium.dart';

class Ticket {
  const Ticket({
    required this.id,
    required this.match,
    required this.stadiumName,
    required this.standName,
    required this.blockNumber,
    required this.seat,
    required this.gate,
    required this.price,
    required this.vip,
    required this.vipPrice,
    required this.gatesOpenAt,
    required this.issuedAt,
    required this.paymentReference,
    required this.qrPayload,
  });

  final String id;
  final FootballMatch match;
  final String stadiumName;
  final String standName;
  final int blockNumber;
  final SeatRef seat;
  final Gate gate;
  final int price;
  final bool vip;
  final int vipPrice;
  final DateTime gatesOpenAt;
  final DateTime issuedAt;
  final String paymentReference;

  /// What the QR code encodes. Mock: not signed by a server yet.
  final String qrPayload;

  int get total => price + (vip ? vipPrice : 0);
}
