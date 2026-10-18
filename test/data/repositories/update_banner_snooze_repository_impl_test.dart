import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/update_banner_snooze_repository_impl.dart';

void main() {
  Future<UpdateBannerSnoozeRepositoryImpl> build([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return UpdateBannerSnoozeRepositoryImpl(
      await SharedPreferences.getInstance(),
    );
  }

  test('the banner is not snoozed by default', () async {
    final repo = await build();

    expect(repo.snoozedUntil(), isNull);
  });

  test(
    'stores the end of the snooze under update_banner_snoozed_until',
    () async {
      final repo = await build();
      final until = DateTime.utc(2026, 10, 16, 9, 30);

      await repo.snoozeUntil(until);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('update_banner_snoozed_until'),
        until.millisecondsSinceEpoch,
      );
      expect(repo.snoozedUntil(), until);
    },
  );

  test('reads a stored snooze back', () async {
    final until = DateTime.utc(2026, 10, 16, 9, 30);
    final repo = await build({
      'update_banner_snoozed_until': until.millisecondsSinceEpoch,
    });

    expect(repo.snoozedUntil()!.isAtSameMomentAs(until), isTrue);
  });

  test('ignores a value of the wrong type', () async {
    final repo = await build({'update_banner_snoozed_until': 'tomorrow'});

    expect(repo.snoozedUntil(), isNull);
  });
}
