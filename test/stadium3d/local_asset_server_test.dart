import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/features/stadium3d/local_asset_server.dart';
import 'package:stadia/features/stadium3d/stadium_protocol.dart';

/// In-memory bundle so the test needs no binding (the test binding would
/// replace HttpClient with a stub).
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final file = files[key];
    if (file == null) throw StateError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(file)));
  }
}

void main() {
  group('assetKeyFor', () {
    test('maps viewer paths into the two asset folders', () {
      expect(LocalAssetServer.assetKeyFor('/'), 'assets/web/index.html');
      expect(LocalAssetServer.assetKeyFor('/stadium.js'), 'assets/web/stadium.js');
      expect(
        LocalAssetServer.assetKeyFor('/draco/draco_decoder.wasm'),
        'assets/web/draco/draco_decoder.wasm',
      );
      expect(LocalAssetServer.assetKeyFor('/3d/stadium.glb'), 'assets/3d/stadium.glb');
    });

    test('refuses anything that could leave those folders', () {
      expect(LocalAssetServer.assetKeyFor('/../data/matches.json'), isNull);
      expect(LocalAssetServer.assetKeyFor('/%2e%2e/pubspec.yaml'), isNull);
      expect(LocalAssetServer.assetKeyFor('/3d/..%2F..%2Fsecret'), isNull);
      expect(LocalAssetServer.assetKeyFor(r'/..\secret'), isNull);
      expect(LocalAssetServer.assetKeyFor('/%E0%A4%A'), isNull);
    });
  });

  group('server', () {
    late LocalAssetServer server;
    late HttpClient client;

    setUp(() async {
      server = await LocalAssetServer.start(
        bundle: _MapBundle({
          'assets/web/index.html': '<!doctype html><title>Stadia 3D</title>',
          'assets/3d/stadium.glb': 'glTF',
        }),
      );
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    Future<HttpClientResponse> request(
      String path, {
      String method = 'GET',
      String? host,
    }) async {
      final req = await client.openUrl(method, server.origin.replace(path: path));
      if (host != null) req.headers.host = host;
      return req.close();
    }

    test('binds to loopback only', () {
      expect(server.origin.host, '127.0.0.1');
      expect(server.port, greaterThan(0));
    });

    test('serves the viewer page with its content type', () async {
      final res = await request('/index.html');
      expect(res.statusCode, 200);
      expect(res.headers.contentType?.mimeType, 'text/html');
      expect(await res.transform(utf8.decoder).join(), contains('Stadia 3D'));
    });

    test('serves the model from /3d/', () async {
      final res = await request('/3d/stadium.glb');
      expect(res.statusCode, 200);
      expect(res.headers.contentType?.mimeType, 'model/gltf-binary');
      await res.drain<void>();
    });

    test('404 for missing files, 405 for writes, 403 for foreign hosts', () async {
      final missing = await request('/nope.js');
      expect(missing.statusCode, 404);
      await missing.drain<void>();

      final post = await request('/index.html', method: 'POST');
      expect(post.statusCode, 405);
      await post.drain<void>();

      final foreign = await request('/index.html', host: 'evil.example');
      expect(foreign.statusCode, 403);
      await foreign.drain<void>();
    });

    test('page URL carries the scene mode', () {
      final uri = server.page(SceneMode.intro, debug: false);
      expect(uri.path, '/index.html');
      expect(uri.queryParameters, {'mode': 'intro'});
      expect(
        server.page(SceneMode.picker, debug: true).queryParameters,
        {'mode': 'picker', 'debug': '1'},
      );
    });
  });
}
