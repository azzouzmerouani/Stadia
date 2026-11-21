import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Hand-drawn glyph set (24×24 grid, 1.8 stroke) – no icon font packs.
enum StadiaGlyph {
  back,
  close,
  arrowRight,
  calendar,
  clock,
  pin,
  seat,
  gate,
  ticket,
  skip,
  crown,
  check,
  cube,
  card,
  locate,
  stadium,
  info,
  orbit,
}

class StadiaIcon extends StatelessWidget {
  const StadiaIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.color = const Color(0xFFFFFFFF),
    this.strokeWidth = 1.8,
    this.semanticLabel,
  });

  final StadiaGlyph glyph;
  final double size;
  final Color color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GlyphPainter(glyph, color, strokeWidth),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: icon);
    return Semantics(label: semanticLabel, child: icon);
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color, this.strokeWidth);

  final StadiaGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
    void poly(List<double> pts, {bool close = false}) {
      final p = Path()..moveTo(pts[0], pts[1]);
      for (var i = 2; i < pts.length; i += 2) {
        p.lineTo(pts[i], pts[i + 1]);
      }
      if (close) p.close();
      canvas.drawPath(p, stroke);
    }

    RRect rr(double l, double t, double w, double h, double r) =>
        RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(r));

    switch (glyph) {
      case StadiaGlyph.back:
        poly([15, 5, 8, 12, 15, 19]);
      case StadiaGlyph.close:
        line(6.5, 6.5, 17.5, 17.5);
        line(17.5, 6.5, 6.5, 17.5);
      case StadiaGlyph.arrowRight:
        line(5, 12, 19, 12);
        poly([13, 6, 19, 12, 13, 18]);
      case StadiaGlyph.calendar:
        canvas.drawRRect(rr(4, 5.5, 16, 14.5, 3), stroke);
        line(4, 10, 20, 10);
        line(8.5, 3.5, 8.5, 7);
        line(15.5, 3.5, 15.5, 7);
      case StadiaGlyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        poly([12, 7.5, 12, 12, 15, 14]);
      case StadiaGlyph.pin:
        final p = Path()
          ..moveTo(12, 21)
          ..cubicTo(12, 21, 5, 14.6, 5, 9.6)
          ..arcToPoint(const Offset(19, 9.6),
              radius: const Radius.circular(7))
          ..cubicTo(19, 14.6, 12, 21, 12, 21)
          ..close();
        canvas.drawPath(p, stroke);
        canvas.drawCircle(const Offset(12, 9.6), 2.4, stroke);
      case StadiaGlyph.seat:
        canvas.drawRRect(rr(7, 3.5, 10, 9, 2.5), stroke);
        canvas.drawRRect(rr(5, 12.5, 14, 4, 2), stroke);
        line(7.5, 16.5, 7.5, 20.5);
        line(16.5, 16.5, 16.5, 20.5);
      case StadiaGlyph.gate:
        final p = Path()
          ..moveTo(5.5, 20)
          ..lineTo(5.5, 10.5)
          ..arcToPoint(const Offset(18.5, 10.5),
              radius: const Radius.circular(6.5))
          ..lineTo(18.5, 20);
        canvas.drawPath(p, stroke);
        line(3, 20, 21, 20);
        line(10, 12, 10, 20);
        line(14, 12, 14, 20);
      case StadiaGlyph.ticket:
        final p = Path()
          ..moveTo(6, 5)
          ..lineTo(18, 5)
          ..arcToPoint(const Offset(20, 7), radius: const Radius.circular(2))
          ..lineTo(20, 9.5)
          ..arcToPoint(const Offset(20, 14.5),
              radius: const Radius.circular(2.5), clockwise: false)
          ..lineTo(20, 17)
          ..arcToPoint(const Offset(18, 19), radius: const Radius.circular(2))
          ..lineTo(6, 19)
          ..arcToPoint(const Offset(4, 17), radius: const Radius.circular(2))
          ..lineTo(4, 14.5)
          ..arcToPoint(const Offset(4, 9.5),
              radius: const Radius.circular(2.5), clockwise: false)
          ..lineTo(4, 7)
          ..arcToPoint(const Offset(6, 5), radius: const Radius.circular(2))
          ..close();
        canvas.drawPath(p, stroke);
        for (var y = 8.0; y <= 16; y += 2.7) {
          canvas.drawCircle(Offset(14.5, y), 0.6, fill);
        }
      case StadiaGlyph.skip:
        poly([5, 6.5, 11, 12, 5, 17.5], close: true);
        poly([12, 6.5, 18, 12, 12, 17.5], close: true);
        line(20, 6.5, 20, 17.5);
      case StadiaGlyph.crown:
        poly([4.5, 17, 5.5, 8, 9.5, 12, 12, 6, 14.5, 12, 18.5, 8, 19.5, 17],
            close: true);
        line(4.5, 20, 19.5, 20);
      case StadiaGlyph.check:
        poly([5, 12.5, 10, 17, 19, 7.5]);
      case StadiaGlyph.cube:
        poly([12, 3, 20, 7.5, 20, 16.5, 12, 21, 4, 16.5, 4, 7.5], close: true);
        poly([4, 7.5, 12, 12, 20, 7.5]);
        line(12, 12, 12, 21);
      case StadiaGlyph.card:
        canvas.drawRRect(rr(3, 6, 18, 12.5, 2.5), stroke);
        line(3, 10, 21, 10);
        line(6.5, 14.8, 10, 14.8);
      case StadiaGlyph.locate:
        canvas.drawCircle(const Offset(12, 12), 6.5, stroke);
        canvas.drawCircle(const Offset(12, 12), 1.8, fill);
        line(12, 2.5, 12, 5.5);
        line(12, 18.5, 12, 21.5);
        line(2.5, 12, 5.5, 12);
        line(18.5, 12, 21.5, 12);
      case StadiaGlyph.stadium:
        canvas.drawOval(
            Rect.fromCenter(center: const Offset(12, 10), width: 18, height: 8),
            stroke);
        canvas.drawOval(
            Rect.fromCenter(center: const Offset(12, 10), width: 8, height: 3.4),
            stroke);
        line(3, 10, 3, 14);
        line(21, 10, 21, 14);
        canvas.drawArc(
            Rect.fromCenter(center: const Offset(12, 14), width: 18, height: 8),
            0,
            math.pi,
            false,
            stroke);
      case StadiaGlyph.info:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        line(12, 11, 12, 16.5);
        canvas.drawCircle(const Offset(12, 7.8), 1.1, fill);
      case StadiaGlyph.orbit:
        final rect =
            Rect.fromCenter(center: const Offset(12, 13), width: 19, height: 8);
        canvas.drawArc(rect, math.pi * 0.15, math.pi * 1.55, false, stroke);
        poly([19.2, 10.4, 21.4, 12.6, 18.6, 13.6]);
        canvas.drawCircle(const Offset(12, 8.5), 2.6, stroke);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.strokeWidth != strokeWidth;
}
