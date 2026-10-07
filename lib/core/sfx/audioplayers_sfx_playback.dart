import 'package:audioplayers/audioplayers.dart';
import 'package:winklo/core/sfx/sfx_id.dart';

/// Builds a fire-and-forget playClip for [SfxService].
Future<void> Function(SfxId id) createAudioplayersPlayClip() {
  const paths = {
    SfxId.tap: 'sfx/tap.ogg',
    SfxId.success: 'sfx/success.ogg',
    SfxId.reject: 'sfx/reject.ogg',
    SfxId.clear: 'sfx/clear.ogg',
  };
  return (SfxId id) async {
    final path = paths[id];
    if (path == null) return;
    final player = AudioPlayer();
    try {
      await player.play(AssetSource(path));
      // Detach: let the player finish; dispose after short delay.
      Future<void>.delayed(const Duration(seconds: 2), player.dispose);
    } catch (_) {
      await player.dispose();
      rethrow;
    }
  };
}
