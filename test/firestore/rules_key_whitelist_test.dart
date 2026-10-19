import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/clients/leaderboard/firestore_leaderboard_skip_log.dart';
import 'package:winklo/data/clients/leaderboard/leaderboard_submit_client.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/data/repositories/progress_remote_repository_impl.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';

/// Keys in the first `hasOnly([...])` after `function <name>(` in the rules.
///
/// Fails (rather than passing silently) when the function or its whitelist
/// is renamed or reshaped.
Set<String> _rulesWhitelist(String rules, String function) {
  final header = rules.indexOf('function $function(');
  expect(header, isNot(-1), reason: 'rules function $function not found');
  final list = RegExp(
    r'hasOnly\(\[([^\]]*)\]\)',
  ).firstMatch(rules.substring(header));
  expect(list, isNotNull, reason: 'no hasOnly([...]) in $function');
  final keys = RegExp(
    r"'([A-Za-z_]+)'",
  ).allMatches(list!.group(1)!).map((m) => m.group(1)!).toSet();
  expect(keys, isNotEmpty, reason: 'empty whitelist in $function');
  return keys;
}

/// A key the client writes but the rules lack rejects the whole write in
/// production (the `currentStreak` incident); pin both sides together.
void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore/firestore.rules').readAsStringSync();
  });

  test('game_days whitelist equals the client payload keys', () {
    expect(_rulesWhitelist(rules, 'validGameDay'), gameDayFirestoreKeys);
  });

  test('game_streaks whitelist equals the client payload keys', () {
    expect(_rulesWhitelist(rules, 'validGameStreak'), streakFirestoreKeys);
  });

  test('validGameStreak type-checks freezeCount as an optional 0-2 int', () {
    final header = rules.indexOf('function validGameStreak(');
    final end = rules.indexOf('function gameStreakDoesNotRegress(');
    expect(header, isNot(-1));
    expect(end, greaterThan(header));
    final body = rules.substring(header, end).replaceAll(RegExp(r'\s+'), ' ');
    expect(
      body,
      contains(
        "(!('freezeCount' in data) || (data.freezeCount is int "
        '&& data.freezeCount >= 0 && data.freezeCount <= 2))',
      ),
    );
    // Older builds keep writing the flag, so it stays required.
    expect(body, contains('data.freezeAvailable is bool'));
  });

  test('leaderboard whitelist equals the client payload keys', () {
    expect(
      _rulesWhitelist(rules, 'validLeaderboardKeys'),
      leaderboardFirestoreKeys,
    );
  });

  test('leaderboard_skips whitelist equals the skip log keys', () {
    expect(
      _rulesWhitelist(rules, 'validLeaderboardSkip'),
      leaderboardSkipFirestoreKeys,
    );
  });

  test('leaderboard_skips takes every final refusal code', () {
    final header = rules.indexOf('function validLeaderboardSkip(');
    expect(header, isNot(-1));
    final list = RegExp(
      r'data\.reason in \[([^\]]*)\]',
    ).firstMatch(rules.substring(header));
    expect(list, isNotNull, reason: 'no reason list in validLeaderboardSkip');
    final reasons = RegExp(
      r"'([a-z_]+)'",
    ).allMatches(list!.group(1)!).map((m) => m.group(1)!).toSet();
    // A refused token is retried, then written directly: never final.
    final finalWorkerCodes = leaderboardSubmitRefusalCodes.difference({
      'unauthorized',
    });
    expect(reasons, {
      LeaderboardSubmitRefused.tooFast,
      LeaderboardSubmitRefused.tooSlow,
      LeaderboardSubmitRefused.notLive,
      LeaderboardSubmitRefused.permissionDenied,
      ...finalWorkerCodes,
    });
  });
}
