import 'stadium.dart';

class BlockAvailability {
  const BlockAvailability({
    required this.blockId,
    required this.capacity,
    required this.sold,
  });

  final String blockId;
  final int capacity;

  /// 0-based seat indexes (see [Block.seatIndex]) that are already taken.
  final Set<int> sold;

  int get free => capacity - sold.length;
  double get freeRatio => capacity == 0 ? 0 : free / capacity;
  bool get isSoldOut => free <= 0;
  bool isSold(int index) => sold.contains(index);

  BlockAvailability withSold(int index) => BlockAvailability(
        blockId: blockId,
        capacity: capacity,
        sold: {...sold, index},
      );
}

/// Free / sold seats for one match.
class MatchAvailability {
  const MatchAvailability({required this.matchId, required this.blocks});

  final String matchId;
  final Map<String, BlockAvailability> blocks;

  BlockAvailability? block(String blockId) => blocks[blockId];

  int freeInBlock(String blockId) => blocks[blockId]?.free ?? 0;

  int freeInStand(Stand stand) =>
      stand.blocks.fold(0, (sum, b) => sum + freeInBlock(b.id));

  int get freeTotal => blocks.values.fold(0, (sum, b) => sum + b.free);

  bool isSeatFree(Block block, SeatRef seat) {
    final a = blocks[block.id];
    if (a == null) return false;
    if (seat.row < 1 || seat.row > block.rows) return false;
    if (seat.seat < 1 || seat.seat > block.seatsPerRow) return false;
    return !a.isSold(block.seatIndex(seat.row, seat.seat));
  }

  MatchAvailability withSeatSold(Block block, SeatRef seat) {
    final current = blocks[block.id];
    if (current == null) return this;
    return MatchAvailability(
      matchId: matchId,
      blocks: {
        ...blocks,
        block.id: current.withSold(block.seatIndex(seat.row, seat.seat)),
      },
    );
  }
}
