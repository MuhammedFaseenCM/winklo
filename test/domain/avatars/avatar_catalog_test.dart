import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('maps known preset to asset path', () {
    expect(
      AvatarCatalog.assetPathFor('preset_01'),
      'assets/avatars/preset_01.png',
    );
  });

  test('unknown id returns null', () {
    expect(AvatarCatalog.assetPathFor('nope'), isNull);
  });
}
