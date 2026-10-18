import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';

void main() {
  test('keeps the hint time its clock includes', () {
    const run = InProgressRun(
      gameId: 'zip',
      playId: '20261017',
      elapsedMs: 42000,
      board: {},
      usedHintsThisRun: true,
      hintPenaltySeconds: 30,
    );
    final back = InProgressRun.fromJson(run.toJson());
    expect(back.hintPenaltySeconds, 30);
    expect(back.elapsedMs, 42000);
  });

  test('a run without hint time leaves the key out', () {
    const run = InProgressRun(
      gameId: 'zip',
      playId: '20261017',
      elapsedMs: 1000,
      board: {},
    );
    expect(run.toJson().containsKey('hintPenaltySeconds'), isFalse);
  });

  test('a run saved before hints cost time charged none', () {
    final back = InProgressRun.fromJson(const {
      'gameId': 'zip',
      'playId': '20261017',
      'elapsedMs': 1000,
      'usedHintsThisRun': true,
      'board': <String, dynamic>{},
    });
    expect(back.hintPenaltySeconds, 0);
  });
}
