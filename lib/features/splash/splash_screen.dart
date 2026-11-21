import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../ui/format.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/tokens.dart';
import '../../ui/wordmark.dart';
import 'splash_tasks.dart';

/// "Loading the stadium": warms data (and, from milestone 4, the local 3D
/// asset server), then hands over to the next route.
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
    final stadium = ref.watch(stadiumProvider).value;
    final subtitle = _error ??
        (stadium == null
            ? 'Preparing stands, blocks and seats'
            : '${stadium.name} · ${stadium.city} · '
                '${formatCount(stadium.capacity)} seats');
    return Scaffold(
      backgroundColor: StadiaColors.navy900,
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
                          ? 'Loading the stadium'
                          : 'Something went wrong',
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
                        style: StadiaText.body,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _boot,
                        child: const Text('Try again', style: StadiaText.label),
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
