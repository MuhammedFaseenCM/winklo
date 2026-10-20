import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

/// App builds from before the critters draw a preset from
/// `static/avatars/<id>.png` on R2; these are the files uploaded there.
void main() {
  test('every preset id has a 512×512 critter PNG to upload', () {
    for (final id in AvatarCatalog.presetIds) {
      final file = File('tools/static-assets/avatars/$id.png');
      expect(file.existsSync(), isTrue, reason: file.path);

      final bytes = file.readAsBytesSync();
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: id);
      // IHDR: width and height, big-endian, at bytes 16–23.
      final header = ByteData.sublistView(bytes, 16, 24);
      expect(header.getUint32(0), 512, reason: '$id width');
      expect(header.getUint32(4), 512, reason: '$id height');
      // The old flat blobs were ~2.5 KiB; a critter has far more detail.
      expect(bytes.length, greaterThan(4096), reason: id);
    }
  });

  test('the export script names every id with its critter', () {
    final script = File(
      'tools/static-assets/export_avatar_pngs.sh',
    ).readAsStringSync();
    for (final MapEntry(key: id, value: critter)
        in AvatarCatalog.presets.entries) {
      expect(script, contains('$id:${critter.name}'), reason: id);
    }
  });
}
