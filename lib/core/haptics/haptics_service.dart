import 'dart:async';

import 'package:flutter/services.dart';
import 'package:winklo/domain/repositories/haptics_settings_repository.dart';

/// How strong a buzz is, weakest first.
enum HapticKind {
  /// A cell added to a path or a digit placed.
  tick,

  /// A light tap, e.g. the time landing on Results.
  light,

  /// A step done: a found word, a number reached, a completed row.
  success,

  /// The puzzle is solved.
  win,
}

/// Vibration feedback, off when the player turns it off in Profile.
class HapticsService {
  HapticsService({
    required HapticsSettingsRepository settings,
    Future<void> Function(HapticKind kind)? perform,
    DateTime Function()? now,
  }) : _settings = settings,
       _perform = perform ?? _platformHaptic,
       _now = now ?? DateTime.now,
       _enabled = settings.isEnabled;

  /// Ticks closer together than this are dropped, so a fast swipe across a
  /// row feels like a ripple instead of one long buzz.
  static const tickGap = Duration(milliseconds: 35);

  final HapticsSettingsRepository _settings;
  final Future<void> Function(HapticKind kind) _perform;
  final DateTime Function() _now;
  bool _enabled;
  DateTime? _lastTickAt;

  bool get isEnabled => _enabled;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _settings.setEnabled(value);
  }

  void play(HapticKind kind) {
    if (!_enabled) return;
    if (kind == HapticKind.tick) {
      final now = _now();
      final last = _lastTickAt;
      // A clock set back (now before last) counts as time passed.
      final gap = last == null ? null : now.difference(last);
      if (gap != null && !gap.isNegative && gap < tickGap) return;
      _lastTickAt = now;
    }
    unawaited(
      _perform(kind).catchError((Object _) {
        // Never break gameplay for a missing or failing vibrator.
      }),
    );
  }

  static Future<void> _platformHaptic(HapticKind kind) => switch (kind) {
    HapticKind.tick => HapticFeedback.selectionClick(),
    HapticKind.light => HapticFeedback.lightImpact(),
    HapticKind.success => HapticFeedback.mediumImpact(),
    HapticKind.win => HapticFeedback.heavyImpact(),
  };
}
