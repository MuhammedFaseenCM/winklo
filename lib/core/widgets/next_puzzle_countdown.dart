import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/play_period.dart';
import '../strings/app_strings.dart';

/// "New puzzle in 6h 12m" until the next play period starts, then "A new
/// puzzle is ready". Rebuilds only when the shown minute changes.
class NextPuzzleCountdown extends StatefulWidget {
  const NextPuzzleCountdown({
    super.key,
    required this.period,
    this.periodOf,
    this.clock = DateTime.now,
    this.style,
    this.textAlign,
    this.maxLines = 1,
  });

  final Duration period;

  /// A moment in the period being counted down; defaults to now. Results
  /// pass the run's day, so a run finished after midnight says the next
  /// puzzle is already out.
  final DateTime? periodOf;
  final DateTime Function() clock;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Lines before the text ellipsizes; long languages may want two.
  final int maxLines;

  @override
  State<NextPuzzleCountdown> createState() => _NextPuzzleCountdownState();
}

class _NextPuzzleCountdownState extends State<NextPuzzleCountdown> {
  late final DateTime _target = PlayPeriod.nextStart(
    widget.periodOf ?? widget.clock(),
    widget.period,
  );
  Timer? _timer;

  Duration get _remaining => _target.difference(widget.clock());

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  /// Wakes up when the rounded-up minute drops (or the period ends).
  void _scheduleTick() {
    final remaining = _remaining;
    if (remaining <= Duration.zero) return;
    final intoMinute = Duration(
      microseconds: remaining.inMicroseconds % Duration.microsecondsPerMinute,
    );
    final wait = intoMinute == Duration.zero
        ? const Duration(minutes: 1)
        : intoMinute;
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.newPuzzleIn(_remaining),
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
