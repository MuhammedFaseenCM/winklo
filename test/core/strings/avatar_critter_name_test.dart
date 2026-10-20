import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/avatar_critter_name.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('every critter has a distinct, non-empty name', () {
    final names = AvatarCritter.values.map(avatarCritterName).toList();
    expect(names.every((n) => n.isNotEmpty), isTrue);
    expect(names.toSet(), hasLength(AvatarCritter.values.length));
    expect(avatarCritterName(AvatarCritter.fox), 'Fox');
  });
}
