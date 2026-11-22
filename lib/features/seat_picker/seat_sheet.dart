import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/stadium.dart';
import '../../data/payment/payment_service.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/glass.dart';
import '../../ui/icons.dart';
import '../../ui/spring_press.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/tokens.dart';
import '../stadium3d/stadium_scene_controller.dart';
import '../ticket/checkout.dart';
import 'booking_controller.dart';
import 'booking_machine.dart';

/// Opens the seat sheet over the 3D view. Completes with the issued ticket
/// id, or null when the fan closed it or chose another seat.
Future<String?> showSeatSheet(
  BuildContext context, {
  required String matchId,
  required StadiumSceneController scene,
}) {
  final topInset = MediaQuery.paddingOf(context).top + 12;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // Light barrier: the seat stays visible above the sheet.
    barrierColor: const Color(0x1F040A16),
    builder: (_) =>
        SeatSheet(matchId: matchId, scene: scene, topInset: topInset),
  );
}

enum _Stage { seat, checkout, taken }

/// Seat details ("View from your seat", block/row/seat/gate/price, VIP)
/// and, on "Buy ticket", the checkout in the same sheet.
class SeatSheet extends ConsumerStatefulWidget {
  const SeatSheet({
    super.key,
    required this.matchId,
    required this.scene,
    this.topInset = 0,
  });

  final String matchId;
  final StadiumSceneController scene;

  /// Screen space above the sheet the scene may use (status bar etc.).
  final double topInset;

  @override
  ConsumerState<SeatSheet> createState() => _SeatSheetState();
}

class _SeatSheetState extends ConsumerState<SeatSheet> {
  var _stage = _Stage.seat;
  var _method = PaymentMethod.cib;
  var _paying = false;
  String? _error;
  String? _refundReference;
  late final SeatRef? _seat;
  Timer? _insetsTimer;
  double? _reportedHeight;

  @override
  void initState() {
    super.initState();
    _seat = ref.read(bookingControllerProvider(widget.matchId)).seat;
  }

  @override
  void dispose() {
    _insetsTimer?.cancel();
    super.dispose();
  }

  BookingController get _booking =>
      ref.read(bookingControllerProvider(widget.matchId).notifier);

