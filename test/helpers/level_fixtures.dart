import 'package:winklo/domain/entities/level_world.dart';

/// A 3×3 Zip board with a serpentine solution; numbers 1 and 2 at its ends.
Map<String, dynamic> levelBoardJson(String id, {int? targetSeconds}) => {
  'id': id,
  'size': 3,
  'numbers': {'0,0': 1, '2,2': 2},
  'walls': <Object>[],
  'solution': [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
    [1, 1],
    [1, 0],
    [2, 0],
    [2, 1],
    [2, 2],
  ],
  'targetSeconds': ?targetSeconds,
};

String levelId(int world, int n) =>
    'zip_${world}_${n.toString().padLeft(2, '0')}';

Map<String, dynamic> levelWorldJson(
  int order,
  int count, {
  String theme = 'ink',
  int? targetSeconds = 30,
}) => {
  'game': 'zip',
  'order': order,
  'published': true,
  'theme': theme,
  'levels': [
    for (var n = 1; n <= count; n++)
      levelBoardJson(levelId(order, n), targetSeconds: targetSeconds),
  ],
};

LevelWorld levelWorld(
  int order,
  int count, {
  String theme = 'ink',
  int? targetSeconds = 30,
}) => LevelWorld.fromJson(
  'zip_$order',
  levelWorldJson(order, count, theme: theme, targetSeconds: targetSeconds),
);
