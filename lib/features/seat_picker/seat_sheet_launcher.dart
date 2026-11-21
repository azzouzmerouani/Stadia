import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stadium3d/stadium_scene_controller.dart';

typedef SeatSheetLauncher = Future<void> Function(
  BuildContext context, {
  required String matchId,
  required StadiumSceneController scene,
});

/// Opens the seat detail sheet once a seat is picked. Replaced by the real
/// sheet in milestone 5; overridable in tests.
final seatSheetLauncherProvider = Provider<SeatSheetLauncher>(
  (ref) => (context, {required matchId, required scene}) async {},
);
