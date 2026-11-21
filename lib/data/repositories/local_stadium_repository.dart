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
class LocalStadiumRepository implements StadiumRepository {
  LocalStadiumRepository({
    AssetBundle? bundle,
    this.stadiumAsset = 'assets/data/stadium.json',
    this.matchesAsset = 'assets/data/matches.json',
    this.latency = const Duration(milliseconds: 250),
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String stadiumAsset;
  final String matchesAsset;

  /// Simulated network latency so loading states are exercised.
  final Duration latency;

  Stadium? _stadium;
  List<FootballMatch>? _matches;
  final Map<String, MatchAvailability> _availability = {};

  @override
  Future<Stadium> fetchStadium() async {
    if (_stadium != null) return _stadium!;
    final raw = jsonDecode(await _bundle.loadString(stadiumAsset));
    return _stadium = parseStadium(raw as Map<String, dynamic>);
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
    final stadium = await fetchStadium();
    final match = await fetchMatch(matchId);
    return _availability[matchId] = generateAvailability(stadium, match);
  }

  @override
  Future<Ticket> issueTicket({
    required FootballMatch match,
    required SeatRef seat,
    required bool vip,
    required PaymentReceipt receipt,
  }) async {
    final stadium = await fetchStadium();
    final availability = await fetchAvailability(match.id);
    final block = stadium.blockById(seat.blockId);
    if (block == null || !availability.isSeatFree(block, seat)) {
      throw SeatUnavailableException(seat);
    }
    _availability[match.id] = availability.withSeatSold(block, seat);

    final stand = stadium.standById(block.standId)!;
    final gate = stadium.gateById(vip ? 'E' : stand.gateId) ??
        stadium.gateById(stand.gateId)!;
    final id = 'STD-${receipt.paidAt.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
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
    final raw = jsonDecode(await _bundle.loadString(matchesAsset));
    return _matches = parseMatches(raw as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------- parsing

  static Stadium parseStadium(Map<String, dynamic> json) {
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
      final prices = (s['prices'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as int));
      final perTier = s['blocksPerTier'] as int;
      stands.add(
        Stand(
          id: id,
          name: s['name'] as String,
          nickname: s['nickname'] as String,
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
      name: json['name'] as String,
      city: json['city'] as String,
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
            name: g['name'] as String,
            position: centre.offsetMetres(
              north: (g['north'] as num).toDouble(),
              east: (g['east'] as num).toDouble(),
            ),
          ),
      ],
    );
  }

  static List<FootballMatch> parseMatches(Map<String, dynamic> json) {
    final teams = {
      for (final t in json['teams'] as List)
        t['id'] as String: Team(
          id: t['id'] as String,
          name: t['name'] as String,
          shortName: t['short'] as String,
          city: t['city'] as String,
          primaryColor: _parseHex(t['primary'] as String),
          secondaryColor: _parseHex(t['secondary'] as String),
        ),
    };
    final matches = [
      for (final m in json['matches'] as List)
        FootballMatch(
          id: m['id'] as String,
          stadiumId: m['stadium'] as String,
          home: teams[m['home']]!,
          away: teams[m['away']]!,
          kickoff: DateTime.parse(m['kickoff'] as String),
          competition: m['competition'] as String,
          round: m['round'] as String,
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
            (match.demand + standBias + tierBias + (rnd.nextDouble() - 0.5) * 0.3)
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
