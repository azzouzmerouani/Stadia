import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/stadium.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/glass.dart';
import '../../ui/icons.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/step_progress.dart';
import '../../ui/tokens.dart';
import '../stadium3d/stadium_protocol.dart';
import '../stadium3d/stadium_scene_controller.dart';
import '../stadium3d/stadium_view.dart';
import 'booking_controller.dart';
import 'booking_machine.dart';
import 'seat_sheet_launcher.dart';
import 'widgets/selection_card.dart';

/// Stand -> Block -> Seat -> Buy over the interactive 3D stadium.
class SeatPickerScreen extends ConsumerStatefulWidget {
  const SeatPickerScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<SeatPickerScreen> createState() => _SeatPickerScreenState();
}

class _SeatPickerScreenState extends ConsumerState<SeatPickerScreen> {
  final _scene = StadiumSceneController();
  late final StreamSubscription<SceneEvent> _events;
  bool _sceneReady = false;
  bool _sheetOpen = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _events = _scene.events.listen(_onSceneEvent);
    _scene.init(SceneMode.picker);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    unawaited(_events.cancel());
    _scene.dispose();
    super.dispose();
  }

  BookingController get _booking =>
      ref.read(bookingControllerProvider(widget.matchId).notifier);

  // -------------------------------------------------------------- scene IO

  void _onSceneEvent(SceneEvent event) {
    switch (event) {
      case SceneReady():
        setState(() => _sceneReady = true);
        _pushAll();
      case SceneSelect(:final level, :final id):
        _booking.dispatch(switch (level) {
          SceneLevel.stand => StandTapped(id),
          SceneLevel.block => BlockTapped(id),
          SceneLevel.seat => SeatTapped(
              SeatRef.tryParse(id) ??
                  const SeatRef(blockId: '', row: 0, seat: 0),
            ),
        });
      case SceneError(:final message):
        _showToast(message);
      case SceneIntroDone() || SceneView() || SceneStats():
        break;
    }
  }

  /// Sends availability + current step (used once the scene is ready).
  void _pushAll() {
    final ctx = ref.read(bookingContextProvider(widget.matchId)).value;
    if (ctx == null) return;
    _scene
      ..sendStandAvailability(ctx.stadium, ctx.availability)
      ..sendBlockAvailability(ctx.stadium, ctx.availability);
    _syncStep(ref.read(bookingControllerProvider(widget.matchId)));
  }

  void _syncStep(BookingState state) {
    final ctx = ref.read(bookingContextProvider(widget.matchId)).value;
    if (ctx == null) return;
    if (state.blockId case final blockId?) {
      final block = ctx.stadium.blockById(blockId);
      if (block != null) _scene.sendSeatAvailability(block, ctx.availability);
    }
    _scene.setStep(state);
  }

  void _onStateChanged(BookingState? previous, BookingState next) {
    if (next.notice != null && next.notice != previous?.notice) {
      _showToast(switch (next.notice!) {
        BookingNotice.standSoldOut => 'This stand is sold out',
        BookingNotice.blockSoldOut => 'This block is sold out, try another',
        BookingNotice.seatTaken => 'That seat is taken, pick a free one',
      });
    }
    final stepChanged = previous == null ||
        previous.step != next.step ||
        previous.standId != next.standId ||
        previous.blockId != next.blockId ||
        previous.seat != next.seat;
    if (stepChanged) _syncStep(next);
    if (next.step == BookingStep.buy &&
        previous?.step != BookingStep.buy &&
        !_sheetOpen) {
      unawaited(_openSeatSheet());
    }
  }

  Future<void> _openSeatSheet() async {
    final ctx = ref.read(bookingContextProvider(widget.matchId)).value;
    if (ctx == null) return;
    _sheetOpen = true;
    await ref.read(seatSheetLauncherProvider)(
      context,
      matchId: widget.matchId,
      scene: _scene,
    );
    _sheetOpen = false;
    // Dismissed without buying: back to seat selection.
    if (mounted &&
        ref.read(bookingControllerProvider(widget.matchId)).step ==
            BookingStep.buy) {
      _booking.dispatch(const AnotherSeat());
    }
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _back() {
    final state = ref.read(bookingControllerProvider(widget.matchId));
    if (state.step == BookingStep.stand) {
      context.pop();
    } else {
      _booking.dispatch(const StepBack());
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(bookingContextProvider(widget.matchId));
    final state = ref.watch(bookingControllerProvider(widget.matchId));
    ref.listen(bookingControllerProvider(widget.matchId), _onStateChanged);
    final viewBuilder = ref.watch(stadiumViewBuilderProvider);

    return PopScope(
      canPop: state.step == BookingStep.stand,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _booking.dispatch(const StepBack());
      },
      child: Scaffold(
        backgroundColor: StadiaColors.navy900,
        body: switch (ctx) {
          AsyncError(:final error) => Center(
              child: Text('$error', style: StadiaText.body),
            ),
          AsyncData(:final value) => Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: viewBuilder(context, _scene, SceneMode.picker),
                ),
                IgnorePointer(
                  ignoring: _sceneReady,
                  child: AnimatedSwitcher(
                    duration: StadiaMotion.slow,
                    child: _sceneReady
                        ? const SizedBox.shrink()
                        : const _SceneLoading(),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: _TopBar(
                      title: value.match.title,
                      subtitle: '${formatMatchDate(value.match.kickoff)} · '
                          '${formatTime(value.match.kickoff)} · '
                          '${value.stadium.name}',
                      step: state.step,
                      onBack: _back,
                      onStepTap: (i) =>
                          _booking.dispatch(StepTapped(BookingStep.values[i])),
                      toast: _toast,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: StadiaSpace.md,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.step != BookingStep.stand)
                            const _Legend()
                                .animate()
                                .fadeIn(duration: StadiaMotion.medium),
                          const SizedBox(height: 10),
                          SelectionCard(
                            summary: value.machine
                                .summarize(state, value.match),
                            hint: 'Tap a stand to zoom in',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          _ => const _SceneLoading(),
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.step,
    required this.onBack,
    required this.onStepTap,
    required this.toast,
  });

  final String title;
  final String subtitle;
  final BookingStep step;
  final VoidCallback onBack;
  final ValueChanged<int> onStepTap;
  final String? toast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StadiaSpace.md,
        StadiaSpace.sm,
        StadiaSpace.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassSurface(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    GlassIconButton(
                      glyph: StadiaGlyph.back,
                      size: 40,
                      onPressed: onBack,
                      semanticLabel:
                          step == BookingStep.stand ? 'Back to matches' : 'Back',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StadiaText.label,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StadiaText.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: StepProgressBar(
                    labels: [for (final s in BookingStep.values) s.label],
                    current: step.index,
                    onStepTap: onStepTap,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: StadiaMotion.medium,
            child: toast == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(toast),
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: GlassSurface(
                        radius: 999,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const StadiaIcon(StadiaGlyph.info, size: 16),
                            const SizedBox(width: 8),
                            Text(toast!, style: StadiaText.label.copyWith(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: StadiaText.caption.copyWith(fontSize: 12)),
            ],
          ),
        );
    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(StadiaColors.free, 'Free'),
          item(StadiaColors.limited, 'Few left'),
          item(StadiaColors.sold, 'Sold'),
        ],
      ),
    );
  }
}

class _SceneLoading extends StatelessWidget {
  const _SceneLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: StadiaColors.navy900,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrackLoader(width: 96),
            SizedBox(height: 20),
            Text('Loading the stadium', style: StadiaText.label),
          ],
        ),
      ),
    );
  }
}
