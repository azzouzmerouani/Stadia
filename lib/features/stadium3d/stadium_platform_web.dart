import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import 'stadium_frame_view.dart';
import 'stadium_protocol.dart';
import 'stadium_scene_controller.dart';

// Web: the viewer in an <iframe> on the app's own origin, which already
// serves assets/web and assets/3d, so there is no server to start.

Widget buildStadiumView(
  BuildContext context,
  StadiumSceneController controller,
  SceneMode mode,
  String stadiumId,
) => StadiumFrameView(controller: controller, mode: mode, stadiumId: stadiumId);

/// An invisible `<div>` platform view under [child] (painted after the
/// iframe, so above it in the DOM) catches the clicks and hands them to
/// Flutter, the way package:pointer_interceptor does on the web.
Widget overScene(Widget child) => Stack(
  children: [
    Positioned.fill(
      child: HtmlElementView.fromTagName(
        tagName: 'div',
        isVisible: false,
        onElementCreated: (element) {
          (element as web.HTMLElement).style
            ..width = '100%'
            ..height = '100%';
        },
      ),
    ),
    child,
  ],
);

Future<void> prepareSceneHost(Ref ref) async {}
