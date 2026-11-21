import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/buttons.dart';
import '../../ui/icons.dart';
import '../../ui/tokens.dart';

/// Placeholder until the 3D seat picker lands (milestone 4).
class SeatPickerScreen extends StatelessWidget {
  const SeatPickerScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StadiaSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassIconButton(
                glyph: StadiaGlyph.back,
                semanticLabel: 'Back',
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              const Text('Seat picker', style: StadiaText.display),
              const SizedBox(height: 8),
              Text(matchId, style: StadiaText.body),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
