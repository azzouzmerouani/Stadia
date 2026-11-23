import 'dart:math' as math;

/// Plain geographic point so the data layer stays free of map packages.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Returns the point moved by [north] / [east] metres (flat-earth
  /// approximation, fine at stadium scale).
  GeoPoint offsetMetres({double north = 0, double east = 0}) {
    const metresPerDegree = 111320.0;
    final dLat = north / metresPerDegree;
    final dLng = east / (metresPerDegree * math.cos(lat * math.pi / 180));
    return GeoPoint(lat + dLat, lng + dLng);
  }
}

class Gate {
  const Gate({required this.id, required this.name, required this.position});

  final String id;
  final String name;
  final GeoPoint position;
}

/// One tier of seating ("1" = lower bowl, "2" = upper bowl).
class Tier {
  const Tier({required this.tier, required this.rows, required this.rise});

  final int tier;
  final int rows;

  /// Height gained per row, in metres. Only used by the 3D generator.
  final double rise;
}

/// A selectable block of seats. Its 3D mesh is named `Block_<stand>_<number>`
/// (e.g. `Block_N_101`); the seats inside are `Seats_<stand>_<number>`.
class Block {
  const Block({
    required this.standId,
    required this.number,
    required this.tier,
    required this.rows,
    required this.seatsPerRow,
    required this.basePrice,
  });

  final String standId;
  final int number;
  final int tier;
  final int rows;
  final int seatsPerRow;

  /// Face value in DZD before any match multiplier.
  final int basePrice;

  String get id => '${standId}_$number';
  String get meshName => 'Block_$id';
  String get seatsMeshName => 'Seats_$id';
  int get capacity => rows * seatsPerRow;

  /// 0-based index of a seat inside this block, row-major from the front row.
  int seatIndex(int row, int seat) => (row - 1) * seatsPerRow + (seat - 1);

  SeatRef seatAt(int index) => SeatRef(
    blockId: id,
    row: index ~/ seatsPerRow + 1,
    seat: index % seatsPerRow + 1,
  );
}

class Stand {
  const Stand({
    required this.id,
    required this.name,
    required this.nickname,
    required this.gateId,
    required this.blocks,
    this.hasVip = false,
  });

  final String id;
  final String name;
  final String nickname;
  final String gateId;
  final List<Block> blocks;
  final bool hasVip;

  String get meshName => 'Stand_$id';
  int get capacity => blocks.fold(0, (sum, b) => sum + b.capacity);
  int get minBasePrice => blocks.map((b) => b.basePrice).reduce(math.min);

  /// False for a single-tier bowl (8 Mai 1945), where "lower tier" means
  /// nothing.
  bool get hasUpperTier => blocks.any((b) => b.tier > 1);
}

class Stadium {
  const Stadium({
    required this.id,
    required this.name,
    required this.city,
    required this.location,
    required this.stands,
    required this.gates,
    required this.tiers,
    required this.seatsPerRow,
    required this.vipUpgradePrice,
    required this.gatesOpenMinutesBefore,
  });

  final String id;
  final String name;
  final String city;
  final GeoPoint location;
  final List<Stand> stands;
  final List<Gate> gates;
  final List<Tier> tiers;
  final int seatsPerRow;
  final int vipUpgradePrice;
  final int gatesOpenMinutesBefore;

  int get capacity => stands.fold(0, (sum, s) => sum + s.capacity);

  Iterable<Block> get blocks => stands.expand((s) => s.blocks);

  Stand? standById(String id) {
    for (final s in stands) {
      if (s.id == id) return s;
    }
    return null;
  }

  Block? blockById(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  Gate? gateById(String id) {
    for (final g in gates) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Accepts either a domain id (`N`, `N_101`) or a mesh name
  /// (`Stand_N`, `Block_N_101`, `Seats_N_101`).
  static String stripMeshPrefix(String id) {
    for (final prefix in const ['Stand_', 'Block_', 'Seats_']) {
      if (id.startsWith(prefix)) return id.substring(prefix.length);
    }
    return id;
  }
}

/// Identifies one seat: `N_101_R12_S7`.
class SeatRef {
  const SeatRef({required this.blockId, required this.row, required this.seat});

  final String blockId;
  final int row;
  final int seat;

  String get id => '${blockId}_R${row}_S$seat';
  String get standId => blockId.split('_').first;

  static final _pattern = RegExp(r'^([A-Z]+_\d+)_R(\d+)_S(\d+)$');

  static SeatRef? tryParse(String id) {
    final m = _pattern.firstMatch(id);
    if (m == null) return null;
    return SeatRef(
      blockId: m.group(1)!,
      row: int.parse(m.group(2)!),
      seat: int.parse(m.group(3)!),
    );
  }

  @override
  bool operator ==(Object other) => other is SeatRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}
