import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/config/static_assets_config.dart';

void main() {
  test('url joins base and static path', () {
    expect(
      StaticAssetsConfig.url('games/zip_tile.png'),
      '${StaticAssetsConfig.baseUrl}/static/games/zip_tile.png',
    );
  });

  test('url strips leading slashes on relative path', () {
    expect(
      StaticAssetsConfig.url('/medals/medal_gold.png'),
      '${StaticAssetsConfig.baseUrl}/static/medals/medal_gold.png',
    );
  });
}
