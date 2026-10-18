import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshot tests render a screen at a phone size and check it lays out
/// without overflow. With `WINKLO_SCREENSHOTS=1` in the environment they also
/// write a PNG to `build/screenshots/` (readable text: Roboto stands in for
/// Lexend, the bundled Noto Sans Malayalam is loaded, and so are the
/// Material icons).
bool get writeScreenshots => Platform.environment['WINKLO_SCREENSHOTS'] == '1';

/// Loads Roboto under the Lexend family names google_fonts uses, and the
/// Material icon font, from the Flutter SDK (no-op when they aren't found),
/// and the app's Noto Sans Malayalam under google_fonts' names for it.
Future<void> loadScreenshotFonts() async {
  Future<void> loadFiles(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  // The Malayalam fallback (app_theme.dart) ships with the app, so it's in
  // the repo: Malayalam screens measure the same here as on a phone.
  await loadFiles('NotoSansMalayalam_regular', [
    'assets/google_fonts/NotoSansMalayalam-Regular.ttf',
  ]);
  await loadFiles('NotoSansMalayalam_700', [
    'assets/google_fonts/NotoSansMalayalam-Bold.ttf',
  ]);

  final fonts = _materialFontsDir();
  if (fonts == null) return;
  Future<void> load(String family, List<String> files) =>
      loadFiles(family, [for (final file in files) '${fonts.path}/$file']);

  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  for (final (variant, file) in [
    ('regular', 'Roboto-Regular.ttf'),
    ('500', 'Roboto-Medium.ttf'),
    ('600', 'Roboto-Medium.ttf'),
    ('700', 'Roboto-Bold.ttf'),
    ('800', 'Roboto-Bold.ttf'),
    ('900', 'Roboto-Black.ttf'),
  ]) {
    await load('Lexend_$variant', [file]);
  }
  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']);
}

Directory? _materialFontsDir() {
  // flutter_tester lives under <flutter>/bin/cache/artifacts/engine/…
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final candidate = Directory('${dir.path}/artifacts/material_fonts');
    if (dir.path.endsWith('bin/cache') && candidate.existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  return null;
}

/// Writes the [boundary] finder's [RepaintBoundary] to
/// `build/screenshots/<name>.png` when [writeScreenshots] is on.
Future<void> saveScreenshot(
  WidgetTester tester,
  Finder boundary,
  String name,
) async {
  if (!writeScreenshots) return;
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  final bytes = await tester.runAsync(() async {
    final image = await render.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final file = File('build/screenshots/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('Screenshot: ${file.absolute.path}');
}
