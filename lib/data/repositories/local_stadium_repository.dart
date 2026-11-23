import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../models/availability.dart';
import '../models/match.dart';
import '../models/stadium.dart';
import '../models/ticket.dart';
import '../payment/payment_service.dart';
import 'stadium_repository.dart';

/// Mock backend: reads `assets/data/*.json`, generates a deterministic
/// sold/free pattern per match and keeps bookings in memory.
///
/// Display text in the JSON is either a plain string or a translation map
/// (`{"en": "MC Oran", "ar": "مولودية وهران"}`); the repository returns it in
/// [languageCode], as a real API would for the request's Accept-Language.
class LocalStadiumRepository implements StadiumRepository {
  LocalStadiumRepository({
    AssetBundle? bundle,
    this.stadiumIds = defaultStadiumIds,
    this.stadiumsDir = 'assets/data/stadiums',
    this.matchesAsset = 'assets/data/matches.json',
    this.latency = const Duration(milliseconds: 250),
    this.languageCode = 'en',
  }) : _bundle = bundle ?? rootBundle;

  /// Miloud Hadefi (Oran) first: the default stadium.
  static const defaultStadiumIds = ['miloud-hadefi', '8-mai-1945'];

  final AssetBundle _bundle;

  /// Each stadium is `<stadiumsDir>/<id>.json`; its 3D model is
  /// `assets/3d/<id>.glb`.
  final List<String> stadiumIds;
  final String stadiumsDir;
  final String matchesAsset;

  /// Language of names, cities, competitions… (`ar` in the app).
  final String languageCode;

  /// Simulated network latency so loading states are exercised.
  final Duration latency;

  final Map<String, Stadium> _stadiums = {};
  List<Team>? _teams;
  List<FootballMatch>? _matches;
  final Map<String, MatchAvailability> _availability = {};

  @override
  Future<List<Stadium>> fetchStadiums() async => [
    for (final id in stadiumIds) await fetchStadium(id),
  ];

  @override
  Future<Stadium> fetchStadium([String? id]) async {
    final key = id ?? stadiumIds.first;
    final cached = _stadiums[key];
    if (cached != null) return cached;
    if (!stadiumIds.contains(key)) throw ArgumentError.value(id, 'id');
    final raw = jsonDecode(await _bundle.loadString('$stadiumsDir/$key.json'));
    return _stadiums[key] = parseStadium(
      raw as Map<String, dynamic>,
      language: languageCode,
    );
  }

  @override
  Future<List<Team>> fetchTeams() async {
    await _loadMatches();
    return List.unmodifiable(_teams!);
  }

  @override
  Future<List<FootballMatch>> fetchUpcomingMatches() async {
    await Future<void>.delayed(latency);
    return List.unmodifiable(await _loadMatches());
  }

  @override
  Future<FootballMatch> fetchMatch(String matchId) async {
    final matches = await _loadMatches();
    return matches.firstWhere(
      (m) => m.id == matchId,
      orElse: () => throw ArgumentError.value(matchId, 'matchId'),
    );
  }

  @override
  Future<MatchAvailability> fetchAvailability(String matchId) async {
    await Future<void>.delayed(latency);
    final cached = _availability[matchId];
    if (cached != null) return cached;
    final match = await fetchMatch(matchId);
    final stadium = await fetchStadium(match.stadiumId);
    return _availability[matchId] = generateAvailability(stadium, match);
  }

