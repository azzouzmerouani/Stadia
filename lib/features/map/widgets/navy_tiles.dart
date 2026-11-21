import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Re-tints the standard OpenStreetMap raster tiles into the Stadia navy
/// palette: luminance is inverted (so labels turn light) and mapped onto a
/// navy ramp. Pure colour matrix – cheap, no shader, no gradient.
final ColorFilter navyTileFilter = () {
  // Per-channel gain applied to inverted luminance, and the navy floor.
  const k = [0.42, 0.55, 0.78];
  const base = [3.7, 15.7, 38.3];
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  List<double> row(int c) =>
      [-k[c] * lr, -k[c] * lg, -k[c] * lb, 0, base[c] + 255 * k[c]];
  return ColorFilter.matrix([
    ...row(0),
    ...row(1),
    ...row(2),
    0, 0, 0, 1, 0, //
  ]);
}();

Widget navyTileBuilder(BuildContext context, Widget tile, TileImage image) =>
    ColorFiltered(colorFilter: navyTileFilter, child: tile);
