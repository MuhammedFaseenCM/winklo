import 'dart:convert';
import 'dart:typed_data';

import 'package:winklo/data/repositories/zip_level_repository_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MapAssetBundle extends CachingAssetBundle {
  _MapAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw StateError('Missing test asset: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return bytes.buffer.asByteData();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchLevels falls back to assets when firestore is null', () async {
    final bundle = _MapAssetBundle({
      'assets/zip/levels/level_01.json': jsonEncode({
        'id': 'l2',
        'size': 2,
        'order': 2,
        'numbers': {'0,0': 1},
        'walls': <Object>[],
      }),
      'assets/zip/levels/level_02.json': jsonEncode({
        'id': 'l1',
        'size': 2,
        'order': 1,
        'numbers': {'0,0': 1},
        'walls': <Object>[],
      }),
      'assets/zip/levels/level_03.json': jsonEncode({
        'id': 'l3',
        'size': 2,
        'order': 3,
        'numbers': {'0,0': 1},
        'walls': <Object>[],
      }),
    });

    final repo = ZipLevelRepositoryImpl(firestore: null, assetBundle: bundle);

    final levels = await repo.fetchLevels();
    expect(levels.map((l) => l.id).toList(), ['l1', 'l2', 'l3']);
    expect(levels.map((l) => l.order).toList(), [1, 2, 3]);
  });

  test('fetchDailyLevel falls back to generator when firestore is null', () async {
    final repo = ZipLevelRepositoryImpl(firestore: null);
    final level = await repo.fetchDailyLevel(DateTime(2026, 9, 29));
    expect(level.id, 'daily_20260929');
    expect(level.size, 6);
    expect(level.maxNumber, 6);
  });
}
