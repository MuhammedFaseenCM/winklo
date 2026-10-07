import 'package:winklo/core/sfx/sfx_id.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';

class SfxService {
  SfxService({
    required SfxSettingsRepository settings,
    Future<void> Function(SfxId id)? playClip,
    DateTime Function()? now,
    this.rejectCooldown = const Duration(milliseconds: 150),
  }) : _settings = settings,
       _playClip = playClip,
       _now = now ?? DateTime.now,
       _enabled = settings.isEnabled;

  final SfxSettingsRepository _settings;
  final Future<void> Function(SfxId id)? _playClip;
  final DateTime Function() _now;
  final Duration rejectCooldown;

  /// Tap/drag ticks (Zip path, Path Words trace) are muted for now; flip to
  /// re-enable. Success, reject and clear still play.
  static const tapSoundEnabled = false;

  bool _enabled;
  DateTime? _lastRejectAt;

  bool get isEnabled => _enabled;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _settings.setEnabled(value);
  }

  Future<void> play(SfxId id) async {
    if (!_enabled) return;
    if (id == SfxId.tap && !tapSoundEnabled) return;
    if (id == SfxId.reject) {
      final now = _now();
      final last = _lastRejectAt;
      if (last != null && now.difference(last) < rejectCooldown) return;
      _lastRejectAt = now;
    }
    final playClip = _playClip;
    if (playClip == null) return;
    try {
      await playClip(id);
    } catch (_) {
      // Never break gameplay for audio failures.
    }
  }
}
