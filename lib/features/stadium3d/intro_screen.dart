import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/tokens.dart';
import '../../ui/wordmark.dart';
import 'stadium_protocol.dart';
import 'stadium_scene_controller.dart';
import 'stadium_view.dart';

/// Cinematic fly-in over the 3D stadium, floodlights switching on. Leaves
/// for the map when the scene reports `introDone`, on Skip, or on the
/// failsafes (scene never ready / intro never finishes).
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  static const loadTimeout = Duration(seconds: 12);
  static const playTimeout = Duration(seconds: 9);

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _scene = StadiumSceneController();
  late final StreamSubscription<SceneEvent> _events;
  Timer? _failsafe;
  bool _ready = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _events = _scene.events.listen(_onEvent);
    _scene.init(SceneMode.intro);
    _failsafe = Timer(IntroScreen.loadTimeout, _leave);
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    unawaited(_events.cancel());
    _scene.dispose();
    super.dispose();
  }

  void _onEvent(SceneEvent event) {
    switch (event) {
      case SceneReady():
        _failsafe?.cancel();
        _failsafe = Timer(IntroScreen.playTimeout, _leave);
        setState(() => _ready = true);
      case SceneIntroDone() || SceneError():
        _leave();
      case SceneSelect() || SceneView() || SceneStats():
        break;
    }
  }

  void _skip() {
    _scene.skipIntro();
    _leave();
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    _failsafe?.cancel();
    context.go(Routes.map);
  }

  @override
  Widget build(BuildContext context) {
    final viewBuilder = ref.watch(stadiumViewBuilderProvider);
    final stadium = ref.watch(stadiumProvider).value;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: StadiaColors.page,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: viewBuilder(context, _scene, SceneMode.intro)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  StadiaSpace.lg,
                  StadiaSpace.lg,
                  StadiaSpace.lg,
                  0,
                ),
                child:
                    Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const StadiaWordmark(),
                            const SizedBox(height: 28),
                            if (stadium != null) ...[
                              Text(
                                l10n.matchdayAt,
                                style: StadiaText.overline.copyWith(
                                  color: StadiaColors.green,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(stadium.name, style: StadiaText.display),
                              const SizedBox(height: 6),
                              Text(
                                '${stadium.city} · '
                                '${l10n.seatCount(stadium.capacity, StadiaFormat.of(context).count(stadium.capacity))}',
                                style: StadiaText.body.copyWith(
                                  color: StadiaColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        )
                        .animate()
                        .fadeIn(duration: StadiaMotion.slow)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          curve: StadiaMotion.emphasized,
                        ),
              ),
            ),
          ),
          // Until the scene reports ready (WebView spin-up + model decode).
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: StadiaMotion.slow,
              child: _ready
                  ? const SizedBox.shrink()
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TrackLoader(width: 72),
                          const SizedBox(height: 16),
                          Text(l10n.loadingStadium, style: StadiaText.caption),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: StadiaSpace.lg),
              child: Center(
                child: StadiaButton(
                  label: l10n.skip,
                  variant: StadiaButtonVariant.glass,
                  expand: false,
                  height: 48,
                  trailing: StadiaGlyph.skip,
                  onPressed: _skip,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
