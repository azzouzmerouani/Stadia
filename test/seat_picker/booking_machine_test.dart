import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/models/availability.dart';
import 'package:stadia/data/models/match.dart';
import 'package:stadia/data/models/stadium.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/seat_picker/booking_machine.dart';

MatchAvailability availabilityFor(
  Stadium stadium, {
  Set<String> soldOutBlocks = const {},
  Map<String, Set<int>> sold = const {},
}) =>
    MatchAvailability(
      matchId: 'test',
      blocks: {
        for (final b in stadium.blocks)
          b.id: BlockAvailability(
            blockId: b.id,
            capacity: b.capacity,
            sold: soldOutBlocks.contains(b.id)
                ? {for (var i = 0; i < b.capacity; i++) i}
                : (sold[b.id] ?? const {}),
          ),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Stadium stadium;
  late FootballMatch match;
  late BookingMachine machine;

  setUpAll(() async {
    final repo = LocalStadiumRepository(latency: Duration.zero);
    stadium = await repo.fetchStadium();
    match = (await repo.fetchUpcomingMatches()).first;
  });

  setUp(() {
    machine = BookingMachine(
      stadium: stadium,
      availability: availabilityFor(
        stadium,
        soldOutBlocks: {'E_101'},
        sold: {
          'E_104': {0, 1, 2},
        },
      ),
    );
  });

  BookingState run(List<BookingEvent> events, [BookingState? from]) =>
      events.fold(from ?? const BookingState(), machine.reduce);

  group('forward flow', () {
    test('starts at the stand step with nothing selected', () {
      const s = BookingState();
      expect(s.step, BookingStep.stand);
      expect(machine.summarize(s, match), isNull);
    });

    test('stand -> block -> seat -> buy', () {
      var s = run([const StandTapped('E')]);
      expect(s.step, BookingStep.block);
      expect(s.standId, 'E');

      s = machine.reduce(s, const BlockTapped('E_104'));
      expect(s.step, BookingStep.seat);
      expect(s.blockId, 'E_104');

      const seat = SeatRef(blockId: 'E_104', row: 12, seat: 7);
      s = machine.reduce(s, const SeatTapped(seat));
      expect(s.step, BookingStep.buy);
      expect(s.seat, seat);
    });

    test('accepts 3D mesh names as ids', () {
      final s =
          run([const StandTapped('Stand_W'), const BlockTapped('Block_W_203')]);
      expect(s.standId, 'W');
      expect(s.blockId, 'W_203');
    });

    test('can switch stand while choosing a block', () {
      final s = run([const StandTapped('E'), const StandTapped('N')]);
      expect(s.step, BookingStep.block);
      expect(s.standId, 'N');
    });

    test('can switch block of the same stand while choosing a seat', () {
      final s = run([
        const StandTapped('E'),
        const BlockTapped('E_104'),
        const BlockTapped('E_205'),
      ]);
      expect(s.step, BookingStep.seat);
      expect(s.blockId, 'E_205');
    });
  });

  group('guards', () {
    test('unknown stand is ignored', () {
      expect(run([const StandTapped('X')]), const BookingState());
    });

    test('block from another stand is ignored', () {
      final s = run([const StandTapped('E'), const BlockTapped('N_101')]);
      expect(s.step, BookingStep.block);
      expect(s.blockId, isNull);
    });

    test('sold-out block raises a notice and keeps the step', () {
      final s = run([const StandTapped('E'), const BlockTapped('E_101')]);
      expect(s.step, BookingStep.block);
      expect(s.notice, BookingNotice.blockSoldOut);
    });

    test('sold-out stand raises a notice', () {
      final m = BookingMachine(
        stadium: stadium,
        availability: availabilityFor(
          stadium,
          soldOutBlocks: {for (final b in stadium.standById('S')!.blocks) b.id},
        ),
      );
      final s = m.reduce(const BookingState(), const StandTapped('S'));
      expect(s.step, BookingStep.stand);
      expect(s.notice, BookingNotice.standSoldOut);
    });

    test('taken seat raises a notice, other block seat is ignored', () {
      final inBlock = run([const StandTapped('E'), const BlockTapped('E_104')]);
      final taken = machine.reduce(
        inBlock,
        const SeatTapped(SeatRef(blockId: 'E_104', row: 1, seat: 2)),
      );
      expect(taken.step, BookingStep.seat);
      expect(taken.notice, BookingNotice.seatTaken);

      final elsewhere = machine.reduce(
        inBlock,
        const SeatTapped(SeatRef(blockId: 'E_105', row: 3, seat: 3)),
      );
      expect(elsewhere, inBlock);
    });

    test('seat outside the block grid is rejected', () {
      final inBlock = run([const StandTapped('E'), const BlockTapped('E_104')]);
      final s = machine.reduce(
        inBlock,
        const SeatTapped(SeatRef(blockId: 'E_104', row: 99, seat: 1)),
      );
      expect(s.step, BookingStep.seat);
      expect(s.notice, BookingNotice.seatTaken);
    });

    test('a notice is cleared by the next event', () {
      final s = run([
        const StandTapped('E'),
        const BlockTapped('E_101'),
        const BlockTapped('E_102'),
      ]);
      expect(s.notice, isNull);
      expect(s.blockId, 'E_102');
    });

    test('stand taps are ignored once a block is chosen', () {
      final inBlock = run([const StandTapped('E'), const BlockTapped('E_104')]);
      expect(machine.reduce(inBlock, const StandTapped('N')), inBlock);
    });
  });

  group('going back', () {
    final toBuy = [
      const StandTapped('E'),
      const BlockTapped('E_104'),
      const SeatTapped(SeatRef(blockId: 'E_104', row: 12, seat: 7)),
    ];

    test('StepBack walks buy -> seat -> block -> stand', () {
      var s = run(toBuy);
      s = machine.reduce(s, const StepBack());
      expect((s.step, s.seat, s.blockId), (BookingStep.seat, null, 'E_104'));
      s = machine.reduce(s, const StepBack());
      expect((s.step, s.blockId, s.standId), (BookingStep.block, null, 'E'));
      s = machine.reduce(s, const StepBack());
      expect(s, const BookingState());
      expect(machine.reduce(s, const StepBack()), s);
    });

    test('Another seat clears the seat and the VIP upgrade', () {
      var s = run([...toBuy, const VipToggled(true)]);
      expect(s.vip, isTrue);
      s = machine.reduce(s, const AnotherSeat());
      expect(s.step, BookingStep.seat);
      expect(s.seat, isNull);
      expect(s.vip, isFalse);
    });

    test('tapping a completed step jumps back; future steps do nothing', () {
      final s = run(toBuy);
      expect(
        machine.reduce(s, const StepTapped(BookingStep.block)).step,
        BookingStep.block,
      );
      expect(
        machine.reduce(s, const StepTapped(BookingStep.stand)),
        const BookingState(),
      );
      final early = run([const StandTapped('E')]);
      expect(machine.reduce(early, const StepTapped(BookingStep.buy)), early);
    });

    test('VIP can only be toggled at the buy step', () {
      final s = run([const StandTapped('E'), const VipToggled(true)]);
      expect(s.vip, isFalse);
    });
  });

  group('summary for the floating card', () {
    test('stand shows free seats and the cheapest open price', () {
      final s = run([const StandTapped('E')]);
      final summary = machine.summarize(s, match)!;
      expect(summary.level, SelectionLevel.stand);
      expect(summary.title, 'East Stand');
      final stand = stadium.standById('E')!;
      expect(summary.free, stand.capacity - 720 - 3);
      expect(summary.price, match.priceFor(stadium.blockById('E_201')!));
      expect(summary.priceIsFrom, isTrue);
    });

    test('block and seat show exact price', () {
      final block = run([const StandTapped('E'), const BlockTapped('E_104')]);
      final b = machine.summarize(block, match)!;
      expect(b.title, 'Block 104');
      expect(b.free, 720 - 3);
      expect(b.price, match.priceFor(stadium.blockById('E_104')!));

      final seat = machine.reduce(
        block,
        const SeatTapped(SeatRef(blockId: 'E_104', row: 12, seat: 7)),
      );
      expect(machine.summarize(seat, match)!.title, 'Row 12 · Seat 7');
    });
  });
}
