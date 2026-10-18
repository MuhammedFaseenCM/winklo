import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/repositories/update_banner_snooze_repository.dart';

class UpdateBannerSnoozeRepositoryImpl implements UpdateBannerSnoozeRepository {
  UpdateBannerSnoozeRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  static const key = 'update_banner_snoozed_until';

  @override
  DateTime? snoozedUntil() {
    final Object? raw = _prefs.get(key);
    if (raw is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }

  @override
  Future<void> snoozeUntil(DateTime until) =>
      _prefs.setInt(key, until.millisecondsSinceEpoch);
}
