import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/clients/leaderboard/leaderboard_submit_client.dart';
import 'package:winklo/data/leaderboard_identity.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/data/repositories/league_repository_impl.dart';
import 'package:winklo/domain/leaderboard_limits.dart';
import 'package:winklo/domain/league_code.dart';

/// The leaderboard Worker, the rules and the app each hold a copy of the fair
/// play limits and the entry field lists. A mismatch means the Worker writes
/// what the app can't read, or the rules refuse what the Worker accepts, so
/// pin all three together.
void main() {
  late String rules;
  late String limits;
  late String identity;
  late String days;

  String read(String path) => File(path).readAsStringSync();

  setUpAll(() {
    rules = read('firestore/firestore.rules');
    limits = read('workers/leaderboard/src/limits.ts');
    identity = read('workers/leaderboard/src/identity.ts');
    days = read('workers/leaderboard/src/days.ts');
  });

  /// The body of `export const <name> ... = <open> ... <close>` in [source].
  String tsConst(String source, String name, String open, String close) {
    final start = source.indexOf('export const $name');
    expect(start, isNot(-1), reason: '$name not found');
    final from = source.indexOf(open, start);
    final to = source.indexOf(close, from);
    return source.substring(from + 1, to);
  }

  Set<String> quoted(String text) => RegExp(
    r"'([A-Za-z_]+)'",
  ).allMatches(text).map((m) => m.group(1)!).toSet();

  Map<String, int> numberMap(String text) => {
    for (final m in RegExp(r"'?([a-z_]+)'?\s*:\s*(\d+)").allMatches(text))
      m.group(1)!: int.parse(m.group(2)!),
  };

  int tsNumber(String source, String name) {
    final m = RegExp(
      'export const $name\\s*=\\s*([\\d_]+);',
    ).firstMatch(source);
    expect(m, isNotNull, reason: '$name not found');
    return int.parse(m!.group(1)!.replaceAll('_', ''));
  }

  test('minimum times match in the app, the Worker and the rules', () {
    final worker = numberMap(tsConst(limits, 'MIN_SECONDS', '{', '}'));
    final header = rules.indexOf('function minLeaderboardSeconds(');
    expect(header, isNot(-1));
    final body = rules.substring(header);
    final rulesMap = numberMap(
      body.substring(
        body.indexOf('{', body.indexOf('return')),
        body.indexOf('}['),
      ),
    );
    expect(worker, leaderboardMinSeconds);
    expect(rulesMap, leaderboardMinSeconds);
    expect(tsNumber(limits, 'MAX_SECONDS'), leaderboardMaxSeconds);
  });

  test('the live window matches in the app, the Worker and the rules', () {
    expect(
      tsNumber(days, 'LIVE_FROM_HOURS_BEFORE'),
      leaderboardLiveFromHoursBefore,
    );
    expect(
      tsNumber(days, 'LIVE_UNTIL_HOURS_AFTER'),
      leaderboardLiveUntilHoursAfter,
    );
    final header = rules.indexOf('function leaderboardDayIsLive(');
    expect(header, isNot(-1));
    final body = rules.substring(header, rules.indexOf('\n    }', header));
    expect(
      body,
      contains("- duration.value($leaderboardLiveFromHoursBefore, 'h')"),
    );
    expect(
      body,
      contains("+ duration.value($leaderboardLiveUntilHoursAfter, 'h')"),
    );
  });

  test('the Worker writes the entry fields the app and rules know', () {
    expect(quoted(tsConst(limits, 'ENTRY_FIELDS', '[', ']')), {
      ...leaderboardFirestoreKeys,
    });
    expect(quoted(tsConst(limits, 'WEEKLY_FIELDS', '[', ']')), {
      ...weeklyLeaderboardFields,
    });
  });

  test('the Worker cleans identity like the app', () {
    final pattern = RegExp(
      r"export const PHOTO_URL_PATTERN =\s*'([^']+)';",
    ).firstMatch(identity)?.group(1);
    expect(pattern, leaderboardPhotoUrlPattern);
    expect(
      tsNumber(identity, 'DISPLAY_NAME_MAX_LENGTH'),
      leaderboardDisplayNameMaxLength,
    );
    expect(
      tsNumber(identity, 'AVATAR_ID_MAX_LENGTH'),
      leaderboardAvatarIdMaxLength,
    );
  });

  test('the Worker serves the three leaderboard games', () {
    expect(quoted(tsConst(limits, 'GAMES', '[', ']')), {
      ...leaderboardMinSeconds.keys,
    });
  });

  test('phase 1: direct leaderboard writes are still allowed', () {
    expect(
      RegExp(
        r'function directLeaderboardWritesAllowed\(\) \{\s*return true;\s*\}',
      ).hasMatch(rules),
      isTrue,
    );
  });

  test('league docs, codes and limits match the rules', () {
    final header = rules.indexOf('function validLeagueCreate(');
    expect(header, isNot(-1));
    final keys = RegExp(
      r'hasOnly\(\[([^\]]*)\]\)',
    ).firstMatch(rules.substring(header))!.group(1)!;
    expect(quoted(keys), leagueFirestoreKeys);
    expect(
      rules,
      contains("code.matches('^[$leagueCodeAlphabet]{$leagueCodeLength}\$')"),
    );
    expect(rules, contains('after.size() <= $leaguesMaxMembers'));
    expect(rules, contains('name.size() <= $leagueNameMaxLength'));
  });

  test('the app knows every refusal the Worker can answer', () {
    final submit = read('workers/leaderboard/src/submit.ts');
    final start = submit.indexOf('export type SubmitErrorCode =');
    expect(start, isNot(-1));
    final union = submit.substring(start, submit.indexOf(';', start));
    expect(quoted(union), isNotEmpty);
    expect(
      read('workers/leaderboard/src/index.ts'),
      contains("'unauthorized'"),
    );
    expect({...quoted(union), 'unauthorized'}, leaderboardSubmitRefusalCodes);
  });
}
