/// JSON messages exchanged with the Three.js scene in `assets/web/`.
///
/// Flutter -> JS: `window.stadia.receive(<json>)`
///   {type: "init", mode: "intro" | "picker"}
///   {type: "setStep", step: "stand" | "block" | "seat" | "buy",
///        stand?: "E", block?: "E_104", seat?: "E_104_R12_S7"}
///   {type: "availability", level: "stand" | "block",
///        items: {"E": 0.42, ...}}                    free ratio 0..1
///   {type: "availability", level: "seat", block: "E_104",
///        rows: 24, seats: 30, sold: [0, 5, ...]}     row-major indexes
///   {type: "highlight", id: "Block_E_104" | null}
///   {type: "labels", items: {"N": "North Stand", ...}}
///   {type: "insets", top: 196, bottom: 232}         px hidden by Flutter UI
///   {type: "renderView", seat: "E_104_R12_S7", requestId: "v3"}
///   {type: "skipIntro"}
///
/// JS -> Flutter: `StadiaBridge.postMessage(<json>)`
///   {type: "ready"}
///   {type: "select", level: "stand" | "block" | "seat", id: "..."}
///   {type: "introDone"}
///   {type: "view", requestId: "v3", seat: "...", dataUrl: "data:image/jpeg;base64,..."}
///   {type: "error", message: "..."}
///   {type: "stats", fps: 60, calls: 120, triangles: 40000}
library;

const bridgeChannelName = 'StadiaBridge';

enum SceneMode { intro, picker }

enum SceneLevel { stand, block, seat }

sealed class SceneEvent {
  const SceneEvent();

  static SceneEvent? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'ready':
        return const SceneReady();
      case 'introDone':
        return const SceneIntroDone();
      case 'select':
        final level =
            SceneLevel.values.where((l) => l.name == json['level']).firstOrNull;
        final id = json['id'];
        if (level == null || id is! String) return null;
        return SceneSelect(level, id);
      case 'view':
        final requestId = json['requestId'];
        final dataUrl = json['dataUrl'];
        if (requestId is! String || dataUrl is! String) return null;
        return SceneView(requestId, dataUrl);
      case 'error':
        return SceneError('${json['message']}');
      case 'stats':
        return SceneStats(
          fps: (json['fps'] as num?)?.toDouble() ?? 0,
          calls: (json['calls'] as num?)?.toInt() ?? 0,
          triangles: (json['triangles'] as num?)?.toInt() ?? 0,
        );
    }
    return null;
  }
}

class SceneReady extends SceneEvent {
  const SceneReady();
}

class SceneIntroDone extends SceneEvent {
  const SceneIntroDone();
}

class SceneSelect extends SceneEvent {
  const SceneSelect(this.level, this.id);
  final SceneLevel level;
  final String id;
}

class SceneView extends SceneEvent {
  const SceneView(this.requestId, this.dataUrl);
  final String requestId;
  final String dataUrl;
}

class SceneError extends SceneEvent {
  const SceneError(this.message);
  final String message;
}

class SceneStats extends SceneEvent {
  const SceneStats({
    required this.fps,
    required this.calls,
    required this.triangles,
  });
  final double fps;
  final int calls;
  final int triangles;
}
