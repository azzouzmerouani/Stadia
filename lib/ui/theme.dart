import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildStadiaTheme() {
  const scheme = ColorScheme.dark(
    primary: StadiaColors.white,
    onPrimary: StadiaColors.ink,
    secondary: StadiaColors.green,
    onSecondary: StadiaColors.ink,
    tertiary: StadiaColors.cyan,
    surface: StadiaColors.page,
    error: StadiaColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: StadiaText.family,
    scaffoldBackgroundColor: StadiaColors.page,
    canvasColor: StadiaColors.page,
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
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: StadiaColors.cyan,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
