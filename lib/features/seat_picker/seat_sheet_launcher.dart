import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stadium3d/stadium_scene_controller.dart';
import 'seat_sheet.dart';

/// Completes with the issued ticket id, or null when the fan closed the sheet
/// or chose another seat.
typedef SeatSheetLauncher = Future<String?> Function(
  BuildContext context, {
  required String matchId,
  required StadiumSceneController scene,
});

/// Opens the seat detail sheet once a seat is picked. Overridable in tests.
final seatSheetLauncherProvider =
    Provider<SeatSheetLauncher>((ref) => showSeatSheet);
