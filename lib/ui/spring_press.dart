import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Scales its child down on press and springs back with a slight overshoot,
/// driven by a real [SpringSimulation] (velocity is preserved between
/// press and release, so fast taps feel physical).
class SpringPress extends StatefulWidget {
  const SpringPress({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.94,
    this.haptics = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;
  final String? semanticLabel;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 19,
  );

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool get _enabled => widget.onTap != null;

  void _springTo(double target) {
    _scale.animateWith(
      SpringSimulation(_spring, _scale.value, target, _scale.velocity),
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _springTo(widget.pressedScale) : null,
        onTapCancel: _enabled ? () => _springTo(1) : null,
        onTapUp: _enabled ? (_) => _springTo(1) : null,
        onTap: _enabled
            ? () {
                if (widget.haptics) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}
