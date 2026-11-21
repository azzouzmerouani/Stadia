/// Route paths, kept apart from the router so features can import them
/// without pulling in every screen.
abstract final class Routes {
  static const splash = '/';
  static const intro = '/intro';
  static const map = '/map';
  static String seats(String matchId) => '/match/$matchId/seats';
  static String ticket(String ticketId) => '/ticket/$ticketId';
}
