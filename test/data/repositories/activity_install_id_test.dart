import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/activity_install_id.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  test('makes lowercase UUID v4 ids', () {
    for (var i = 0; i < 200; i++) {
      expect(isInstallId(newInstallId()), isTrue);
    }
  });

  test('sets the version and variant bits whatever the random bytes', () {
    expect(
      newInstallId(_FixedRandom(0xff)),
      'ffffffff-ffff-4fff-bfff-ffffffffffff',
    );
    expect(
      newInstallId(_FixedRandom(0)),
      '00000000-0000-4000-8000-000000000000',
    );
  });

  test('refuses other shapes', () {
    expect(isInstallId(''), isFalse);
    expect(isInstallId('not-an-id'), isFalse);
    expect(isInstallId(newInstallId().toUpperCase()), isFalse);
    expect(isInstallId('3f2b8c1e-9a4d-1e7f-b123-0c9d8e7f6a5b'), isFalse);
  });
}
