import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('12 presets, each critter exactly once', () {
    expect(AvatarCatalog.presetIds, hasLength(12));
    expect(AvatarCatalog.presetIds.toSet(), hasLength(12));
    expect(AvatarCatalog.presets.values.toSet(), AvatarCritter.values.toSet());
  });

  test('the original six ids keep working, as related critters', () {
    expect(AvatarCatalog.critterFor('preset_01'), AvatarCritter.fox);
    expect(AvatarCatalog.critterFor('preset_02'), AvatarCritter.panda);
    expect(AvatarCatalog.critterFor('preset_03'), AvatarCritter.cat);
    expect(AvatarCatalog.critterFor('preset_04'), AvatarCritter.bear);
    expect(AvatarCatalog.critterFor('preset_05'), AvatarCritter.owl);
    expect(AvatarCatalog.critterFor('preset_06'), AvatarCritter.bunny);
  });

  test('picker order starts fox, cat, owl', () {
    expect(AvatarCatalog.presetIds.take(3), [
      'preset_01',
      'preset_03',
      'preset_05',
    ]);
  });

  test('asset path for known ids, null otherwise', () {
    expect(AvatarCatalog.assetFor('preset_09'), 'assets/avatars/tiger.svg');
    expect(AvatarCatalog.assetFor('nope'), isNull);
    expect(AvatarCatalog.assetFor(null), isNull);
    expect(AvatarCatalog.critterFor('nope'), isNull);
    expect(AvatarCatalog.isPresetId('preset_12'), isTrue);
    expect(AvatarCatalog.isPresetId('preset_13'), isFalse);
  });
}
