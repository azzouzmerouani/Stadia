import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/availability.dart';
import 'models/match.dart';
import 'models/stadium.dart';
import 'models/ticket.dart';
import 'payment/payment_service.dart';
import 'repositories/local_stadium_repository.dart';
import 'repositories/stadium_repository.dart';

/// Swap this override for a Supabase implementation later.
final stadiumRepositoryProvider = Provider<StadiumRepository>(
  (ref) => LocalStadiumRepository(),
);

/// Swap for `ChargilyPaymentService` once the backend exists.
final paymentServiceProvider = Provider<PaymentService>(
  (ref) => MockPaymentService(),
);

final stadiumProvider = FutureProvider<Stadium>(
  (ref) => ref.watch(stadiumRepositoryProvider).fetchStadium(),
);

final upcomingMatchesProvider = FutureProvider<List<FootballMatch>>(
  (ref) => ref.watch(stadiumRepositoryProvider).fetchUpcomingMatches(),
);

final matchProvider = FutureProvider.family<FootballMatch, String>(
  (ref, id) => ref.watch(stadiumRepositoryProvider).fetchMatch(id),
);

final availabilityProvider = FutureProvider.family<MatchAvailability, String>(
  (ref, id) => ref.watch(stadiumRepositoryProvider).fetchAvailability(id),
);

/// Tickets bought in this session (in memory).
class TicketWallet extends Notifier<List<Ticket>> {
  @override
  List<Ticket> build() => const [];

  void add(Ticket ticket) => state = [...state, ticket];

  Ticket? byId(String id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }
}

final ticketWalletProvider =
    NotifierProvider<TicketWallet, List<Ticket>>(TicketWallet.new);
