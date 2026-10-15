import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Body of `function <name>(...) { ... }` in the rules (up to its closing
/// brace at two-level indentation).
String _functionBody(String rules, String name) {
  final start = rules.indexOf('function $name(');
  expect(start, isNot(-1), reason: 'rules function $name not found');
  final end = rules.indexOf('\n    }\n', start);
  expect(end, isNot(-1), reason: 'end of $name not found');
  return rules.substring(start, end);
}

/// The one-time history upload (UploadProgressHistory) writes game days from
/// any past period. Pin that `validGameDay` only checks the period id's shape,
/// with no window relative to `request.time`; adding one would reject the
/// upload's batches.
void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore/firestore.rules').readAsStringSync();
  });

  test('game days accept any well-formed past period id', () {
    final body = _functionBody(rules, 'validGameDay');
    expect(body, contains("data.playId.matches('^[0-9]{8}([0-9]{4})?\$')"));
    // Every use of the written playId: its type, its shape and the doc id.
    final playIdChecks = RegExp(
      r'data\.playId[^\n]*',
    ).allMatches(body).map((m) => m.group(0)!.trim()).toList();
    expect(playIdChecks, [
      'data.playId is string',
      "data.playId.matches('^[0-9]{8}([0-9]{4})?\$')",
      'data.playId',
    ]);
  });

  test('game day updates only compare with the stored doc', () {
    final body = _functionBody(rules, 'gameDayDoesNotRegress');
    expect(body, isNot(contains('request.time')));
    expect(body, isNot(contains('playId')));
  });
}
