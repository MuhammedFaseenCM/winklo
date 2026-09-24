import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Ada', avatarId: 'preset_01');
  late _MockProfileRepository repo;

  setUp(() {
    repo = _MockProfileRepository();
  });

  group('UpdateDisplayName', () {
    test('trims and forwards', () async {
      when(() => repo.updateDisplayName('Ada')).thenAnswer((_) async => user);
      expect(await UpdateDisplayName(repo)('  Ada  '), user);
    });

    test('empty throws Failure', () async {
      expect(() => UpdateDisplayName(repo)('   '), throwsA(isA<Failure>()));
      verifyNever(() => repo.updateDisplayName(any()));
    });

    test('too long throws Failure', () async {
      expect(() => UpdateDisplayName(repo)('a' * 25), throwsA(isA<Failure>()));
    });
  });

  group('UpdateAvatar', () {
    test('preset forwards', () async {
      when(
        () => repo.updateAvatarPreset('preset_02'),
      ).thenAnswer((_) async => user);
      expect(await UpdateAvatar(repo).preset('preset_02'), user);
    });

    test('invalid preset throws before repo', () async {
      expect(() => UpdateAvatar(repo).preset('nope'), throwsA(isA<Failure>()));
      verifyNever(() => repo.updateAvatarPreset(any()));
    });
  });
}
