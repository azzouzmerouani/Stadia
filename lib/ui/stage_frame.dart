import 'package:flutter/material.dart';

import 'tokens.dart';

/// Window classes. A wide window (a desktop browser, a tablet in
/// landscape) gets a map-app layout: a bar across the top, a side panel on
/// the start side (the right, in Arabic) and the map or the 3D stadium
/// filling the rest. Narrow windows keep the phone layout: the map or the
/// 3D full-bleed under floating cards.
abstract final class StadiaLayout {
  static const wideFrom = 900.0;
  static const topBarHeight = 68.0;

  /// Floating cards of the phone layout stop growing here (tablets in
  /// portrait, narrow browser windows).
  static const cardMaxWidth = 560.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideFrom;

  /// A little narrower on small desktops.
  static double sidebarWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1180 ? 440 : 400;
}

/// A screen built around a stage: the map or the 3D view.
///
/// The stage is always the first child of one [Stack], so it keeps its
/// state (camera, WebView, scene) when the window crosses
/// [StadiaLayout.wideFrom]: only its rectangle changes.
class StageFrame extends StatelessWidget {
  const StageFrame({
    super.key,
    required this.wide,
    required this.stage,
    this.overlay = const [],
    this.topBar,
    this.sidebar,
    this.overStage = const [],
  }) : assert(!wide || (topBar != null && sidebar != null));

  final bool wide;
  final Widget stage;

  /// Narrow: [Stack] children floating over the full-screen stage.
  final List<Widget> overlay;

  /// Wide: the bar across the top.
  final Widget? topBar;

  /// Wide: the panel on the start side.
  final Widget? sidebar;

  /// Wide: [Stack] children floating over the stage's own rectangle.
  final List<Widget> overStage;

  @override
  Widget build(BuildContext context) {
    final top = wide
        ? StadiaLayout.topBarHeight + MediaQuery.paddingOf(context).top
        : 0.0;
    final side = wide ? StadiaLayout.sidebarWidth(context) : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        PositionedDirectional(
          key: const ValueKey('stage'),
          top: top,
          start: side,
          end: 0,
          bottom: 0,
          child: stage,
        ),
        if (wide) ...[
          if (overStage.isNotEmpty)
            PositionedDirectional(
              top: top,
              start: side,
              end: 0,
              bottom: 0,
              child: Stack(children: overStage),
            ),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            height: top,
            child: topBar!,
          ),
          PositionedDirectional(
            top: top,
            start: 0,
            bottom: 0,
            width: side,
            child: sidebar!,
          ),
        ] else
          ...overlay,
      ],
    );
  }
}

/// The bar across the top of a wide window.
class WideTopBar extends StatelessWidget {
  const WideTopBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: StadiaColors.purple100,
        border: Border(bottom: BorderSide(color: StadiaColors.glassBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      ),
    );
  }
}

/// The side panel of a wide window.
class WideSidebar extends StatelessWidget {
  const WideSidebar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: StadiaColors.purple110,
        border: BorderDirectional(
          end: BorderSide(color: StadiaColors.glassBorder),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x40000000), blurRadius: 24, spreadRadius: -6),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Phone-layout cards stop at [StadiaLayout.cardMaxWidth], centred.
class CardWidth extends StatelessWidget {
  const CardWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: StadiaLayout.cardMaxWidth),
        child: child,
      ),
    );
  }
}
