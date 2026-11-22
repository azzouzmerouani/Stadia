import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/models/stadium.dart';
import '../../l10n/l10n.dart';
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
import 'booking_words.dart';
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
  final _topCardKey = GlobalKey();
  final _bottomKey = GlobalKey();
  Timer? _insetsTimer;
  (double, double)? _insets;

  @override
  void initState() {
    super.initState();
    _events = _scene.events.listen(_onSceneEvent);
    _scene.init(SceneMode.picker);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportInsets());
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _insetsTimer?.cancel();
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
            SeatRef.tryParse(id) ?? const SeatRef(blockId: '', row: 0, seat: 0),
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
      ..sendLabels(ctx.stadium)
      ..sendStandAvailability(ctx.stadium, ctx.availability)
      ..sendBlockAvailability(ctx.stadium, ctx.availability);
    _insets = null;
    _reportInsets();
    _syncStep(ref.read(bookingControllerProvider(widget.matchId)));
  }

  /// Tells the scene how much of it the glass cards cover, so the camera
  /// frames stands / blocks / seats in the visible middle.
  void _reportInsets() {
    if (!mounted || _sheetOpen) return;
    final top = _topCardKey.currentContext?.findRenderObject();
    final bottom = _bottomKey.currentContext?.findRenderObject();
    if (top is! RenderBox || bottom is! RenderBox) return;
    if (!top.hasSize || !bottom.hasSize) return;
    final height = MediaQuery.sizeOf(context).height;
    final t = top.localToGlobal(Offset(0, top.size.height)).dy + 8;
    final b = height - bottom.localToGlobal(Offset.zero).dy + 8;
    final next = (t.roundToDouble(), b.roundToDouble());
    if (next == _insets) return;
    _insets = next;
    _scene.setInsets(top: next.$1, bottom: next.$2);
  }

  /// Re-measure once the bottom card has finished resizing.
  void _measureSoon() {
    _insetsTimer?.cancel();
    _insetsTimer = Timer(const Duration(milliseconds: 420), _reportInsets);
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
      final l10n = context.l10n;
      _showToast(switch (next.notice!) {
        BookingNotice.standSoldOut => l10n.standSoldOut,
        BookingNotice.blockSoldOut => l10n.blockSoldOut,
        BookingNotice.seatTaken => l10n.seatTakenNotice,
      });
    }
    final stepChanged =
        previous == null ||
        previous.step != next.step ||
        previous.standId != next.standId ||
        previous.blockId != next.blockId ||
        previous.seat != next.seat;
    if (stepChanged) {
      _syncStep(next);
      _measureSoon();
    }
    if (next.step == BookingStep.buy &&
        previous?.step != BookingStep.buy &&
        !_sheetOpen) {
      unawaited(_openSeatSheet());
    }
  }

  Future<void> _openSeatSheet() async {
    final ctx = ref.read(bookingContextProvider(widget.matchId)).value;
    if (ctx == null) return;
    // The sheet takes over: the cards step aside and it reports its own
    // insets so the camera frames the seat above it.
    setState(() => _sheetOpen = true);
    final ticketId = await ref.read(seatSheetLauncherProvider)(
      context,
      matchId: widget.matchId,
      scene: _scene,
    );
    if (!mounted) return;
    if (ticketId != null) {
      context.go(Routes.ticket(ticketId));
      return;
    }
    setState(() => _sheetOpen = false);
    // Give the camera the picker's framing back now, re-measure once the
    // cards have slid back in.
    if (_insets case (final top, final bottom)) {
      _scene.setInsets(top: top, bottom: bottom);
    }
    _insets = null;
    _measureSoon();
    // Dismissed without buying: back to seat selection.
    if (ref.read(bookingControllerProvider(widget.matchId)).step ==
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
    // Availability refreshed (a sale, a seat taken): repaint the scene.
    ref.listen(bookingContextProvider(widget.matchId), (previous, next) {
      final value = next.value;
      if (_sceneReady && value != null && !identical(value, previous?.value)) {
        _pushAll();
      }
    });
    final viewBuilder = ref.watch(stadiumViewBuilderProvider);
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);

    return PopScope(
      canPop: state.step == BookingStep.stand,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _booking.dispatch(const StepBack());
      },
      child: Scaffold(
        backgroundColor: StadiaColors.page,
        // Data first: a refresh keeps the previous value, so the WebView
        // (and its camera) survives availability reloads.
        body: switch (ctx) {
          AsyncValue(value: final value?) => Stack(
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
                child: _StepAside(
                  hidden: _sheetOpen,
                  offset: const Offset(0, -0.3),
                  child: SafeArea(
                    bottom: false,
                    child: _TopBar(
                      cardKey: _topCardKey,
                      title: l10n.match(value.match),
                      subtitle:
                          '${f.matchDate(value.match.kickoff)} · '
                          '${f.time(value.match.kickoff)} · '
                          '${value.stadium.name}',
                      step: state.step,
                      onBack: _back,
                      onStepTap: (i) =>
                          _booking.dispatch(StepTapped(BookingStep.values[i])),
                      toast: _toast,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StepAside(
                  hidden: _sheetOpen,
                  offset: const Offset(0, 0.3),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: StadiaSpace.md,
                      ),
                      child: Column(
                        key: _bottomKey,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.step != BookingStep.stand)
                            const _Legend().animate().fadeIn(
                              duration: StadiaMotion.medium,
                            ),
                          const SizedBox(height: 10),
                          SelectionCard(
                            summary: value.machine.summarize(
                              state,
                              value.match,
                            ),
                            hint: l10n.tapStandHint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AsyncError(:final error) => Center(
            child: Text('$error', style: StadiaText.body),
          ),
          _ => const _SceneLoading(),
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.cardKey,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.onBack,
    required this.onStepTap,
    required this.toast,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
  final BookingStep step;
  final VoidCallback onBack;
  final ValueChanged<int> onStepTap;
  final String? toast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            key: cardKey,
            shadow: true,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    GlassIconButton(
                      glyph: StadiaGlyph.back,
                      size: 40,
                      onPressed: onBack,
                      semanticLabel: step == BookingStep.stand
                          ? l10n.backToMatches
                          : l10n.back,
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
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: StepProgressBar(
                    labels: [for (final s in BookingStep.values) l10n.step(s)],
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
                        radius: StadiaRadii.pill,
                        shadow: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const StadiaIcon(StadiaGlyph.info, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              toast!,
                              style: StadiaText.label.copyWith(fontSize: 13),
                            ),
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
    final l10n = context.l10n;
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
      radius: StadiaRadii.pill,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(StadiaColors.free, l10n.legendFree),
          item(StadiaColors.limited, l10n.legendFewLeft),
          item(StadiaColors.sold, l10n.legendSold),
        ],
      ),
    );
  }
}

class _SceneLoading extends StatelessWidget {
  const _SceneLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StadiaColors.page,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TrackLoader(width: 96),
            const SizedBox(height: 20),
            Text(context.l10n.loadingStadium, style: StadiaText.label),
          ],
        ),
      ),
    );
  }
}

/// Slides and fades a floating card out of the way (while the seat sheet is
/// open) and ignores touches meanwhile.
class _StepAside extends StatelessWidget {
  const _StepAside({
    required this.hidden,
    required this.offset,
    required this.child,
  });

  final bool hidden;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedSlide(
        offset: hidden ? offset : Offset.zero,
        duration: StadiaMotion.medium,
        curve: StadiaMotion.emphasized,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: StadiaMotion.medium,
          child: child,
        ),
      ),
    );
  }
}
