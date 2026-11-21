import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/availability.dart';
import '../../data/models/stadium.dart';
import '../seat_picker/booking_machine.dart';
import 'stadium_protocol.dart';

typedef ScenePort = void Function(String json);

/// Flutter side of the bridge. Screens talk to this; the WebView widget
/// attaches a [ScenePort] once the scene reports `ready`. Messages sent
/// before that are queued (only the latest of each kind is kept).
class StadiumSceneController {
  ScenePort? _port;
  final _pending = <String, Map<String, Object?>>{};
  final _views = <String, Completer<Uint8List?>>{};
  final _events = StreamController<SceneEvent>.broadcast();
  var _nextRequest = 0;

  /// Every message sent, newest last (handy in tests and debugging).
  @visibleForTesting
  final List<Map<String, Object?>> log = [];

  Stream<SceneEvent> get events => _events.stream;
  bool get isAttached => _port != null;

  void attach(ScenePort port) {
    _port = port;
    final queued = _pending.values.toList();
    _pending.clear();
    for (final m in queued) {
      port(jsonEncode(m));
    }
  }

  void detach() => _port = null;

  void send(Map<String, Object?> message) {
    log.add(message);
    final port = _port;
    if (port == null) {
      final key = message['type'] == 'availability'
          ? 'availability/${message['level']}'
          : '${message['type']}';
      _pending[key] = message;
      return;
    }
    port(jsonEncode(message));
  }

  /// Called by the WebView with the raw JSON posted from JS.
  void handleIncoming(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final event = SceneEvent.fromJson(decoded);
    if (event == null) return;
    if (event is SceneView) {
      _views.remove(event.requestId)?.complete(_decodeDataUrl(event.dataUrl));
    }
    _events.add(event);
  }

  // ------------------------------------------------------------- commands

  void init(SceneMode mode) => send({'type': 'init', 'mode': mode.name});

  void skipIntro() => send({'type': 'skipIntro'});

  void highlight(String? meshName) =>
      send({'type': 'highlight', 'id': meshName});

  void setStep(BookingState state) => send({
        'type': 'setStep',
        'step': state.step.name,
        'stand': state.standId,
        'block': state.blockId,
        'seat': state.seat?.id,
      });

  void sendStandAvailability(Stadium stadium, MatchAvailability a) => send({
        'type': 'availability',
        'level': 'stand',
        'items': {
          for (final s in stadium.stands)
            s.id: _ratio(a.freeInStand(s), s.capacity),
        },
      });

  void sendBlockAvailability(Stadium stadium, MatchAvailability a) => send({
        'type': 'availability',
        'level': 'block',
        'items': {
          for (final b in stadium.blocks)
            b.id: _ratio(a.freeInBlock(b.id), b.capacity),
        },
      });

  void sendSeatAvailability(Block block, MatchAvailability a) => send({
        'type': 'availability',
        'level': 'seat',
        'block': block.id,
        'rows': block.rows,
        'seats': block.seatsPerRow,
        'sold': (a.block(block.id)?.sold.toList() ?? <int>[])..sort(),
      });

  /// Asks the scene to render the view from [seat]; completes with JPEG
  /// bytes, or null on timeout / when no scene is attached.
  Future<Uint8List?> renderSeatView(
    SeatRef seat, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (_port == null) return Future.value();
    final id = 'v${_nextRequest++}';
    final completer = Completer<Uint8List?>();
    _views[id] = completer;
    send({'type': 'renderView', 'seat': seat.id, 'requestId': id});
    return completer.future.timeout(timeout, onTimeout: () {
      _views.remove(id);
      return null;
    });
  }

  void dispose() {
    _port = null;
    for (final c in _views.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _views.clear();
    _events.close();
  }

  static double _ratio(int free, int capacity) =>
      capacity == 0 ? 0 : double.parse((free / capacity).toStringAsFixed(3));

  static Uint8List? _decodeDataUrl(String url) {
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }
}
