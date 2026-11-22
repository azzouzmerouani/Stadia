import 'package:flutter/foundation.dart';

import '../../data/models/availability.dart';
import '../../data/models/match.dart';
import '../../data/models/stadium.dart';

/// The four steps shown in the progress bar (labels live in the l10n
/// files: stepStand … stepBuy).
enum BookingStep { stand, block, seat, buy }

/// Why the last event was rejected (shown as a hint, never blocks the UI).
enum BookingNotice { standSoldOut, blockSoldOut, seatTaken }

@immutable
class BookingState {
  const BookingState({
    this.step = BookingStep.stand,
    this.standId,
    this.blockId,
    this.seat,
    this.vip = false,
    this.notice,
  });

  final BookingStep step;
  final String? standId;
  final String? blockId;
  final SeatRef? seat;
  final bool vip;
  final BookingNotice? notice;

  BookingState _with({
    BookingStep? step,
    String? Function()? standId,
    String? Function()? blockId,
    SeatRef? Function()? seat,
    bool? vip,
    BookingNotice? notice,
  }) => BookingState(
    step: step ?? this.step,
    standId: standId != null ? standId() : this.standId,
    blockId: blockId != null ? blockId() : this.blockId,
    seat: seat != null ? seat() : this.seat,
    vip: vip ?? this.vip,
    notice: notice,
  );

  @override
  bool operator ==(Object other) =>
      other is BookingState &&
      other.step == step &&
      other.standId == standId &&
      other.blockId == blockId &&
      other.seat == seat &&
      other.vip == vip &&
      other.notice == notice;

  @override
  int get hashCode => Object.hash(step, standId, blockId, seat, vip, notice);

  @override
  String toString() =>
      'BookingState(${step.name}, stand: $standId, block: $blockId, '
      'seat: $seat, vip: $vip, notice: $notice)';
}

sealed class BookingEvent {
  const BookingEvent();
}

/// A stand was tapped in the 3D view.
class StandTapped extends BookingEvent {
  const StandTapped(this.standId);
  final String standId;
}

class BlockTapped extends BookingEvent {
  const BlockTapped(this.blockId);
  final String blockId;
}

class SeatTapped extends BookingEvent {
  const SeatTapped(this.seat);
  final SeatRef seat;
}

/// Hardware back / back button: go up one level.
class StepBack extends BookingEvent {
  const StepBack();
}

/// A completed step was tapped in the progress bar.
class StepTapped extends BookingEvent {
  const StepTapped(this.step);
  final BookingStep step;
}

/// "Another seat" in the seat sheet.
class AnotherSeat extends BookingEvent {
  const AnotherSeat();
}

class VipToggled extends BookingEvent {
  const VipToggled(this.vip);
  final bool vip;
}

/// Pure, synchronous state machine: Stand -> Block -> Seat -> Buy.
///
/// Invalid events return the same selection (optionally with a [BookingNotice])
/// rather than throwing, because they come from user taps.
class BookingMachine {
  const BookingMachine({required this.stadium, required this.availability});

  final Stadium stadium;
  final MatchAvailability availability;

  BookingState reduce(BookingState s, BookingEvent event) {
    final cleared = s.notice == null ? s : s._with();
    return switch (event) {
      StandTapped(:final standId) => _stand(cleared, standId),
      BlockTapped(:final blockId) => _block(cleared, blockId),
      SeatTapped(:final seat) => _seat(cleared, seat),
      StepBack() => _back(cleared),
      AnotherSeat() => s.step == BookingStep.buy ? _back(cleared) : cleared,
      StepTapped(:final step) => _jumpTo(cleared, step),
      VipToggled(:final vip) =>
        s.step == BookingStep.buy ? cleared._with(vip: vip) : cleared,
    };
  }

