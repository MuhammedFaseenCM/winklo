import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('each preset staging asset exists and is illustrated', () {
    for (final id in AvatarCatalog.presetIds) {
      final relative = 'tools/static-assets/avatars/$id.png';
      final file = File(relative);
      expect(file.existsSync(), isTrue, reason: relative);

      final bytes = file.readAsBytesSync();
      // Solid-color placeholders are ~70–300 bytes. Flat 512² blob art compresses
      // to a few KiB — still clearly larger than a solid fill.
      expect(
        bytes.length,
        greaterThan(1024),
        reason: '$relative looks like a placeholder (${bytes.length} bytes)',
      );

      // PNG magic
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50); // P
      expect(bytes[2], 0x4E); // N
      expect(bytes[3], 0x47); // G

      expect(AvatarCatalog.imageUrlFor(id), isNotNull, reason: id);
    }
  });
}
