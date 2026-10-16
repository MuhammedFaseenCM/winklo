import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/activity_install_id.dart';

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
}
