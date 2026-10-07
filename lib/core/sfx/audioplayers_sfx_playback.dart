import 'package:audioplayers/audioplayers.dart';
import 'package:winklo/core/sfx/sfx_id.dart';

/// Short SFX: iOS ambient mixes and follows the silent switch; Android
/// sonification does not take exclusive audio focus.
///
/// audioplayers 6.8.1 copies [AudioPlayer.global]'s context into each new
/// Android player and applies the iOS session globally, so one global set
/// before [AudioPlayer] construction is enough. Per-player `setAudioContext`
/// on iOS only repeats that global session.
final AudioContext sfxAudioContext = AudioContext(
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  android: const AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.assistanceSonification,
    audioFocus: AndroidAudioFocus.none,
  ),
);

bool _sfxAudioContextConfigured = false;

Future<void> ensureSfxAudioContext() async {
  if (_sfxAudioContextConfigured) return;
  await AudioPlayer.global.setAudioContext(sfxAudioContext);
  _sfxAudioContextConfigured = true;
}

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
    await ensureSfxAudioContext();
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
