import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/hint_penalty.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

class _CountingQuota implements HintQuotaRepository {
  final Map<String, int> used = {};

  @override
  Future<int> consume(String gameId, String playId) async =>
      used.update('$gameId|$playId', (n) => n + 1, ifAbsent: () => 1);

  @override
  int usedFor(String gameId, String playId) => used['$gameId|$playId'] ?? 0;

  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}

void main() {
  group('HintPenalty.secondsFor', () {
    test('grows by ten seconds a hint', () {
      expect(HintPenalty.secondsFor(1), 10);
      expect(HintPenalty.secondsFor(2), 20);
      expect(HintPenalty.secondsFor(5), 50);
    });

    test('stops growing at a minute', () {
      expect(HintPenalty.secondsFor(6), 60);
      expect(HintPenalty.secondsFor(7), 60);
      expect(HintPenalty.secondsFor(40), 60);
    });

    test('is zero before the first hint', () {
      expect(HintPenalty.secondsFor(0), 0);
      expect(HintPenalty.secondsFor(-1), 0);
    });
  });

  group('HintPenalty.totalSeconds', () {
    test('adds up every hint spent', () {
      expect(HintPenalty.totalSeconds(0), 0);
      expect(HintPenalty.totalSeconds(1), 10);
      expect(HintPenalty.totalSeconds(3), 60);
      // 10 + 20 + 30 + 40 + 50 + 60 + 60
      expect(HintPenalty.totalSeconds(7), 270);
    });
  });

  group('HintPenalty.appliesTo', () {
    test('charges dailies and the archive, not practice', () {
      expect(HintPenalty.appliesTo(PlayMode.daily), isTrue);
      expect(
        HintPenalty.appliesTo(PlayMode.archive(DateTime(2026, 10, 9))),
        isTrue,
      );
      expect(HintPenalty.appliesTo(PlayMode.practice), isFalse);
    });
  });

  group('HintPenalty.nextSeconds', () {
    test('is the cost of the next hint in a charged mode', () {
      expect(HintPenalty.nextSeconds(PlayMode.daily, hintsUsed: 0), 10);
      expect(HintPenalty.nextSeconds(PlayMode.daily, hintsUsed: 2), 30);
    });

    test('is zero in practice', () {
      expect(HintPenalty.nextSeconds(PlayMode.practice, hintsUsed: 4), 0);
    });
  });

  group('HintPenalty.chargedSeconds', () {
    test('is the total in a charged mode and zero in practice', () {
      expect(HintPenalty.chargedSeconds(PlayMode.daily, hintsUsed: 3), 60);
      expect(HintPenalty.chargedSeconds(PlayMode.practice, hintsUsed: 3), 0);
    });
  });

  group('HintPenalty.startClock', () {
    final t0 = DateTime.utc(2026, 10, 17, 9);

    test('starts at zero with no hints counted', () {
      final clock = HintPenalty.startClock(
        at: t0,
        mode: PlayMode.daily,
        hintsUsed: 0,
      );
      expect(clock.elapsedMs, 0);
      expect(clock.resumedAt, t0);
    });

    test('carries the time of hints already counted for the period', () {
      final clock = HintPenalty.startClock(
        at: t0,
        mode: PlayMode.daily,
        hintsUsed: 2,
      );
      expect(clock.elapsedMs, 30000);
      expect(clock.isRunning, isTrue);
    });

    test('practice starts at zero whatever was counted', () {
      final clock = HintPenalty.startClock(
        at: t0,
        mode: PlayMode.practice,
        hintsUsed: 4,
      );
      expect(clock.elapsedMs, 0);
    });
  });

  group('spendHint', () {
    test('counts the hint and prices it by its number', () async {
      final quota = _CountingQuota();
      Future<SpentHint> spend() => spendHint(
        quota: quota,
        mode: PlayMode.daily,
        gameId: 'zip',
        playId: '20261017',
      );

      final first = await spend();
      expect(first.hintsUsed, 1);
      expect(first.penaltySeconds, 10);

      final second = await spend();
      expect(second.hintsUsed, 2);
      expect(second.penaltySeconds, 20);
      expect(quota.usedFor('zip', '20261017'), 2);
    });

    test('practice counts the hint but it costs nothing', () async {
      final quota = _CountingQuota();
      final spent = await spendHint(
        quota: quota,
        mode: PlayMode.practice,
        gameId: 'zip',
        playId: 'practice',
      );
      expect(spent.hintsUsed, 1);
      expect(spent.penaltySeconds, 0);
    });
  });
}
