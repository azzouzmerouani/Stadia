import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// A "runner on the track": a bright segment lapping a stadium-shaped
/// outline. Used on the splash screen and while the 3D scene loads.
class TrackLoader extends StatefulWidget {
  const TrackLoader({super.key, this.width = 120, this.color = StadiaColors.white});

  final double width;
  final Color color;

  @override
  State<TrackLoader> createState() => _TrackLoaderState();
}

class _TrackLoaderState extends State<TrackLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.width * 0.56,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TrackPainter(_c, widget.color),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.t, this.color) : super(repaint: t);

  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.07;
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(
      rect.deflate(stroke),
      Radius.circular(size.height / 2),
    );
    final inner = RRect.fromRectAndRadius(
      rect.deflate(size.height * 0.3),
      Radius.circular(size.height * 0.2),
    );
    final base = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawRRect(outer, base);
    canvas.drawRRect(
      inner,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.5,
    );

    final metric = (Path()..addRRect(outer)).computeMetrics().first;
    final len = metric.length;
    final head = Curves.easeInOutSine.transform(t.value) * len;
    const tail = 0.22;
    final from = head - len * tail;
    final runner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    void segment(double a, double b) =>
        canvas.drawPath(metric.extractPath(a, b), runner);
    if (from < 0) {
      segment(len + from, len);
      segment(0, head);
    } else {
      segment(from, head);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.color != color;
}

/// Compact circular spinner for buttons.
class StadiaSpinner extends StatefulWidget {
  const StadiaSpinner({super.key, this.size = 20, this.color = StadiaColors.white});

  final double size;
  final Color color;

  @override
  State<StadiaSpinner> createState() => _StadiaSpinnerState();
}

class _StadiaSpinnerState extends State<StadiaSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ArcPainter(_c.value, widget.color),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.12;
    final rect = (Offset.zero & size).deflate(w / 2);
    canvas.drawArc(
      rect,
      t * math.pi * 2,
      math.pi * 1.2,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.t != t || old.color != color;
}
