import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import '../ui/scroll_behavior.dart';
import '../ui/theme.dart';
import 'router.dart';

class StadiaApp extends ConsumerWidget {
  const StadiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildStadiaTheme(),
      // Arabic (right-to-left) regardless of the device language.
      locale: Locale(ref.watch(languageProvider)),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      // Screens fill the window: wide ones lay out as a map app (see
      // StadiaLayout), narrow ones as the phone app.
      scrollBehavior: const StadiaScrollBehavior(),
    );
  }
}
