import 'package:flutter/material.dart';

import 'tokens.dart';

/// Segmented progress bar: one segment per step, labels underneath.
/// Completed steps are tappable to jump back.
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
    return Semantics(
      label: 'Step ${current + 1} of ${labels.length}: ${labels[current]}',
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _segment(i)),
          ],
        ],
      ),
    );
  }

  Widget _segment(int i) {
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
                const ColoredBox(color: StadiaColors.hairline),
                AnimatedFractionallySizedBox(
                  duration: StadiaMotion.slow,
                  curve: StadiaMotion.emphasized,
                  alignment: Alignment.centerLeft,
                  widthFactor: done ? 1 : (active ? 0.5 : 0),
                  child: const ColoredBox(color: StadiaColors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
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
      child: Semantics(button: true, label: 'Back to ${labels[i]}', child: child),
    );
  }
}
