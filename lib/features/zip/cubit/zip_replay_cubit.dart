import 'package:bloc/bloc.dart';

import '../../../domain/entities/zip_level.dart';
import '../logic/path_validator.dart';

class ZipReplayState {
  const ZipReplayState({this.available = false, this.playing = false});

  /// There is a saved winning path to replay. Without one, review shows the
  /// setter's solution, which isn't the player's path.
  final bool available;

  /// The board is drawing the path right now.
  final bool playing;

  @override
  bool operator ==(Object other) =>
      other is ZipReplayState &&
      other.available == available &&
      other.playing == playing;

  @override
  int get hashCode => Object.hash(available, playing);

  @override
  String toString() =>
      'ZipReplayState(available: $available, playing: $playing)';
}

/// Whether a reviewed Zip can replay the player's saved path, and whether it
/// is replaying. The board only draws; this stays the source of truth.
class ZipReplayCubit extends Cubit<ZipReplayState> {
  ZipReplayCubit({required ZipLevel level, required List<Cell> savedPath})
    : path = List<Cell>.unmodifiable(savedPath),
      super(
        ZipReplayState(
          available:
              savedPath.isNotEmpty && PathValidator(level).isWon(savedPath),
        ),
      );

  /// The saved path, in the order it was drawn.
  final List<Cell> path;

  /// Marks the replay as playing. False when there is nothing to replay or
  /// one is already playing, so the board isn't asked twice.
  bool start() {
    if (isClosed || !state.available || state.playing) return false;
    emit(const ZipReplayState(available: true, playing: true));
    return true;
  }

  /// The board's one-shot callback once the path is fully drawn again.
  void finished() {
    if (isClosed || !state.playing) return;
    emit(const ZipReplayState(available: true));
  }
}
