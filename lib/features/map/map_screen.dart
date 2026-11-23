import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/routes.dart';
import '../../data/favourite_team.dart';
import '../../data/models/match.dart';
import '../../data/models/stadium.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/stadia_loader.dart';
import '../../ui/tokens.dart';
import '../matches/upcoming_matches_card.dart';
import 'widgets/gate_markers.dart';
import 'widgets/map_header.dart';
import 'widgets/osm_attribution.dart';
import 'widgets/purple_tiles.dart';
import 'widgets/stadium_marker.dart';
import 'widgets/stadium_sheet.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  /// Another stadium: fly in to it (intro), then its map.
  Future<void> _switchStadium(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final stadiums = await ref.read(stadiumsProvider.future);
    if (!context.mounted) return;
    final id = await StadiumSheet.show(
      context,
      stadiums: stadiums,
      current: current,
    );
    if (id == null || id == current || !context.mounted) return;
    ref.read(currentStadiumIdProvider.notifier).select(id);
    context.go(Routes.intro);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stadium = ref.watch(stadiumProvider);
    final favourite = ref.watch(favouriteTeamProvider);
    final team = ref
        .watch(teamsProvider)
        .value
        ?.where((t) => t.id == favourite)
        .firstOrNull;
    return Scaffold(
      backgroundColor: StadiaColors.page,
      body: switch (stadium) {
        AsyncData(:final value) => _StadiumMap(
          stadium: value,
          team: team,
          onChangeTeam: () => context.go(Routes.team),
          onChangeStadium: () => _switchStadium(context, ref, value.id),
        ),
        AsyncError(:final error) => Center(
          child: Text('$error', style: StadiaText.body),
        ),
        _ => const Center(child: TrackLoader(width: 96)),
      },
    );
  }
}

class _StadiumMap extends StatefulWidget {
  const _StadiumMap({
    required this.stadium,
    required this.team,
    required this.onChangeTeam,
    required this.onChangeStadium,
  });

  final Stadium stadium;
  final Team? team;
  final VoidCallback onChangeTeam;
  final VoidCallback onChangeStadium;

  @override
  State<_StadiumMap> createState() => _StadiumMapState();
}

class _StadiumMapState extends State<_StadiumMap>
    with SingleTickerProviderStateMixin {
  static const _focusZoom = 15.6;

  final _map = MapController();

  /// Created eagerly: a lazy `late final` would first be built inside
  /// dispose() when the user never re-centred, and creating a ticker on a
  /// deactivated element throws.
  late final AnimationController _fly;

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  LatLng get _stadiumPoint =>
      LatLng(widget.stadium.location.lat, widget.stadium.location.lng);

  /// Keeps the stadium visible above the bottom matches card.
  EdgeInsets _focusPadding(BuildContext context) {
    final media = MediaQuery.of(context);
    return EdgeInsets.only(
      top: media.padding.top + 90,
      bottom: UpcomingMatchesCard.estimatedHeight + media.padding.bottom + 40,
      left: 40,
      right: 40,
    );
  }

  CameraFit _focusFit(BuildContext context) => CameraFit.coordinates(
    coordinates: [_stadiumPoint],
    padding: _focusPadding(context),
    maxZoom: _focusZoom,
    minZoom: _focusZoom,
  );

  void _recenter() {
    final camera = _map.camera;
    final target = _focusFit(context).fit(camera);
    final centre = LatLngTween(begin: camera.center, end: target.center);
    final zoom = Tween<double>(begin: camera.zoom, end: target.zoom);
    final curve = CurvedAnimation(parent: _fly, curve: Curves.easeInOutCubic);
    void tick() => _map.move(centre.evaluate(curve), zoom.evaluate(curve));
    _fly
      ..addListener(tick)
      ..forward(from: 0).whenCompleteOrCancel(() => _fly.removeListener(tick));
  }

  @override
  void dispose() {
    _fly.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stadium;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: _focusFit(context),
              minZoom: 5,
              maxZoom: 18.5,
              backgroundColor: StadiaColors.page,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dz.stadia.app',
                tileBuilder: purpleTileBuilder,
              ),
              GateMarkersLayer(gates: s.gates),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _stadiumPoint,
                    width: StadiumMarker.size.width,
                    height: StadiumMarker.size.height,
                    alignment: Alignment.topCenter,
                    child: StadiumMarker(
                      name: s.name,
                      caption:
                          '${context.l10n.seatCount(s.capacity, StadiaFormat.of(context).count(s.capacity))} · ${s.city}',
                      onTap: _recenter,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child:
                MapHeader(
                      city: s.city,
                      team: widget.team,
                      onRecenter: _recenter,
                      onChangeStadium: widget.onChangeStadium,
                      onChangeTeam: widget.onChangeTeam,
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .moveY(begin: -12, curve: StadiaMotion.emphasized),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(
                  end: StadiaSpace.gutter,
                  bottom: 8,
                ),
                child: OsmAttribution(),
              ),
              const UpcomingMatchesCard()
                  .animate()
                  .fadeIn(delay: 120.ms, duration: 450.ms)
                  .moveY(begin: 40, curve: StadiaMotion.emphasized),
            ],
          ),
        ),
      ],
    );
  }
}
