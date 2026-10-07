import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/data/repositories/progress_remote_repository_impl.dart';

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

  test('leaderboard whitelist equals the client payload keys', () {
    expect(
      _rulesWhitelist(rules, 'validLeaderboardKeys'),
      leaderboardFirestoreKeys,
    );
  });
}
