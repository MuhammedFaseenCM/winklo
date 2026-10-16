import 'dart:math';

/// A lowercase UUID v4, the shape of an install ID. The same pattern is in
/// firestore/firestore.rules and workers/activity/src/open.ts;
/// test/firestore/activity_pins_test.dart keeps the three in step.
const installIdPattern =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

final _installId = RegExp(installIdPattern);

bool isInstallId(String value) => _installId.hasMatch(value);

/// A fresh random install ID.
String newInstallId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