  @override
  Future<Ticket> issueTicket({
    required FootballMatch match,
    required SeatRef seat,
    required bool vip,
    required PaymentReceipt receipt,
  }) async {
    final stadium = await fetchStadium(match.stadiumId);
    final availability = await fetchAvailability(match.id);
    final block = stadium.blockById(seat.blockId);
    if (block == null || !availability.isSeatFree(block, seat)) {
      throw SeatUnavailableException(seat);
    }
    _availability[match.id] = availability.withSeatSold(block, seat);

    final stand = stadium.standById(block.standId)!;
    final gate =
        stadium.gateById(vip ? 'E' : stand.gateId) ??
        stadium.gateById(stand.gateId)!;
    final id =
        'STD-${receipt.paidAt.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    return Ticket(
      id: id,
      match: match,
      stadiumName: stadium.name,
      standName: stand.name,
      blockNumber: block.number,
      seat: seat,
      gate: gate,
      price: match.priceFor(block),
      vip: vip,
      vipPrice: stadium.vipUpgradePrice,
      gatesOpenAt: match.gatesOpenAt(stadium),
      issuedAt: receipt.paidAt,
      paymentReference: receipt.reference,
      // Mock payload. In production the backend signs this (see README).
      qrPayload: 'STADIA:1:$id:${match.id}:${seat.id}:${gate.id}',
    );
  }

  Future<List<FootballMatch>> _loadMatches() async {
    if (_matches != null) return _matches!;
    final raw =
        jsonDecode(await _bundle.loadString(matchesAsset))
            as Map<String, dynamic>;
    _teams = parseTeams(raw, language: languageCode);
    return _matches = parseMatches(raw, language: languageCode);
  }

  // ---------------------------------------------------------------- parsing

  /// A display string: plain, or `{"en": …, "ar": …}` resolved to
  /// [language] (falling back to English, then to any translation).
  static String text(Object? value, String language) => switch (value) {
    final String s => s,
    final Map<String, dynamic> m =>
      (m[language] ?? m['en'] ?? m.values.first) as String,
    _ => throw FormatException('Expected text, got $value'),
  };

  static Stadium parseStadium(
    Map<String, dynamic> json, {
    String language = 'en',
  }) {
    String t(Object? v) => text(v, language);
    final layout = json['layout'] as Map<String, dynamic>;
    final seatsPerRow = layout['seatsPerRow'] as int;
    final tiers = [
      for (final t in layout['tiers'] as List)
        Tier(
          tier: t['tier'] as int,
          rows: t['rows'] as int,
          rise: (t['rise'] as num).toDouble(),
        ),
    ];
    final location = json['location'] as Map<String, dynamic>;
    final centre = GeoPoint(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );

    final stands = <Stand>[];
    for (final s in json['stands'] as List) {
      final id = s['id'] as String;
      final prices = (s['prices'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as int),
      );
      final perTier = s['blocksPerTier'] as int;
      stands.add(
        Stand(
          id: id,
          name: t(s['name']),
          nickname: t(s['nickname']),
          gateId: s['gate'] as String,
          hasVip: s['vip'] as bool? ?? false,
          blocks: [
            for (final tier in tiers)
              for (var i = 1; i <= perTier; i++)
                Block(
                  standId: id,
                  number: tier.tier * 100 + i,
                  tier: tier.tier,
                  rows: tier.rows,
                  seatsPerRow: seatsPerRow,
                  basePrice: prices[tier.tier]!,
                ),
          ],
        ),
      );
    }

    return Stadium(
      id: json['id'] as String,
      name: t(json['name']),
      city: t(json['city']),
      location: centre,
      stands: stands,
      tiers: tiers,
      seatsPerRow: seatsPerRow,
      vipUpgradePrice: json['vipUpgradePrice'] as int,
      gatesOpenMinutesBefore: json['gatesOpenMinutesBefore'] as int,
      gates: [
        for (final g in json['gates'] as List)
          Gate(
            id: g['id'] as String,
            name: t(g['name']),
            position: centre.offsetMetres(
              north: (g['north'] as num).toDouble(),
              east: (g['east'] as num).toDouble(),
            ),
          ),
      ],
    );
  }

  static List<Team> parseTeams(
    Map<String, dynamic> json, {
    String language = 'en',
  }) {
    String t(Object? v) => text(v, language);
    return [
      for (final team in json['teams'] as List)
        Team(
          id: team['id'] as String,
          name: t(team['name']),
          shortName: team['short'] as String,
          city: t(team['city']),
          primaryColor: _parseHex(team['primary'] as String),
          secondaryColor: _parseHex(team['secondary'] as String),
          logo: team['logo'] as String?,
          homeStadiumId: team['stadium'] as String?,
        ),
    ];
  }

  static List<FootballMatch> parseMatches(
    Map<String, dynamic> json, {
    String language = 'en',
  }) {
    String t(Object? v) => text(v, language);
    final teams = {
      for (final team in parseTeams(json, language: language)) team.id: team,
    };
    final matches = [
      for (final m in json['matches'] as List)
        FootballMatch(
          id: m['id'] as String,
          stadiumId: m['stadium'] as String,
          home: teams[m['home']]!,
          away: teams[m['away']]!,
          kickoff: DateTime.parse(m['kickoff'] as String),
          competition: t(m['competition']),
          round: t(m['round']),
          priceMultiplier: (m['priceMultiplier'] as num).toDouble(),
          demand: (m['demand'] as num).toDouble(),
        ),
    ]..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    return matches;
  }

  static int _parseHex(String hex) =>
      int.parse('FF${hex.replaceFirst('#', '')}', radix: 16);

  // ----------------------------------------------------------- availability

  /// Deterministic per match so the same seats are always sold. Curves
  /// mimic real demand: behind-the-goal stands and the lower tier fill
  /// first, sold seats cluster in groups, a few blocks sell out.
  static MatchAvailability generateAvailability(
    Stadium stadium,
    FootballMatch match,
  ) {
    final blocks = <String, BlockAvailability>{};
    for (final stand in stadium.stands) {
      final standBias = switch (stand.id) {
        'N' || 'S' => 0.14,
        'W' => -0.04,
        _ => 0.0,
      };
      for (final block in stand.blocks) {
        final rnd = math.Random(_seed('${match.id}/${block.id}'));
        final tierBias = block.tier == 1 ? 0.08 : -0.1;
        var fill =
            (match.demand +
                    standBias +
                    tierBias +
                    (rnd.nextDouble() - 0.5) * 0.3)
                .clamp(0.05, 1.0);
        // Occasionally a block is completely gone.
        if (match.demand > 0.6 && rnd.nextDouble() < 0.12) fill = 1.0;

        final sold = <int>{};
        final phase = rnd.nextDouble() * math.pi * 2;
        for (var row = 1; row <= block.rows; row++) {
          for (var seat = 1; seat <= block.seatsPerRow; seat++) {
            final wave = 0.22 * math.sin(row * 0.55 + seat * 0.35 + phase);
            if (fill >= 1.0 || rnd.nextDouble() < fill + wave) {
              sold.add(block.seatIndex(row, seat));
            }
          }
        }
        blocks[block.id] = BlockAvailability(
          blockId: block.id,
          capacity: block.capacity,
          sold: sold,
        );
      }
    }
    return MatchAvailability(matchId: match.id, blocks: blocks);
  }

  /// Stable string hash (FNV-1a) – `String.hashCode` is not stable across runs.
  static int _seed(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }
}
