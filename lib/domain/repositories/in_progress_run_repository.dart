import '../entities/in_progress_run.dart';

abstract class InProgressRunRepository {
  Future<InProgressRun?> load({required String gameId, required String playId});

  Future<void> save(InProgressRun run);

  Future<void> clear({required String gameId, required String playId});
}
