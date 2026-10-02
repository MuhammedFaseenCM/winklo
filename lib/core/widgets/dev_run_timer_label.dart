import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../strings/app_strings.dart';

/// Live run clock for debug builds only (release shows nothing).
class DevRunTimerLabel extends StatefulWidget {
  const DevRunTimerLabel({super.key, required this.elapsedMs, this.resumedAt});

  final int elapsedMs;
  final DateTime? resumedAt;

  @override
  State<DevRunTimerLabel> createState() => _DevRunTimerLabelState();
}

class _DevRunTimerLabelState extends State<DevRunTimerLabel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(covariant DevRunTimerLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resumedAt != widget.resumedAt ||
        oldWidget.elapsedMs != widget.elapsedMs) {
      _syncTick();
    }
  }

  void _syncTick() {
    _tick?.cancel();
    _tick = null;
    if (!kDebugMode || widget.resumedAt == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _seconds {
    final resumed = widget.resumedAt;
    final live = resumed == null
        ? 0
        : DateTime.now().difference(resumed).inMilliseconds.clamp(0, 1 << 62);
    return (widget.elapsedMs + live) ~/ 1000;
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        AppStrings.formatPlayTime(_seconds),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
