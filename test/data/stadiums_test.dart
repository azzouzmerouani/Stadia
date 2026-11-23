import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/data/favourite_team.dart';
import 'package:stadia/data/payment/payment_service.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/seat_picker/booking_words.dart';
import 'package:stadia/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStadiumRepository repo;

  setUp(() => repo = LocalStadiumRepository(latency: Duration.zero));

  test('two stadiums, Oran first; each has its 3D model', () async {
    final stadiums = await repo.fetchStadiums();
    expect(stadiums.map((s) => s.id), ['miloud-hadefi', '8-mai-1945']);
    expect((await repo.fetchStadium()).id, 'miloud-hadefi');
    for (final s in stadiums) {
      expect(File('assets/3d/${s.id}.glb').existsSync(), isTrue, reason: s.id);
    }
    expect(() => repo.fetchStadium('nowhere'), throwsArgumentError);
  });

  test('8 Mai 1945 is a ~25k single-tier bowl in Sétif', () async {
    final s = await repo.fetchStadium('8-mai-1945');
    expect(s.name, '8 May 1945 Stadium');
    expect(s.city, 'Sétif');
    expect(s.location.lat, closeTo(36.187, 0.001));
    expect(s.location.lng, closeTo(5.393, 0.001));
    expect(s.blocks.length, 23);
    expect(s.capacity, 24840);
    expect(s.tiers.length, 1);
    expect(s.stands.every((st) => !st.hasUpperTier), isTrue);
    expect(s.standById('W')!.hasVip, isTrue);
    expect(s.gates.map((g) => g.id), containsAll(['A', 'B', 'C', 'D', 'E']));
  });

  test('every match is at a known stadium and every club plays', () async {
    final ids = (await repo.fetchStadiums()).map((s) => s.id).toSet();
    final matches = await repo.fetchUpcomingMatches();
    for (final m in matches) {
      expect(ids, contains(m.stadiumId), reason: m.id);
    }
    for (final t in await repo.fetchTeams()) {
      expect(matches.any((m) => m.involves(t.id)), isTrue, reason: t.id);
    }
    expect(matches.where((m) => m.stadiumId == '8-mai-1945'), hasLength(5));
  });

  test('a Sétif ticket is priced, gated and seated in Sétif', () async {
    final match = await repo.fetchMatch('ess-crb-2026-11-28');
    final stadium = await repo.fetchStadium(match.stadiumId);
    final availability = await repo.fetchAvailability(match.id);
    expect(availability.blocks.length, stadium.blocks.length);

    final block = stadium.blockById('E_104')!;
    final sold = availability.block(block.id)!;
    final free = List.generate(
      block.capacity,
      (i) => i,
    ).firstWhere((i) => !sold.isSold(i));
    final ticket = await repo.issueTicket(
      match: match,
      seat: block.seatAt(free),
      vip: false,
      receipt: PaymentReceipt(
        reference: 'TEST',
        method: PaymentMethod.cib,
        amount: match.priceFor(block),
        paidAt: DateTime(2026, 11, 23, 12),
      ),
    );
    expect(ticket.stadiumName, '8 May 1945 Stadium');
    expect(ticket.gate.id, 'B');
    expect(ticket.price, 1000); // 800 DA x 1.25
  });

  test('a single-tier block is described by its rows, not a tier', () async {
    final setif = await repo.fetchStadium('8-mai-1945');
    final oran = await repo.fetchStadium('miloud-hadefi');
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    final east = setif.standById('E')!;
    expect(en.tier(east, setif.blockById('E_101')!), '36 rows');
    expect(ar.tier(east, setif.blockById('E_101')!), '36 صفًا');
    final oranEast = oran.standById('E')!;
    expect(en.tier(oranEast, oran.blockById('E_201')!), 'Upper tier');
  });

  group('TeamPlan', () {
    Future<TeamPlan> planFor(String teamId) async {
      final team = (await repo.fetchTeams()).firstWhere((t) => t.id == teamId);
      return TeamPlan.of(
        team,
        await repo.fetchUpcomingMatches(),
        fallbackStadiumId: 'miloud-hadefi',
      );
    }

    test('a club with a home ground goes there', () async {
      final mco = await planFor('MCO');
      expect(mco.stadiumId, 'miloud-hadefi');
      expect(mco.nextMatch!.id, 'mco-mca-2026-11-28');
      final ess = await planFor('ESS');
      expect(ess.stadiumId, '8-mai-1945');
      expect(ess.nextMatch!.id, 'ess-crb-2026-11-28');
    });

    test('a visiting club goes where it plays next', () async {
      expect((await planFor('CRB')).stadiumId, '8-mai-1945');
      expect((await planFor('MCA')).stadiumId, 'miloud-hadefi');
      final csc = await planFor('CSC');
      expect(csc.stadiumId, '8-mai-1945');
      expect(csc.nextMatch!.id, 'ess-csc-2026-12-19');
    });
  });
}
