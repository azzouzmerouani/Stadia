import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stadium_protocol.dart';

/// Serves the bundled 3D viewer on the loopback interface:
///
/// ```text
/// http://127.0.0.1:PORT/FILE     -> assets/web/FILE
/// http://127.0.0.1:PORT/3d/FILE  -> assets/3d/FILE
/// ```
///
/// Why not file:// — Android WebView refuses fetch()/WASM from file URLs and
/// the Draco decoder runs in a blob Worker that needs a real origin. The
/// server binds to 127.0.0.1 on a random port, answers GET/HEAD only, only
/// reaches those two asset folders, and rejects foreign Host headers (DNS
/// rebinding). Nothing is fetched from the network.
class LocalAssetServer {
  LocalAssetServer._(this._server, this._bundle);

  static Future<LocalAssetServer> start({AssetBundle? bundle}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = LocalAssetServer._(server, bundle ?? rootBundle);
    server.listen((req) => unawaited(s._handle(req)));
    return s;
  }

  final HttpServer _server;
  final AssetBundle _bundle;

  int get port => _server.port;

  Uri get origin => Uri(scheme: 'http', host: '127.0.0.1', port: port);

  Uri page(SceneMode mode, {required bool debug}) => origin.replace(
    path: '/index.html',
    queryParameters: {'mode': mode.name, if (debug) 'debug': '1'},
  );

  /// Asset key for a request path, or null when it is outside the viewer.
  @visibleForTesting
  static String? assetKeyFor(String path) {
    final String decoded;
    try {
      decoded = Uri.decodeComponent(path);
    } on ArgumentError {
      return null;
    }
    if (decoded.contains('..') || decoded.contains('\\')) return null;
    if (decoded.isEmpty || decoded == '/') return 'assets/web/index.html';
    if (!decoded.startsWith('/')) return null;
    if (decoded.startsWith('/3d/')) return 'assets$decoded';
    return 'assets/web$decoded';
  }

  static const _types = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'wasm': 'application/wasm',
    'glb': 'model/gltf-binary',
    'json': 'application/json',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'ttf': 'font/ttf',
  };

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      if (req.method != 'GET' && req.method != 'HEAD') {
        res.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final host = req.headers.host;
      if (host != null && host != '127.0.0.1' && host != 'localhost') {
        res.statusCode = HttpStatus.forbidden;
        return;
      }
      final key = assetKeyFor(req.uri.path);
      if (key == null) {
        res.statusCode = HttpStatus.forbidden;
        return;
      }
      final ByteData data;
      try {
        data = await _bundle.load(key);
      } on Object {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final ext = key.substring(key.lastIndexOf('.') + 1);
      res.headers
        ..set(
          HttpHeaders.contentTypeHeader,
          _types[ext] ?? 'application/octet-stream',
        )
        ..set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..set('x-content-type-options', 'nosniff');
      res.contentLength = data.lengthInBytes;
      if (req.method == 'GET') {
        res.add(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }
    } finally {
      await res.close();
    }
  }

  Future<void> close() => _server.close(force: true);
}

/// Started by the splash screen; lives for the whole app session.
final localAssetServerProvider = FutureProvider<LocalAssetServer>((ref) async {
  final server = await LocalAssetServer.start();
  ref.onDispose(server.close);
  return server;
});
