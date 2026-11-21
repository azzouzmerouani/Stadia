import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildStadiaTheme() {
  const scheme = ColorScheme.dark(
    primary: StadiaColors.white,
    onPrimary: StadiaColors.navy900,
    secondary: StadiaColors.focus,
    surface: StadiaColors.navy900,
    error: StadiaColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: StadiaColors.navy900,
    canvasColor: StadiaColors.navy900,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: const TextTheme(
      displaySmall: StadiaText.display,
      titleLarge: StadiaText.title,
      titleMedium: StadiaText.headline,
      bodyMedium: StadiaText.body,
      labelLarge: StadiaText.label,
      bodySmall: StadiaText.caption,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      modalBarrierColor: Color(0x99040A16),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
