import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/play_period.dart';

abstract class ZipLevelRepository {
  Future<List<ZipLevel>> fetchLevels();
  Future<ZipLevel> fetchDailyLevel(DateTime date, {Duration period = PlayPeriod.daily});
}
