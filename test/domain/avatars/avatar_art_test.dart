import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('every critter has a 100×100 SVG listed in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/avatars/'));
    for (final critter in AvatarCritter.values) {
      final file = File('assets/avatars/${critter.name}.svg');
      expect(file.existsSync(), isTrue, reason: file.path);
      final svg = file.readAsStringSync();
      expect(svg, contains('viewBox="0 0 100 100"'), reason: file.path);
      expect(svg, contains('xmlns="http://www.w3.org/2000/svg"'));
    }
  });
}
