import 'stadium.dart';

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
    required this.primaryColor,
    required this.secondaryColor,
    this.logo,
    this.homeStadiumId,
  });

  final String id;
  final String name;
  final String shortName;
  final String city;

  /// The club's home ground when the app sells tickets for it.
  final String? homeStadiumId;

  /// ARGB colours; converted to `Color` in the UI layer.
  final int primaryColor;
  final int secondaryColor;

  /// Crest image (an asset path in the mock data, a CDN URL in production).
  /// Null: the UI draws a shield in the club colours.
  final String? logo;
}

/// Named `FootballMatch` to avoid clashing with `dart:core`'s `Match`.
class FootballMatch {
  const FootballMatch({
    required this.id,
    required this.stadiumId,
    required this.home,
    required this.away,
    required this.kickoff,
    required this.competition,
    required this.round,
    required this.priceMultiplier,
    required this.demand,
  });

  final String id;
  final String stadiumId;
  final Team home;
  final Team away;

  /// Stadium wall-clock time (Algeria, UTC+1). Stored without an offset so it
  /// displays the same everywhere.
  final DateTime kickoff;
  final String competition;
  final String round;
  final double priceMultiplier;

  /// 0..1 – how full the mock repository makes the stadium.
  final double demand;

  bool involves(String teamId) => home.id == teamId || away.id == teamId;

  /// Ticket price for a block, rounded to the nearest 50 DA.
  int priceFor(Block block) => _round50(block.basePrice * priceMultiplier);

  int fromPrice(Stadium stadium) =>
      stadium.blocks.map(priceFor).reduce((a, b) => a < b ? a : b);

  DateTime gatesOpenAt(Stadium stadium) =>
      kickoff.subtract(Duration(minutes: stadium.gatesOpenMinutesBefore));

  static int _round50(double value) => ((value / 50).round() * 50);
}
