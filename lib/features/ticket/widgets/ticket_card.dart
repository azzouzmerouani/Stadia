import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/models/match.dart';
import '../../../data/models/ticket.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/format.dart';
import '../../../ui/icons.dart';
import '../../../ui/team_badge.dart';
import '../../../ui/tokens.dart';

const _paper = StadiaColors.white;
const _ink = StadiaColors.ink;
const _inkSoft = Color(0xA637003C);
const _inkFaint = Color(0x7337003C);

/// Paper ticket: match and seat on top, the QR below a perforated tear line
/// with half-circle notches cut out of both edges.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket});

  final Ticket ticket;

  static const notchRadius = 13.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.ticketSemantics(ticket.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipPath(
            clipper: const TicketClipper(notchAt: NotchEdge.bottom),
            child: ColoredBox(
              color: _paper,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // FPL's signature sweep along the top edge.
                  const SizedBox(
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: StadiaGradients.brand,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: _Details(ticket: ticket),
                  ),
                ],
              ),
            ),
          ),
          // Overlap by 1px so the two halves never show an anti-aliased seam.
          Transform.translate(
            offset: const Offset(0, -1),
            child: ClipPath(
              clipper: const TicketClipper(notchAt: NotchEdge.top),
              child: ColoredBox(
                color: _paper,
                child: CustomPaint(
                  foregroundPainter: const _PerforationPainter(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: _Pass(ticket: ticket),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum NotchEdge { top, bottom }

/// Rounded rectangle with concave half-circle notches at the left and right
/// ends of one edge ([notchAt]); the other edge keeps rounded corners.
class TicketClipper extends CustomClipper<Path> {
  const TicketClipper({
    required this.notchAt,
    this.notch = TicketCard.notchRadius,
    this.corner = 20,
  });

  final NotchEdge notchAt;
  final double notch;
  final double corner;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final n = Radius.circular(notch);
    final c = Radius.circular(corner);
    final path = Path();
    if (notchAt == NotchEdge.bottom) {
      path
        ..moveTo(0, corner)
        ..arcToPoint(Offset(corner, 0), radius: c)
        ..lineTo(w - corner, 0)
        ..arcToPoint(Offset(w, corner), radius: c)
        ..lineTo(w, h - notch)
        ..arcToPoint(Offset(w - notch, h), radius: n, clockwise: false)
        ..lineTo(notch, h)
        ..arcToPoint(Offset(0, h - notch), radius: n, clockwise: false);
    } else {
      path
        ..moveTo(notch, 0)
        ..lineTo(w - notch, 0)
        ..arcToPoint(Offset(w, notch), radius: n, clockwise: false)
        ..lineTo(w, h - corner)
        ..arcToPoint(Offset(w - corner, h), radius: c)
        ..lineTo(corner, h)
        ..arcToPoint(Offset(0, h - corner), radius: c)
        ..lineTo(0, notch)
        ..arcToPoint(Offset(notch, 0), radius: n, clockwise: false);
    }
    return path..close();
  }

  @override
  bool shouldReclip(TicketClipper old) =>
      old.notchAt != notchAt || old.notch != notch || old.corner != corner;
}

/// Dashed tear line between the notches.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x3337003C)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const inset = TicketCard.notchRadius + 8;
    const y = 1.0; // the half is shifted up by 1px
    for (var x = inset; x < size.width - inset; x += 11) {
      final end = (x + 6).clamp(0.0, size.width - inset);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter oldDelegate) => false;
}

class _Details extends StatelessWidget {
  const _Details({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);
    final t = ticket;
    final m = t.match;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${m.competition} · ${m.round}',
                style: StadiaText.overline.copyWith(color: _inkFaint),
              ),
            ),
            if (t.vip) const _VipChip(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Team(team: m.home),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  children: [
                    Text(
                      f.time(m.kickoff),
                      style: StadiaText.number.copyWith(
                        color: _ink,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      f.matchDate(m.kickoff),
                      style: StadiaText.caption.copyWith(color: _inkSoft),
                    ),
                  ],
                ),
              ),
            ),
            _Team(team: m.away),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const StadiaIcon(StadiaGlyph.pin, size: 15, color: _inkSoft),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t.stadiumName,
                style: StadiaText.label.copyWith(color: _inkSoft, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: const Color(0x1437003C)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Field(label: l10n.labelStand, value: t.standName),
            ),
            _Field(label: l10n.labelPaid, value: f.price(t.total), end: true),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Field(label: l10n.labelBlock, value: '${t.blockNumber}'),
            ),
            Expanded(
              child: _Field(label: l10n.labelRow, value: '${t.seat.row}'),
            ),
            Expanded(
              child: _Field(label: l10n.labelSeat, value: '${t.seat.seat}'),
            ),
            _Field(label: l10n.labelGate, value: t.gate.id, end: true),
          ],
        ),
      ],
    );
  }
}

class _Pass extends StatelessWidget {
  const _Pass({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TicketQr(payload: ticket.qrPayload),
        const SizedBox(height: 14),
        Text(
          ticket.id,
          textDirection: TextDirection.ltr,
          style: StadiaText.numberSmall.copyWith(
            color: _ink,
            letterSpacing: 1.6,
          ),
        ),
        Text(
          context.l10n.scanAt(ticket.gate.name),
          style: StadiaText.caption.copyWith(color: _inkSoft),
        ),
      ],
    );
  }
}

/// The entry QR. [payload] is what the gate scanner reads.
class TicketQr extends StatelessWidget {
  const TicketQr({super.key, required this.payload, this.size = 172});

  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: payload,
      size: size,
      padding: EdgeInsets.zero,
      backgroundColor: _paper,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      semanticsLabel: context.l10n.entryQr,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _ink),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: _ink,
      ),
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          TeamBadge(team: team, size: 46),
          const SizedBox(height: 8),
          Text(
            team.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: StadiaText.label.copyWith(color: _ink, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.end = false});

  final String label;
  final String value;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: StadiaText.overline.copyWith(color: _inkFaint, fontSize: 10.5),
        ),
        Text(
          value,
          style: StadiaText.numberSmall.copyWith(color: _ink, fontSize: 17),
        ),
      ],
    );
  }
}

class _VipChip extends StatelessWidget {
  const _VipChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(StadiaRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 10, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StadiaIcon(
              StadiaGlyph.crown,
              size: 13,
              color: StadiaColors.green,
            ),
            const SizedBox(width: 5),
            Text(
              'VIP',
              style: StadiaText.overline.copyWith(color: StadiaColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
