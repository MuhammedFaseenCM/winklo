import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/progress_local_repository.dart';
import 'package:winklo/domain/usecases/forget_account_progress.dart';

class _MockLocal extends Mock implements ProgressLocalRepository {}

class _MockLevels extends Mock implements LevelProgressRepository {}

void main() {
  test('drops both the daily progress and the level progress', () async {
    final local = _MockLocal();
    final levels = _MockLevels();
    when(() => local.forgetUserProgress('u1')).thenAnswer((_) async {});
    when(() => levels.forget('u1')).thenAnswer((_) async {});
    await ForgetAccountProgress(local, levels)('u1');
    verify(() => local.forgetUserProgress('u1')).called(1);
    verify(() => levels.forget('u1')).called(1);
  });

  test('works without a level store', () async {
    final local = _MockLocal();
    when(() => local.forgetUserProgress('u1')).thenAnswer((_) async {});
    await ForgetAccountProgress(local)('u1');
    verify(() => local.forgetUserProgress('u1')).called(1);
  });
}
