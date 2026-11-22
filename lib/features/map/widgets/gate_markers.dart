import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/stadium.dart';
import '../../../ui/tokens.dart';

/// Gate pins around the stadium; only shown once the user is zoomed in.
class GateMarkersLayer extends StatelessWidget {
  const GateMarkersLayer({super.key, required this.gates, this.minZoom = 16.4});

  final List<Gate> gates;
  final double minZoom;

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    final visible = zoom >= minZoom;
    return AnimatedOpacity(
      duration: StadiaMotion.medium,
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: MarkerLayer(
          markers: [
            for (final g in gates)
              Marker(
                point: LatLng(g.position.lat, g.position.lng),
                child: Semantics(
                  label: g.name,
                  child: Container(
                    decoration: BoxDecoration(
                      color: StadiaColors.purple100,
                      shape: BoxShape.circle,
                      border: Border.all(color: StadiaColors.white, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      g.id,
                      style: StadiaText.caption.copyWith(
                        color: StadiaColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
