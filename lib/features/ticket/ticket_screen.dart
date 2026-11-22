import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/models/ticket.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/glass.dart';
import '../../ui/icons.dart';
import '../../ui/tokens.dart';
import '../seat_picker/booking_words.dart';
import 'widgets/ticket_card.dart';

/// "You're in": the issued ticket with its entry QR and gate details.
class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(
      ticketWalletProvider.select(
        (all) => all.where((t) => t.id == ticketId).firstOrNull,
      ),
    );
    void home() => context.go(Routes.map);
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);

    return PopScope(
      // The booking flow is behind us: back goes to the map, not the sheet.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) home();
      },
      child: Scaffold(
        backgroundColor: StadiaColors.page,
        body: SafeArea(
          child: ticket == null
              ? _Missing(onHome: home)
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          StadiaSpace.gutter,
                          StadiaSpace.xl,
                          StadiaSpace.gutter,
                          StadiaSpace.xl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(ticket: ticket),
                            const SizedBox(height: StadiaSpace.xxl),
                            TicketCard(ticket: ticket)
                                .animate()
                                .fadeIn(
                                  delay: 120.ms,
                                  duration: StadiaMotion.slow,
                                )
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  delay: 120.ms,
                                  duration: StadiaMotion.slow,
                                  curve: StadiaMotion.emphasized,
                                ),
                            const SizedBox(height: StadiaSpace.lg),
                            _GatesNote(ticket: ticket).animate().fadeIn(
                              delay: 280.ms,
                              duration: StadiaMotion.slow,
                            ),
                            const SizedBox(height: StadiaSpace.md),
                            Text(
                              l10n.paidRef(
                                f.price(ticket.total),
                                ticket.paymentReference,
                              ),
                              textAlign: TextAlign.center,
                              style: StadiaText.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        StadiaSpace.gutter,
                        StadiaSpace.sm,
                        StadiaSpace.gutter,
                        StadiaSpace.md,
                      ),
                      child: StadiaButton(
                        label: l10n.backToMap,
                        leading: StadiaGlyph.pin,
                        onPressed: home,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final match = ticket.match;
    return Column(
      children: [
        Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                gradient: StadiaGradients.go,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: StadiaIcon(
                  StadiaGlyph.check,
                  size: 30,
                  color: StadiaColors.ink,
                  strokeWidth: 2.6,
                ),
              ),
            )
            .animate()
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: 520.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: StadiaMotion.medium),
        const SizedBox(height: StadiaSpace.lg),
        Text(
          l10n.youreIn,
          textAlign: TextAlign.center,
          style: StadiaText.display,
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.match(match)} · '
          '${StadiaFormat.of(context).matchDateLong(match.kickoff)}',
          textAlign: TextAlign.center,
          style: StadiaText.body,
        ),
      ],
    );
  }
}

class _GatesNote extends StatelessWidget {
  const _GatesNote({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lead = ticket.match.kickoff.difference(ticket.gatesOpenAt);
    final leadText = lead.inMinutes % 60 == 0
        ? l10n.leadHours(lead.inHours)
        : l10n.leadMinutes(lead.inMinutes);
    final where = ticket.vip
        ? l10n.useGateVip(ticket.gate.id)
        : l10n.useGateStand(ticket.gate.id, ticket.standName);
    return GlassSurface(
      fill: StadiaColors.purple100,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StadiaIcon(StadiaGlyph.clock, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gatesOpenAt(
                    StadiaFormat.of(context).time(ticket.gatesOpenAt),
                  ),
                  style: StadiaText.headline,
                ),
                const SizedBox(height: 2),
                Text(l10n.gatesLead(leadText, where), style: StadiaText.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(StadiaSpace.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: StadiaIcon(StadiaGlyph.ticket, size: 36)),
          const SizedBox(height: StadiaSpace.md),
          Text(
            l10n.ticketNotFound,
            textAlign: TextAlign.center,
            style: StadiaText.title,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ticketNotFoundBody,
            textAlign: TextAlign.center,
            style: StadiaText.body,
          ),
          const SizedBox(height: StadiaSpace.xl),
          StadiaButton(label: l10n.backToMap, onPressed: onHome),
        ],
      ),
    );
  }
}
