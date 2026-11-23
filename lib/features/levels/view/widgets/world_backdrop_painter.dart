import 'package:flutter/rendering.dart';

import '../../logic/level_map_layout.dart';
import 'backdrops/backdrops.dart' as backdrops;

/// Each world's backdrop in its theme (see [backdrops.paintThemeBackdrop]):
/// ink-stone with a vermilion grid (Ink), a night transit map (Metro), and a
/// drawn ground for every other theme; a world not yet open shows its
/// outlines only ("unprinted"). An unknown theme gets the plain app
/// background.
class WorldBackdropPainter extends CustomPainter {
  WorldBackdropPainter(this.bands);

  final List<LevelMapBand> bands;

  static const metroNight = backdrops.metroNight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final band in bands) {
      backdrops.paintThemeBackdrop(
        canvas,
        band.rect,
        band.world.world.theme,
        open: band.world.open,
        seed: band.world.world.order,
      );
    }
  }

  @override
  bool shouldRepaint(WorldBackdropPainter oldDelegate) =>
      !identical(oldDelegate.bands, bands);
}
