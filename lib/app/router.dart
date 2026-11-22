import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/map/map_screen.dart';
import '../features/seat_picker/seat_picker_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/stadium3d/intro_screen.dart';
import '../features/ticket/ticket_screen.dart';
import 'routes.dart';

export 'routes.dart';

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) => _fade(state, const SplashScreen()),
      ),
      GoRoute(
        path: Routes.intro,
        pageBuilder: (context, state) => _fade(state, const IntroScreen()),
      ),
      GoRoute(
        path: Routes.map,
        pageBuilder: (context, state) => _fade(state, const MapScreen()),
      ),
      GoRoute(
        path: '/match/:matchId/seats',
        pageBuilder: (context, state) => _fade(
          state,
          SeatPickerScreen(matchId: state.pathParameters['matchId']!),
        ),
      ),
      GoRoute(
        path: '/ticket/:ticketId',
        pageBuilder: (context, state) => _fade(
          state,
          TicketScreen(ticketId: state.pathParameters['ticketId']!),
        ),
      ),
    ],
  );
});
