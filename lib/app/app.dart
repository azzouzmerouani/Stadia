import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme.dart';
import 'router.dart';

class StadiaApp extends ConsumerWidget {
  const StadiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Stadia',
      debugShowCheckedModeBanner: false,
      theme: buildStadiaTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
