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
import '../../ui/measure_size.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/step_progress.dart';
import '../../ui/tokens.dart';
import '../stadium3d/stadium_protocol.dart';
import '../stadium3d/stadium_scene_controller.dart';
import '../stadium3d/stadium_view.dart';
import 'booking_controller.dart';
import 'booking_machine.dart';
import 'booking_words.dart';
import 'seat_panel.dart';
import 'widgets/selection_card.dart';

/// Stand -> Block -> Seat -> Buy over the interactive 3D stadium. At Buy the
/// camera sits in the chosen seat (the live, full-screen view from it) and
/// the seat panel slides up in this screen's own tree, not a modal.
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
  String? _toast;
  Timer? _toastTimer;
  final _topCardKey = GlobalKey();
  final _bottomKey = GlobalKey();
  Timer? _insetsTimer;
  (double, double)? _insets;
  var _panelKey = GlobalKey<SeatPanelState>();

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
      case SceneIntroDone() || SceneStats():
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
  /// frames stands / blocks / the view from the seat in the visible middle.
  void _reportInsets() {
    if (!mounted) return;
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

  /// Re-measure once the bottom card / panel has finished resizing.
  void _measureSoon([Duration wait = const Duration(milliseconds: 420)]) {
    _insetsTimer?.cancel();
    _insetsTimer = Timer(wait, _reportInsets);
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
    if (next.step == BookingStep.buy && previous?.step != BookingStep.buy) {
      // A fresh panel (seat stage, no payment state) for every seat.
      _panelKey = GlobalKey<SeatPanelState>();
    }
    if (stepChanged) {
      _syncStep(next);
      _measureSoon();
    }
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  SeatPanelState? get _panel => _panelKey.currentState;

  void _back() {
    final state = ref.read(bookingControllerProvider(widget.matchId));
    // Checkout steps back to the seat first; nothing leaves while paying.
    if (state.step == BookingStep.buy && (_panel?.handleBack() ?? false)) {
      return;
    }
    if (state.step == BookingStep.stand) {
      context.pop();
    } else {
      _booking.dispatch(const StepBack());
    }
  }

  void _jumpToStep(int index) {
    if (_panel?.busy ?? false) return;
    _booking.dispatch(StepTapped(BookingStep.values[index]));
  }

  void _onTicket(String ticketId) => context.go(Routes.ticket(ticketId));

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
    final seated = state.step == BookingStep.buy && state.seat != null;

    return PopScope(
      canPop: state.step == BookingStep.stand,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
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
                child: viewBuilder(
                  context,
                  _scene,
                  SceneMode.picker,
                  value.stadium.id,
                ),
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
                    cardKey: _topCardKey,
                    title: l10n.match(value.match),
                    subtitle:
                        '${f.matchDate(value.match.kickoff)} · '
                        '${f.time(value.match.kickoff)} · '
                        '${value.stadium.name}',
                    step: state.step,
                    onBack: _back,
                    onStepTap: _jumpToStep,
                    toast: _toast,
                    seated: seated,
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
                    child: MeasureSize(
                      // The panel animates between its stages: follow it.
                      onChange: (_) =>
                          _measureSoon(const Duration(milliseconds: 160)),
                      child: KeyedSubtree(
                        key: _bottomKey,
                        child: AnimatedSwitcher(
                          duration: StadiaMotion.medium,
                          switchInCurve: StadiaMotion.emphasized,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.bottomCenter,
                            children: [...previous, ?current],
                          ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.12),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: seated
                              ? OverScene(
                                  key: const ValueKey('seated'),
                                  child: SeatPanel(
                                    key: _panelKey,
                                    matchId: widget.matchId,
                                    onTicket: _onTicket,
                                  ),
                                )
                              : Column(
                                  key: const ValueKey('picking'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (state.step != BookingStep.stand)
                                      const _Legend().animate().fadeIn(
                                        duration: StadiaMotion.medium,
                                      ),
                                    const SizedBox(height: 10),
                                    OverScene(
                                      child: SelectionCard(
                                        summary: value.machine.summarize(
                                          state,
                                          value.match,
                                        ),
                                        hint: l10n.tapStandHint,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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
    required this.seated,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
  final BookingStep step;
  final VoidCallback onBack;
  final ValueChanged<int> onStepTap;
  final String? toast;

  /// The camera is in the seat: say so, and that the view can be turned.
  final bool seated;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = toast;
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
          OverScene(
            child: GlassSurface(
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
                      labels: [
                        for (final s in BookingStep.values) l10n.step(s),
                      ],
                      current: step.index,
                      onStepTap: onStepTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: StadiaMotion.medium,
            child: note != null
                ? _Pill(
                    key: ValueKey(note),
                    glyph: StadiaGlyph.info,
                    text: note,
                  )
                : seated
                ? _Pill(
                    key: const ValueKey('seated'),
                    glyph: StadiaGlyph.orbit,
                    text: '${l10n.viewFromSeat} · ${l10n.dragToLookAround}',
                    quiet: true,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// A floating note under the top card (toast, or the seat-view hint). It
/// never takes touches: the 3D underneath stays draggable.
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.glyph,
    required this.text,
    this.quiet = false,
  });

  final StadiaGlyph glyph;
  final String text;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(
          child: GlassSurface(
            radius: StadiaRadii.pill,
            shadow: !quiet,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StadiaIcon(glyph, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StadiaText.label.copyWith(
                      fontSize: 13,
                      color: quiet ? StadiaColors.textSecondary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
