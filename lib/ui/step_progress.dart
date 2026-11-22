import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'tokens.dart';

/// Segmented progress bar: one segment per step, labels underneath, filled
/// with FPL's cyan-to-lilac sweep (right-to-left in Arabic). Completed
/// steps are tappable to jump back.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.labels,
    required this.current,
    this.onStepTap,
  });

  final List<String> labels;
  final int current;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.stepProgress(current + 1, labels.length, labels[current]),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _segment(l10n, i)),
          ],
        ],
      ),
    );
  }

  Widget _segment(AppLocalizations l10n, int i) {
    final done = i < current;
    final active = i == current;
    final tappable = done && onStepTap != null;
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: StadiaColors.overlay15),
                AnimatedFractionallySizedBox(
                  duration: StadiaMotion.slow,
                  curve: StadiaMotion.emphasized,
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: done ? 1 : (active ? 0.5 : 0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: StadiaGradients.brand),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: StadiaMotion.medium,
          style: StadiaText.caption.copyWith(
            color: active || done
                ? StadiaColors.white
                : StadiaColors.textTertiary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(labels[i], key: ValueKey('step-$i')),
        ),
      ],
    );
    if (!tappable) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onStepTap!(i),
      child: Semantics(
        button: true,
        label: l10n.backToStep(labels[i]),
        child: child,
      ),
    );
  }
}
