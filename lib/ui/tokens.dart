import 'package:flutter/widgets.dart';

/// Stadia design tokens: dark navy + white, glass surfaces, no gradients.
abstract final class StadiaColors {
  static const navy950 = Color(0xFF040A16);
  static const navy900 = Color(0xFF071327);
  static const navy800 = Color(0xFF0C1D3A);
  static const navy700 = Color(0xFF13294C);
  static const navy600 = Color(0xFF1C3762);
  static const navy400 = Color(0xFF3F5D8C);

  static const white = Color(0xFFFFFFFF);
  static const text = white;
  static const textSecondary = Color(0xBFFFFFFF); // 75 %
  static const textTertiary = Color(0x80FFFFFF); // 50 %
  static const hairline = Color(0x24FFFFFF); // 14 %
  static const divider = Color(0x14FFFFFF); // 8 %

  /// Glass on dark content: translucent navy + faint white rim.
  static const glassDark = Color(0x9E0C1D3A); // navy800 @ 62 %
  static const glassLight = Color(0x1FFFFFFF); // white @ 12 %
  static const glassBorder = Color(0x2EFFFFFF); // white @ 18 %

  /// Availability – the only accents in the app.
  static const free = Color(0xFF5FE0A6);
  static const limited = Color(0xFFFFC65C);
  static const sold = Color(0xFF41516E);
  static const focus = Color(0xFF8DC9FF);
  static const danger = Color(0xFFFF6B6B);
}

abstract final class StadiaRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

abstract final class StadiaSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const gutter = 20.0;
}

abstract final class StadiaMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Type scale (platform font: SF Pro on iOS, Roboto on Android).
abstract final class StadiaText {
  static const _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontSize: 34,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: StadiaColors.text,
  );
  static const title = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: StadiaColors.text,
  );
  static const headline = TextStyle(
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: StadiaColors.text,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: StadiaColors.textSecondary,
  );
  static const label = TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: StadiaColors.text,
  );
  static const caption = TextStyle(
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: StadiaColors.textTertiary,
  );
  static const overline = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: StadiaColors.textTertiary,
  );
  static const number = TextStyle(
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: StadiaColors.text,
    fontFeatures: _tabular,
  );
  static const numberSmall = TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: StadiaColors.text,
    fontFeatures: _tabular,
  );
}
