import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/favourite_team.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/tokens.dart';
import '../../ui/wordmark.dart';
import 'splash_tasks.dart';

/// "Loading the stadium": warms data and the local 3D asset server, then
/// hands over to the next route.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _minimumShow = Duration(milliseconds: 1700);
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    if (_error != null) setState(() => _error = null);
    try {
      final tasks = ref.read(splashTasksProvider);
      await Future.wait([tasks.run(), Future<void>.delayed(_minimumShow)]);
      if (!mounted) return;
      context.go(tasks.nextRoute);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = StadiaFormat.of(context);
    // Name the stadium only once we know which one (a returning fan).
    final stadium = ref.watch(favouriteTeamProvider) == null
        ? null
        : ref.watch(stadiumProvider).value;
    final subtitle =
        _error ??
        (stadium == null
            ? l10n.preparingSeats
            : '${stadium.name} · ${stadium.city} · '
                  '${l10n.seatCount(stadium.capacity, f.count(stadium.capacity))}');
    return Scaffold(
      backgroundColor: StadiaColors.page,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TrackLoader(width: 136)
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 36),
                    Text(
                          _error == null
                              ? l10n.loadingStadium
                              : l10n.somethingWentWrong,
                          style: StadiaText.title,
                        )
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 500.ms)
                        .moveY(begin: 8),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: StadiaMotion.medium,
                      child: Text(
                        subtitle,
                        key: ValueKey(subtitle),
                        textAlign: TextAlign.center,
                        style: StadiaText.body.copyWith(
                          color: StadiaColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _boot,
                        child: Text(l10n.tryAgain, style: StadiaText.label),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(child: StadiaWordmark(size: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
