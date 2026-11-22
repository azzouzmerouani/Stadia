import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stadium_protocol.dart';
import 'stadium_scene_controller.dart';
import 'stadium_web_view.dart';

typedef StadiumViewBuilder = Widget Function(
  BuildContext context,
  StadiumSceneController controller,
  SceneMode mode,
);

/// Builds the 3D stadium for a screen. Overridden in widget tests with a
/// fake (WebViews cannot run under `flutter test`).
final stadiumViewBuilderProvider = Provider<StadiumViewBuilder>(
  (ref) => (context, controller, mode) =>
      StadiumWebView(controller: controller, mode: mode),
);
