import '../models/availability.dart';
import '../models/match.dart';
import '../models/stadium.dart';
import '../models/ticket.dart';
import '../payment/payment_service.dart';

class SeatUnavailableException implements Exception {
  const SeatUnavailableException(this.seat);
  final SeatRef seat;

  @override
  String toString() => 'Seat ${seat.id} is no longer available';
}

/// Everything the UI needs from the backend. [LocalStadiumRepository] serves
/// bundled mock JSON; a `SupabaseStadiumRepository` can implement the same
/// interface later (see README for the table layout).
abstract interface class StadiumRepository {
  Future<Stadium> fetchStadium();

  Future<List<FootballMatch>> fetchUpcomingMatches();

  Future<FootballMatch> fetchMatch(String matchId);

  Future<MatchAvailability> fetchAvailability(String matchId);

  /// Reserves [seat] and returns the issued ticket. Throws
  /// [SeatUnavailableException] if someone else got there first.
  Future<Ticket> issueTicket({
    required FootballMatch match,
    required SeatRef seat,
    required bool vip,
    required PaymentReceipt receipt,
  });
}