  BookingState _stand(BookingState s, String standId) {
    if (s.step != BookingStep.stand && s.step != BookingStep.block) return s;
    final stand = stadium.standById(Stadium.stripMeshPrefix(standId));
    if (stand == null) return s;
    if (availability.freeInStand(stand) == 0) {
      return s._with(notice: BookingNotice.standSoldOut);
    }
    return BookingState(step: BookingStep.block, standId: stand.id);
  }

  BookingState _block(BookingState s, String blockId) {
    if (s.step != BookingStep.block && s.step != BookingStep.seat) return s;
    final block = stadium.blockById(Stadium.stripMeshPrefix(blockId));
    if (block == null || block.standId != s.standId) return s;
    if (availability.block(block.id)?.isSoldOut ?? true) {
      return s._with(notice: BookingNotice.blockSoldOut);
    }
    return BookingState(
      step: BookingStep.seat,
      standId: s.standId,
      blockId: block.id,
    );
  }

  BookingState _seat(BookingState s, SeatRef seat) {
    if (s.step != BookingStep.seat || seat.blockId != s.blockId) return s;
    final block = stadium.blockById(seat.blockId);
    if (block == null) return s;
    if (!availability.isSeatFree(block, seat)) {
      return s._with(notice: BookingNotice.seatTaken);
    }
    return s._with(step: BookingStep.buy, seat: () => seat, vip: false);
  }

  BookingState _back(BookingState s) => switch (s.step) {
    BookingStep.buy => s._with(
      step: BookingStep.seat,
      seat: () => null,
      vip: false,
    ),
    BookingStep.seat => BookingState(
      step: BookingStep.block,
      standId: s.standId,
    ),
    BookingStep.block => const BookingState(),
    BookingStep.stand => s,
  };

  BookingState _jumpTo(BookingState s, BookingStep target) {
    var next = s;
    while (next.step.index > target.index) {
      next = _back(next);
    }
    return next;
  }

  // ------------------------------------------------------------ read model

  /// What the floating card describes: the most specific selection. The
  /// UI words it ("Block 104", "القسم 104") from these fields.
  SelectionSummary? summarize(BookingState s, FootballMatch match) {
    if (s.seat case final seat?) {
      final block = stadium.blockById(seat.blockId)!;
      final stand = stadium.standById(block.standId)!;
      return SelectionSummary(
        level: SelectionLevel.seat,
        stand: stand,
        block: block,
        seat: seat,
        free: 1,
        capacity: 1,
        price: match.priceFor(block),
      );
    }
    if (s.blockId case final blockId?) {
      final block = stadium.blockById(blockId)!;
      final stand = stadium.standById(block.standId)!;
      return SelectionSummary(
        level: SelectionLevel.block,
        stand: stand,
        block: block,
        free: availability.freeInBlock(block.id),
        capacity: block.capacity,
        price: match.priceFor(block),
      );
    }
    if (s.standId case final standId?) {
      final stand = stadium.standById(standId)!;
      final open = stand.blocks.where(
        (b) => availability.freeInBlock(b.id) > 0,
      );
      final prices = (open.isEmpty ? stand.blocks : open).map(match.priceFor);
      return SelectionSummary(
        level: SelectionLevel.stand,
        stand: stand,
        free: availability.freeInStand(stand),
        capacity: stand.capacity,
        price: prices.reduce((a, b) => a < b ? a : b),
        priceIsFrom: true,
      );
    }
    return null;
  }
}

enum SelectionLevel { stand, block, seat }

@immutable
class SelectionSummary {
  const SelectionSummary({
    required this.level,
    required this.stand,
    this.block,
    this.seat,
    required this.free,
    required this.capacity,
    required this.price,
    this.priceIsFrom = false,
  });

  final SelectionLevel level;
  final Stand stand;

  /// Set from the block level down.
  final Block? block;

  /// Set at the seat level.
  final SeatRef? seat;
  final int free;
  final int capacity;
  final int price;
  final bool priceIsFrom;

  double get freeRatio => capacity == 0 ? 0 : free / capacity;
}
