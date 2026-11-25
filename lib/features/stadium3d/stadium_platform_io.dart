import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_asset_server.dart';
import 'stadium_protocol.dart';
import 'stadium_scene_controller.dart';
import 'stadium_web_view.dart';

// iOS / Android (and `flutter test`): the viewer in a WebView, served by
// the loopback asset server. Picked by the conditional import in
// stadium_view.dart; the web build uses stadium_platform_web.dart.

Widget buildStadiumView(
  BuildContext context,
  StadiumSceneController controller,
  SceneMode mode,
  String stadiumId,
) => StadiumWebView(controller: controller, mode: mode, stadiumId: stadiumId);

/// Native platform views take part in Flutter's hit testing already.
Widget overScene(Widget child) => child;

Future<void> prepareSceneHost(Ref ref) =>
    ref.watch(localAssetServerProvider.future);
