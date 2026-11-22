import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../data/providers.dart';
import '../stadium3d/local_asset_server.dart';

/// What the splash screen waits for, and where it goes next. Kept separate
/// so tests can override it.
class SplashTasks {
  SplashTasks(this._ref);

  final Ref _ref;

  String get nextRoute => Routes.intro;

  Future<void> run() async {
    await Future.wait([
      _ref.read(stadiumProvider.future),
      _ref.read(upcomingMatchesProvider.future),
      _ref.read(localAssetServerProvider.future), // serves the 3D viewer
    ]);
  }
}

final splashTasksProvider = Provider<SplashTasks>(SplashTasks.new);
