import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/stable_seed.dart';

void main() {
  test('matches the FNV-1a reference values', () {
    expect(stableSeed(''), 0x811c9dc5);
    expect(stableSeed('a'), 0xe40c292c);
    expect(stableSeed('foobar'), 0xbf9cf968);
  });

  test('is the same for the same key and differs between days', () {
    expect(stableSeed('20261010:6'), stableSeed('20261010:6'));
    expect(stableSeed('20261010:6'), isNot(stableSeed('20261011:6')));
  });
}
