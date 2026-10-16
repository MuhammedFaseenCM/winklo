import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/activity_install_id.dart';
import 'package:winklo/data/repositories/activity_repository_impl.dart';

/// The app makes install IDs, the activity Worker checks them and the rules
/// check them again on the signed-in doc. Pin one pattern and one platform
/// list across all three.
void main() {
  late String rules;
  late String worker;

  setUpAll(() {
    rules = File('firestore/firestore.rules').readAsStringSync();
    worker = File('workers/activity/src/open.ts').readAsStringSync();
  });

  test('one install ID pattern', () {
    expect(rules, contains("matches('$installIdPattern')"));
    expect(
      worker,
      contains("export const INSTALL_ID_PATTERN = '$installIdPattern';"),
    );
  });

  test('one platform list', () {
    expect(rules, contains("in ['ios', 'android', 'other']"));
    expect(worker, contains("PLATFORMS = ['ios', 'android', 'other']"));
  });

  test('the app version pattern is the same in the rules and the Worker', () {
    const pattern = r'^[0-9A-Za-z.+-]{1,32}$';
    expect(rules, contains("appVersion.matches('$pattern')"));
    expect(worker, contains('/$pattern/'));
  });

  test('activityKeys() in the rules equals the keys the app writes', () {
    final header = rules.indexOf('function activityKeys(');
    expect(header, isNot(-1));
    final end = rules.indexOf('}', header);
    final keys = RegExp(
      r"'([A-Za-z]+)'",
    ).allMatches(rules.substring(header, end)).map((m) => m.group(1)!).toSet();
    expect(keys, activityFirestoreKeys);
  });
}
