import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/availability.dart';
import '../../data/models/match.dart';
import '../../data/models/stadium.dart';
import '../../data/providers.dart';
import 'booking_machine.dart';

/// Everything the seat picker needs, loaded together.
class BookingContext {
  const BookingContext({
    required this.stadium,
    required this.match,
    required this.availability,
  });

  final Stadium stadium;
  final FootballMatch match;
  final MatchAvailability availability;

  BookingMachine get machine =>
      BookingMachine(stadium: stadium, availability: availability);
}

final bookingContextProvider = FutureProvider.autoDispose
    .family<BookingContext, String>((ref, matchId) async {
      final match = await ref.watch(matchProvider(matchId).future);
      final results = await Future.wait([
        // The stadium the match is played at, whichever one the map shows.
        ref.watch(stadiumByIdProvider(match.stadiumId).future),
        ref.watch(availabilityProvider(matchId).future),
      ]);
      return BookingContext(
        stadium: results[0] as Stadium,
        match: match,
        availability: results[1] as MatchAvailability,
      );
    });

/// Holds the booking selection for one match and feeds events through the
/// pure [BookingMachine].
class BookingController extends Notifier<BookingState> {
  BookingController(this.matchId);

  final String matchId;

  @override
  BookingState build() => const BookingState();

  BookingContext? get _context =>
      ref.read(bookingContextProvider(matchId)).value;

  void dispatch(BookingEvent event) {
    final context = _context;
    if (context == null) return;
    state = context.machine.reduce(state, event);
  }

  SelectionSummary? get summary {
    final context = _context;
    if (context == null) return null;
    return context.machine.summarize(state, context.match);
  }
}

final bookingControllerProvider = NotifierProvider.autoDispose
    .family<BookingController, BookingState, String>(BookingController.new);