  /// Lets the scene frame the seat in the space left above the sheet.
  /// Debounced: the sheet animates its height between stages.
  void _onSize(Size size) {
    _insetsTimer?.cancel();
    _insetsTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      final height = size.height.roundToDouble();
      if (height == _reportedHeight) return;
      _reportedHeight = height;
      widget.scene.setInsets(top: widget.topInset, bottom: height + 8);
    });
  }

  void _anotherSeat() {
    _booking.dispatch(const AnotherSeat());
    Navigator.of(context).pop();
  }

  Future<void> _pay(BookingContext ctx, SeatRef seat, bool vip) async {
    setState(() {
      _paying = true;
      _error = null;
    });
    final outcome = await ref
        .read(checkoutProvider)
        .buy(context: ctx, seat: seat, vip: vip, method: _method);
    if (!mounted) return;
    switch (outcome) {
      case CheckoutDone(:final ticket):
        Navigator.of(context).pop(ticket.id);
      case CheckoutSeatTaken(:final refundReference):
        setState(() {
          _paying = false;
          _stage = _Stage.taken;
          _refundReference = refundReference;
        });
      case CheckoutFailed(:final message):
        setState(() {
          _paying = false;
          _error = message;
        });
      case CheckoutCancelled():
        setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seat = _seat;
    final ctx = ref.watch(bookingContextProvider(widget.matchId)).value;
    final vip = ref.watch(
      bookingControllerProvider(widget.matchId).select((s) => s.vip),
    );
    final block = seat == null ? null : ctx?.stadium.blockById(seat.blockId);
    final stand = block == null ? null : ctx?.stadium.standById(block.standId);
    if (seat == null || ctx == null || block == null || stand == null) {
      return const SizedBox.shrink();
    }
    final quote = OrderQuote.of(ctx, seat, vip: vip);
    final gate =
        ctx.stadium.gateById(vip ? 'E' : stand.gateId) ??
        ctx.stadium.gateById(stand.gateId);

    final Widget content = switch (_stage) {
      _Stage.seat => _SeatStage(
        key: const ValueKey('seat'),
        scene: widget.scene,
        seat: seat,
        stand: stand,
        block: block,
        gateId: gate?.id ?? stand.gateId,
        quote: quote,
        onVip: (v) => _booking.dispatch(VipToggled(v)),
        onAnotherSeat: _anotherSeat,
        onBuy: () => setState(() => _stage = _Stage.checkout),
      ),
      _Stage.checkout => _CheckoutStage(
        key: const ValueKey('checkout'),
        seat: seat,
        stand: stand,
        block: block,
        quote: quote,
        method: _method,
        paying: _paying,
        error: _error,
        onMethod: (m) => setState(() => _method = m),
        onBack: () => setState(() {
          _stage = _Stage.seat;
          _error = null;
        }),
        onPay: () => _pay(ctx, seat, vip),
      ),
      _Stage.taken => _TakenStage(
        key: const ValueKey('taken'),
        refundReference: _refundReference,
        onAnotherSeat: _anotherSeat,
      ),
    };

    return PopScope(
      canPop: !_paying,
      child: _MeasureSize(
        onChange: _onSize,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: GestureDetector(
            // While paying, swallow drags so the sheet can't be pulled away.
            onVerticalDragStart: _paying ? (_) {} : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              child: GlassSurface(
                radius: StadiaRadii.xl,
                blur: 18,
                fill: const Color(0xF00C1D3A),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: AnimatedSize(
                    duration: StadiaMotion.medium,
                    curve: StadiaMotion.emphasized,
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSwitcher(
                      duration: StadiaMotion.medium,
                      switchInCurve: StadiaMotion.emphasized,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.bottomCenter,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- stages

class _SeatStage extends StatelessWidget {
  const _SeatStage({
    super.key,
    required this.scene,
    required this.seat,
    required this.stand,
    required this.block,
    required this.gateId,
    required this.quote,
    required this.onVip,
    required this.onAnotherSeat,
    required this.onBuy,
  });

  final StadiumSceneController scene;
  final SeatRef seat;
  final Stand stand;
  final Block block;
  final String gateId;
  final OrderQuote quote;
  final ValueChanged<bool> onVip;
  final VoidCallback onAnotherSeat;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR SEAT', style: StadiaText.overline),
                  const SizedBox(height: 4),
                  Text(
                    'Row ${seat.row} · Seat ${seat.seat}',
                    style: StadiaText.title,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stand.name} · ${block.tier == 1 ? 'Lower' : 'Upper'} tier',
                    style: StadiaText.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Swap(
                  value: quote.total,
                  child: Text(
                    formatPrice(quote.total),
                    style: StadiaText.number,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quote.vip ? 'incl. VIP' : 'per ticket',
                  style: StadiaText.caption,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SeatView(scene: scene, seat: seat),
        const SizedBox(height: 12),
        _InfoRow(
          cells: [
            ('Block', '${block.number}'),
            ('Row', '${seat.row}'),
            ('Seat', '${seat.seat}'),
            ('Gate', gateId),
          ],
        ),
        const SizedBox(height: 10),
        _VipOption(on: quote.vip, price: quote.vipPrice, onChanged: onVip),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StadiaButton(
                label: 'Another seat',
                variant: StadiaButtonVariant.outline,
                onPressed: onAnotherSeat,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StadiaButton(
                label: 'Buy ticket',
                trailing: StadiaGlyph.arrowRight,
                onPressed: onBuy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutStage extends StatelessWidget {
  const _CheckoutStage({
    super.key,
    required this.seat,
    required this.stand,
    required this.block,
    required this.quote,
    required this.method,
    required this.paying,
    required this.error,
    required this.onMethod,
    required this.onBack,
    required this.onPay,
  });

  final SeatRef seat;
  final Stand stand;
  final Block block;
  final OrderQuote quote;
  final PaymentMethod method;
  final bool paying;
  final String? error;
  final ValueChanged<PaymentMethod> onMethod;
  final VoidCallback onBack;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        const SizedBox(height: 10),
        Row(
          children: [
            GlassIconButton(
              glyph: StadiaGlyph.back,
              size: 38,
              onPressed: paying ? null : onBack,
              semanticLabel: 'Back to seat',
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Checkout', style: StadiaText.headline),
                  SizedBox(height: 2),
                  Text(
                    'Test mode · no card is charged',
                    style: StadiaText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PriceLine(
          title: '${stand.name} · Block ${block.number}',
          subtitle: 'Row ${seat.row} · Seat ${seat.seat}',
          amount: quote.seatPrice,
        ),
        if (quote.vip) ...[
          const SizedBox(height: 10),
          _PriceLine(
            title: 'VIP upgrade',
            subtitle: 'Lounge access · Gate E fast lane',
            amount: quote.vipPrice,
          ),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: StadiaColors.divider),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Total', style: StadiaText.label),
            const Spacer(),
            Text(formatPrice(quote.total), style: StadiaText.number),
          ],
        ),
        const SizedBox(height: 18),
        const Text('PAY WITH', style: StadiaText.overline),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final m in PaymentMethod.values) ...[
              if (m != PaymentMethod.values.first) const SizedBox(width: 10),
              Expanded(
                child: _MethodTile(
                  method: m,
                  selected: m == method,
                  onTap: paying ? null : () => onMethod(m),
                ),
              ),
            ],
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const StadiaIcon(
                StadiaGlyph.info,
                size: 18,
                color: StadiaColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error!,
                  style: StadiaText.body.copyWith(
                    color: StadiaColors.danger,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        StadiaButton(
          label: 'Pay ${formatPrice(quote.total)}',
          loading: paying,
          onPressed: onPay,
        ),
      ],
    );
  }
}

class _TakenStage extends StatelessWidget {
  const _TakenStage({
    super.key,
    required this.refundReference,
    required this.onAnotherSeat,
  });

  final String? refundReference;
  final VoidCallback onAnotherSeat;

  @override
  Widget build(BuildContext context) {
    final money = refundReference == null
        ? 'Nothing was charged.'
        : 'Payment $refundReference will be refunded.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        const SizedBox(height: 18),
        const Center(child: StadiaIcon(StadiaGlyph.seat, size: 30)),
        const SizedBox(height: 12),
        const Text(
          'That seat was just taken',
          textAlign: TextAlign.center,
          style: StadiaText.title,
        ),
        const SizedBox(height: 6),
        Text(
          'Someone booked it a moment before you. $money',
          textAlign: TextAlign.center,
          style: StadiaText.body,
        ),
        const SizedBox(height: 18),
        StadiaButton(label: 'Pick another seat', onPressed: onAnotherSeat),
      ],
    );
  }
}

// -------------------------------------------------------------- pieces

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: StadiaColors.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Cross-fades [child] whenever [value] changes.
class _Swap extends StatelessWidget {
  const _Swap({required this.value, required this.child});

  final Object value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: StadiaMotion.fast,
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

/// The scene rendered from the seat's eye height, pannable sideways.
class _SeatView extends StatefulWidget {
  const _SeatView({required this.scene, required this.seat});

  final StadiumSceneController scene;
  final SeatRef seat;

  @override
  State<_SeatView> createState() => _SeatViewState();
}

class _SeatViewState extends State<_SeatView> {
  static const _height = 164.0;

  Uint8List? _image;
  var _done = false;
  Timer? _delay;
  TransformationController? _pan;

  @override
  void initState() {
    super.initState();
    // Let the sheet slide in first: the render costs a frame.
    _delay = Timer(const Duration(milliseconds: 280), _render);
  }

  Future<void> _render() async {
    final bytes = await widget.scene.renderSeatView(widget.seat);
    if (!mounted) return;
    setState(() {
      _image = bytes;
      _done = true;
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _pan?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Semantics(
      label: 'View from your seat',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(StadiaRadii.md),
        child: SizedBox(
          height: _height,
          child: ColoredBox(
            color: StadiaColors.navy950,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  LayoutBuilder(
                    builder: (context, box) => _panorama(image, box),
                  )
                else
                  Center(
                    child: _done
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StadiaIcon(
                                StadiaGlyph.cube,
                                size: 26,
                                color: StadiaColors.textTertiary,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Preview unavailable',
                                style: StadiaText.caption,
                              ),
                            ],
                          )
                        : const TrackLoader(width: 64),
                  ),
                const Positioned(
                  left: 10,
                  top: 10,
                  child: _Chip(
                    glyph: StadiaGlyph.cube,
                    text: 'View from your seat',
                  ),
                ),
                if (image != null)
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: _Chip(
                      glyph: StadiaGlyph.orbit,
                      text: 'Drag to look around',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The 2:1 render is wider than the box: start centred, pan and pinch.
  Widget _panorama(Uint8List image, BoxConstraints box) {
    final width = math.max(box.maxWidth, box.maxHeight * 2);
    final height = width / 2;
    _pan ??= TransformationController(
      Matrix4.translationValues(
        -(width - box.maxWidth) / 2,
        -(height - box.maxHeight) / 2,
        0,
      ),
    );
    return InteractiveViewer(
      transformationController: _pan,
      constrained: false,
      maxScale: 3,
      child: Image.memory(
        image,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, _) => AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: StadiaMotion.medium,
          child: child,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.glyph, required this.text});

  final StadiaGlyph glyph;
  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xB3071327),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: StadiaColors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StadiaIcon(glyph, size: 13),
              const SizedBox(width: 5),
              Text(
                text,
                style: StadiaText.caption.copyWith(
                  color: StadiaColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.cells});

  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(StadiaRadii.sm + 2),
        border: Border.all(color: StadiaColors.divider),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 28, color: StadiaColors.divider),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cells[i].$1.toUpperCase(),
                    style: StadiaText.overline.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 5),
                  _Swap(
                    value: cells[i].$2,
                    child: Text(
                      cells[i].$2,
                      style: StadiaText.numberSmall.copyWith(fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VipOption extends StatelessWidget {
  const _VipOption({
    required this.on,
    required this.price,
    required this.onChanged,
  });

  final bool on;
  final int price;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      child: SpringPress(
        onTap: () => onChanged(!on),
        pressedScale: 0.98,
        semanticLabel: 'VIP upgrade',
        child: AnimatedContainer(
          duration: StadiaMotion.fast,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: on ? const Color(0x1AFFFFFF) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(StadiaRadii.sm + 2),
            border: Border.all(
              color: on ? const Color(0xB3FFFFFF) : StadiaColors.divider,
            ),
          ),
          child: Row(
            children: [
              const StadiaIcon(StadiaGlyph.crown, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'VIP upgrade',
                        children: [
                          TextSpan(
                            text: '  +${formatPrice(price)}',
                            style: StadiaText.numberSmall.copyWith(
                              fontSize: 13.5,
                              color: StadiaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      style: StadiaText.label,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Lounge access · Gate E fast lane',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StadiaText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Toggle(on: on),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: StadiaMotion.fast,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: on ? StadiaColors.white : const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(13),
      ),
      child: AnimatedAlign(
        duration: StadiaMotion.medium,
        curve: StadiaMotion.emphasized,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: StadiaMotion.fast,
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: on ? StadiaColors.navy900 : StadiaColors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: StadiaText.label),
              const SizedBox(height: 2),
              Text(subtitle, style: StadiaText.caption),
            ],
          ),
        ),
        Text(formatPrice(amount), style: StadiaText.numberSmall),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: SpringPress(
        onTap: onTap,
        pressedScale: 0.97,
        semanticLabel: method.label,
        child: AnimatedContainer(
          duration: StadiaMotion.fast,
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1AFFFFFF) : const Color(0x08FFFFFF),
            borderRadius: BorderRadius.circular(StadiaRadii.sm + 2),
            border: Border.all(
              color: selected ? StadiaColors.white : StadiaColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const StadiaIcon(StadiaGlyph.card),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.label, style: StadiaText.label),
                    const SizedBox(height: 2),
                    Text(
                      method.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StadiaText.caption.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: StadiaMotion.fast,
                opacity: selected ? 1 : 0,
                child: const StadiaIcon(StadiaGlyph.check, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reports its child's size after every layout that changes it.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) => renderObject.onChange = onChange;
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    if (measured == _last) return;
    _last = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}
