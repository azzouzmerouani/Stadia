import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../ui/tokens.dart';
import 'local_asset_server.dart';
import 'stadium_protocol.dart';
import 'stadium_scene_controller.dart';

/// The Three.js stadium (assets/web) in a WebView, wired to a
/// [StadiumSceneController]. The controller gets its port when the page
/// reports `ready`; anything sent before that is queued.
class StadiumWebView extends ConsumerStatefulWidget {
  const StadiumWebView({
    super.key,
    required this.controller,
    required this.mode,
  });

  final StadiumSceneController controller;
  final SceneMode mode;

  @override
  ConsumerState<StadiumWebView> createState() => _StadiumWebViewState();
}

class _StadiumWebViewState extends ConsumerState<StadiumWebView> {
  WebViewController? _web;
  Uri? _origin;

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  WebViewController _create(LocalAssetServer server) {
    final origin = server.origin.toString();
    _origin = server.origin;
    _log('loading ${server.page(widget.mode, debug: _debugStats)}');
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(StadiaColors.page)
      ..addJavaScriptChannel(
        bridgeChannelName,
        onMessageReceived: (m) => _onMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) => _log('page loaded $url'),
          // The viewer never navigates; block anything off the loopback.
          onNavigationRequest: (req) => req.url.startsWith(origin)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            _log(
              'resource error ${error.errorCode} ${error.description} '
              '(${error.url})',
            );
            if (error.isForMainFrame ?? true) {
              _emitError('The 3D view could not load (${error.description})');
            }
          },
        ),
      )
      ..loadRequest(server.page(widget.mode, debug: _debugStats));
  }

  /// `flutter run --dart-define=STADIA_3D_DEBUG=true` shows the scene's
  /// fps / draw-call overlay and streams `stats` messages.
  static const _debugStats = bool.fromEnvironment('STADIA_3D_DEBUG');

  static void _log(String message) {
    if (kDebugMode) {
      final t = DateTime.now().toIso8601String().substring(11, 23);
      debugPrint('stadia 3D $t: $message');
    }
  }

  void _onMessage(String raw) {
    if (!mounted) return;
    if (!raw.contains('"stats"')) {
      _log(raw.length > 160 ? '${raw.substring(0, 160)}…' : raw);
    }
    if (!widget.controller.isAttached && _isReady(raw)) {
      widget.controller.attach(_runJs);
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

  void _runJs(String json) {
    final web = _web;
    if (web == null) return;
    unawaited(
      web
          .runJavaScript('window.stadia && window.stadia.receive($json);')
          .onError((error, _) => debugPrint('stadia bridge: $error')),
    );
  }

  void _emitError(String message) => widget.controller.handleIncoming(
    jsonEncode({'type': 'error', 'message': message}),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(localAssetServerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        _emitError('3D server failed: $error');
      }
    });
    final server = ref.watch(localAssetServerProvider);
    final value = server.value;
    if (value == null) {
      return const ColoredBox(color: StadiaColors.page);
    }
    if (_web == null || _origin != value.origin) _web = _create(value);
    return WebViewWidget(
      controller: _web!,
      // The scene owns every touch: orbit, pinch, tap.
      gestureRecognizers: const {
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}
