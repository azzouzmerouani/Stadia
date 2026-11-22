import 'package:flutter/widgets.dart';

/// Stadia design tokens, after the Fantasy Premier League ("ism") design
/// system: deep purple surfaces, white type, electric green / cyan / lilac
/// accents, 8-12-16 radii and pill buttons. Type is Cairo (Arabic + Latin).
abstract final class StadiaColors {
  // Purple ramp (FPL "mono" scale), darkest first.
  static const purple120 = Color(0xFF1E0021);
  static const purple110 = Color(0xFF28002B);
  static const purple100 = Color(0xFF37003C);
  static const purple90 = Color(0xFF41054B);
  static const purple80 = Color(0xFF541E5D);
  static const purple70 = Color(0xFF7D5980);
  static const purple50 = Color(0xFF9B809D);
  static const purple20 = Color(0xFFD7CCD8);
  static const purple10 = Color(0xFFEBE5EB);
  static const purple5 = Color(0xFFF5F2F5);

  // Brand accents.
  static const green = Color(0xFF00FF87);
  static const cyan = Color(0xFF05F0FF);
  static const lilac = Color(0xFF953BFF);
  static const pink = Color(0xFFE90052);

  /// Screen background.
  static const page = purple120;

  /// Text and icons on white (buttons, the paper ticket).
  static const ink = purple100;

  static const white = Color(0xFFFFFFFF);
  static const text = white;
  static const textSecondary = Color(0xBFFFFFFF); // 75 %
  static const textTertiary = Color(0x8CFFFFFF); // 55 %
  static const hairline = Color(0x26FFFFFF); // 15 %
  static const divider = Color(0x1AFFFFFF); // 10 %

  /// White washes FPL layers on purple (5 / 10 / 15 %).
  static const overlay5 = Color(0x0DFFFFFF);
  static const overlay10 = Color(0x1AFFFFFF);
  static const overlay15 = Color(0x26FFFFFF);

  /// Floating panels over the map and the 3D scene: purple110 at 90 %.
  static const glassDark = Color(0xE628002B);
  static const glassLight = overlay10;
  static const glassBorder = Color(0x1FFFFFFF); // 12 %

  /// Availability.
  static const free = green;
  static const limited = Color(0xFFFF1B54);
  static const sold = purple70;

  static const focus = cyan;
  static const danger = Color(0xFFFF1B54);
}

/// FPL's two signature sweeps. Directional, so they run right-to-left in
/// Arabic (FPL flips its 90deg gradients to 270deg for RTL the same way).
abstract final class StadiaGradients {
  static const brand = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [StadiaColors.cyan, StadiaColors.lilac],
  );
  static const go = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [StadiaColors.green, StadiaColors.cyan],
  );
}

abstract final class StadiaRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

abstract final class StadiaShadows {
  /// FPL's card shadow: 0 8 20 black @ 20 %.
  static const card = [
    BoxShadow(color: Color(0x33000000), offset: Offset(0, 8), blurRadius: 20),
  ];
}

abstract final class StadiaSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const gutter = 16.0;
}

abstract final class StadiaMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Type scale on Cairo. FPL's bold 32/24/20/16 headings and 14/1.4 body,
/// with a little more line height for Arabic, and no letter spacing (it
/// would pull Arabic letters apart).
abstract final class StadiaText {
  static const family = 'Cairo';
  static const _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: family,
    fontSize: 30,
    height: 1.3,
    fontWeight: FontWeight.w800,
    color: StadiaColors.text,
  );
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: StadiaColors.text,
  );
  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: StadiaColors.text,
  );
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: StadiaColors.textSecondary,
  );
  static const label = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: StadiaColors.text,
  );
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: StadiaColors.textTertiary,
  );
  static const overline = TextStyle(
    fontFamily: family,
    fontSize: 11.5,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: StadiaColors.textTertiary,
  );
  static const number = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w800,
    color: StadiaColors.text,
    fontFeatures: _tabular,
  );
  static const numberSmall = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: StadiaColors.text,
    fontFeatures: _tabular,
  );
}
