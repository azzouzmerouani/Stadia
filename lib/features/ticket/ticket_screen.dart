import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/models/ticket.dart';
import '../../data/providers.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/glass.dart';
import '../../ui/icons.dart';
import '../../ui/tokens.dart';
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

    return PopScope(
      // The booking flow is behind us: back goes to the map, not the sheet.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) home();
      },
      child: Scaffold(
        backgroundColor: StadiaColors.navy900,
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
                              'Paid ${formatPrice(ticket.total)} · '
                              'Ref ${ticket.paymentReference}',
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
                        label: 'Back to the map',
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
    final match = ticket.match;
    return Column(
      children: [
        Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: StadiaColors.free,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: StadiaIcon(
                  StadiaGlyph.check,
                  size: 30,
                  color: StadiaColors.navy900,
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
        const Text(
          "You're in",
          textAlign: TextAlign.center,
          style: StadiaText.display,
        ),
        const SizedBox(height: 6),
        Text(
          '${match.title} · ${formatMatchDateLong(match.kickoff)}',
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
    final lead = ticket.match.kickoff.difference(ticket.gatesOpenAt);
    final leadText = lead.inMinutes % 60 == 0
        ? '${lead.inHours} h'
        : '${lead.inMinutes} min';
    final where = ticket.vip
        ? 'Use Gate ${ticket.gate.id}, the VIP fast lane. The lounge opens '
              'with the gates.'
        : 'Use Gate ${ticket.gate.id}, the entrance for the '
              '${ticket.standName}.';
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                  'Gates open at ${formatTime(ticket.gatesOpenAt)}',
                  style: StadiaText.headline,
                ),
                const SizedBox(height: 4),
                Text(
                  "That's $leadText before kick-off. $where",
                  style: StadiaText.body.copyWith(fontSize: 14),
                ),
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
    return Padding(
      padding: const EdgeInsets.all(StadiaSpace.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: StadiaIcon(StadiaGlyph.ticket, size: 36)),
          const SizedBox(height: StadiaSpace.md),
          const Text(
            'Ticket not found',
            textAlign: TextAlign.center,
            style: StadiaText.title,
          ),
          const SizedBox(height: 6),
          const Text(
            'Tickets are kept on this device for the session. '
            'Book again from the map.',
            textAlign: TextAlign.center,
            style: StadiaText.body,
          ),
          const SizedBox(height: StadiaSpace.xl),
          StadiaButton(label: 'Back to the map', onPressed: onHome),
        ],
      ),
    );
  }
}
