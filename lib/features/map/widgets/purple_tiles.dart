import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Re-tints the standard OpenStreetMap raster tiles into FPL purple:
/// luminance is inverted (so labels turn light) and mapped onto a ramp
/// from purple120 (#1E0021) up to a soft lilac. Pure colour matrix – cheap,
/// no shader.
final ColorFilter purpleTileFilter = () {
  // Per-channel gain applied to inverted luminance, and the purple floor.
  const k = [0.56, 0.40, 0.62];
  const base = [30.0, 0.0, 33.0];
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  List<double> row(int c) => [
    -k[c] * lr,
    -k[c] * lg,
    -k[c] * lb,
    0,
    base[c] + 255 * k[c],
  ];
  return ColorFilter.matrix([
    ...row(0),
    ...row(1),
    ...row(2),
    0, 0, 0, 1, 0, //
  ]);
}();

Widget purpleTileBuilder(BuildContext context, Widget tile, TileImage image) =>
    ColorFiltered(colorFilter: purpleTileFilter, child: tile);
