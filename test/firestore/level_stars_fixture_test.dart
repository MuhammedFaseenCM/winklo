import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/level_stars.dart';

/// workers/leaderboard/src/fixtures/level_stars.json is a table of runs and
/// the stars they earn; the Worker's level_stars.test.ts runs the same table
/// against its own starsFor, so the two can't drift apart.
void main() {
  final fixture =
      jsonDecode(
            File(
              'workers/leaderboard/src/fixtures/level_stars.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final raw in fixture['cases'] as List) {
    final c = raw as Map<String, dynamic>;
    test('hints=${c['usedHints']} seconds=${c['seconds']} '
        'target=${c['targetSeconds']} -> ${c['stars']}', () {
      expect(
        starsFor(
          usedHints: c['usedHints'] as bool,
          seconds: c['seconds'] as int,
          targetSeconds: c['targetSeconds'] as int?,
        ),
        c['stars'],
      );
    });
  }
}
