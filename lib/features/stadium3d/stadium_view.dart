import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// dart:io (loopback server) and webview_flutter never reach the web build.
import 'stadium_platform_io.dart'
    if (dart.library.js_interop) 'stadium_platform_web.dart'
    as platform;
import 'stadium_protocol.dart';
import 'stadium_scene_controller.dart';

typedef StadiumViewBuilder =
    Widget Function(
      BuildContext context,
      StadiumSceneController controller,
      SceneMode mode,
      String stadiumId,
    );

/// Builds the 3D stadium for a screen: a WebView on iOS/Android, an
/// `<iframe>` on the web. Overridden in widget tests with a fake (neither
/// can run under `flutter test`).
final stadiumViewBuilderProvider = Provider<StadiumViewBuilder>(
  (ref) => platform.buildStadiumView,
);

/// Flutter UI floating over the 3D view that takes clicks (cards, panels,
/// buttons). On the web the scene is an `<iframe>`, which sits above
/// Flutter's pointer handling: this puts an invisible DOM element under
/// [child] so its clicks reach Flutter, not the scene. Elsewhere it is
/// just [child]. Leave non-interactive notes unwrapped so the scene under
/// them stays draggable.
class OverScene extends StatelessWidget {
  const OverScene({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => platform.overScene(child);
}

/// What the 3D view needs before it can load, started by the splash: the
/// loopback asset server on iOS/Android; nothing on the web, where the
/// app's own origin serves the viewer.
final sceneHostProvider = FutureProvider<void>(platform.prepareSceneHost);
