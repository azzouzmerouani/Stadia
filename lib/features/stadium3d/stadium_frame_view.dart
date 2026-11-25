import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'stadium_protocol.dart';
import 'stadium_scene_controller.dart';

/// Web only: the Three.js stadium (assets/web) in a same-origin `<iframe>`,
/// wired to a [StadiumSceneController] over `postMessage`. The page posts
/// `{stadiaBridge: json}` to its parent and Flutter posts `{stadia: json}`
/// back; both sides drop messages from any other window or origin. As with
/// the WebView, the controller gets its port when the page reports `ready`.
class StadiumFrameView extends StatefulWidget {
  const StadiumFrameView({
    super.key,
    required this.controller,
    required this.mode,
    required this.stadiumId,
  });

  final StadiumSceneController controller;
  final SceneMode mode;

  /// Which model the page loads (`assets/3d/<stadiumId>.glb`).
  final String stadiumId;

  @override
  State<StadiumFrameView> createState() => _StadiumFrameViewState();
}

class _StadiumFrameViewState extends State<StadiumFrameView> {
  web.HTMLIFrameElement? _frame;
  late final JSFunction _onMessage = _onWindowMessage.toJS;
  late final JSFunction _onLoad = _onFrameLoad.toJS;

  /// `--dart-define=STADIA_3D_DEBUG=true` shows the scene's stats overlay.
  static const _debugStats = bool.fromEnvironment('STADIA_3D_DEBUG');

  static String get _origin => web.window.location.origin;

  @override
  void initState() {
    super.initState();
    web.window.addEventListener('message', _onMessage);
  }

  @override
  void didUpdateWidget(StadiumFrameView old) {
    super.didUpdateWidget(old);
    if (old.stadiumId != widget.stadiumId || old.mode != widget.mode) {
      // A new page replaces this one: hold messages until it is ready.
      old.controller.detach();
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _onMessage);
    _frame?.removeEventListener('load', _onLoad);
    widget.controller.detach();
    super.dispose();
  }

  /// The viewer page on the app's origin (it finds the models in ../3d).
  Uri get _page {
    final index = ui_web.assetManager.getAssetUrl('assets/web/index.html');
    return Uri.parse(web.document.baseURI)
        .resolve(index)
        .replace(
          queryParameters: {
            'mode': widget.mode.name,
            'stadium': widget.stadiumId,
            'models': '../3d',
            if (_debugStats) 'debug': '1',
          },
        );
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('stadia 3D (web): $message');
  }

  void _onElementCreated(Object element) {
    _frame?.removeEventListener('load', _onLoad);
    final frame = element as web.HTMLIFrameElement;
    final page = _page;
    _log('loading $page');
    frame
      ..title = '3D stadium'
      ..src = page.toString();
    frame.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      ..backgroundColor = '#1E0021';
    frame.addEventListener('load', _onLoad);
    _frame = frame;
  }

  /// The page and stadium.js have loaded; stadium.js defines
  /// `window.stadia` as it runs, so a page without it (a 404, a server
  /// error page) never will report ready.
  void _onFrameLoad(web.Event _) {
    final win = _frame?.contentWindow;
    if (!mounted || win == null) return;
    bool viewer;
    try {
      viewer = win.has('stadia');
    } on Object {
      viewer = false; // not same-origin: not ours
    }
    if (!viewer) _emitError('The 3D view could not load');
  }

  void _onWindowMessage(web.MessageEvent event) {
    final frame = _frame;
    if (!mounted || frame == null) return;
    if (event.origin != _origin) return;
    if (!event.source.strictEquals(frame.contentWindow).toDart) return;
    final data = event.data.dartify();
    if (data is! Map) return;
    final raw = data['stadiaBridge'];
    if (raw is! String) return;
    if (!raw.contains('"stats"')) {
      _log(raw.length > 160 ? '${raw.substring(0, 160)}…' : raw);
    }
    if (!widget.controller.isAttached && _isReady(raw)) {
      widget.controller.attach(_post);
    }
    widget.controller.handleIncoming(raw);
  }

  static bool _isReady(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map && decoded['type'] == 'ready';
    } on FormatException {
      return false;
    }
  }

  void _post(String json) {
    final win = _frame?.contentWindow;
    if (win == null) return;
    win.postMessage({'stadia': json}.jsify(), _origin.toJS);
  }

  void _emitError(String message) => widget.controller.handleIncoming(
    jsonEncode({'type': 'error', 'message': message}),
  );

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      // A new stadium or mode is a new page.
      key: ValueKey('${widget.mode.name}/${widget.stadiumId}'),
      tagName: 'iframe',
      onElementCreated: _onElementCreated,
    );
  }
}
