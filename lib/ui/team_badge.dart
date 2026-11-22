import 'package:flutter/material.dart';

import '../data/models/match.dart';
import 'tokens.dart';

/// Club crest: the club's logo when the data has one, otherwise a shield
/// drawn in the club colours.
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.team, this.size = 48});

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = team.logo;
    final drawn = _DrawnCrest(team: team, size: size);
    return Semantics(
      label: team.name,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: logo == null
            ? drawn
            : Image.asset(
                logo,
                fit: BoxFit.contain,
                // Decoded at display size (x3 for dense screens).
                cacheHeight: (size * 3).round(),
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) => drawn,
              ),
      ),
    );
  }
}

class _DrawnCrest extends StatelessWidget {
  const _DrawnCrest({required this.team, required this.size});

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Color(team.primaryColor);
    final secondary = Color(team.secondaryColor);
    final onPrimary = primary.computeLuminance() > 0.5
        ? StadiaColors.ink
        : StadiaColors.white;
    return CustomPaint(
      painter: _CrestPainter(primary, secondary),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.04),
          child: Text(
            team.shortName,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: StadiaText.family,
              color: onPrimary,
              fontSize: size * (team.shortName.length > 3 ? 0.2 : 0.24),
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  _CrestPainter(this.primary, this.secondary);

  final Color primary;
  final Color secondary;

  Path _shield(Size s, double inset) {
    final w = s.width - inset * 2;
    final h = s.height - inset * 2;
    final x = inset;
    final y = inset;
    return Path()
      ..moveTo(x + w * 0.5, y)
      ..lineTo(x + w, y + h * 0.14)
      ..lineTo(x + w, y + h * 0.52)
      ..quadraticBezierTo(x + w, y + h * 0.86, x + w * 0.5, y + h)
      ..quadraticBezierTo(x, y + h * 0.86, x, y + h * 0.52)
      ..lineTo(x, y + h * 0.14)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_shield(size, 0), Paint()..color = secondary);
    final innerInset = size.width * 0.07;
    canvas.drawPath(_shield(size, innerInset), Paint()..color = primary);
    // Thin hairline so white/black crests still read on purple.
    canvas.drawPath(
      _shield(size, 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = StadiaColors.hairline,
    );
  }

  @override
  bool shouldRepaint(_CrestPainter old) =>
      old.primary != primary || old.secondary != secondary;
}
