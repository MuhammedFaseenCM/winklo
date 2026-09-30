import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/config/static_assets_config.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('maps known preset to R2 image URL', () {
    expect(
      AvatarCatalog.imageUrlFor('preset_01'),
      StaticAssetsConfig.url('avatars/preset_01.png'),
    );
  });

  test('unknown id returns null', () {
    expect(AvatarCatalog.imageUrlFor('nope'), isNull);
  });
}
