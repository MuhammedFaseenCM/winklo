import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

/// Counts from 0 to [timeSeconds] and formats with [AppStrings.formatPlayTime].
class CountingPlayTime extends StatefulWidget {
  const CountingPlayTime({
    super.key,
    required this.timeSeconds,
    required this.style,
    this.textAlign = TextAlign.center,
    this.duration = const Duration(milliseconds: 650),
    this.onCompleted,
  });

  final int timeSeconds;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration duration;
  final VoidCallback? onCompleted;

  @override
  State<CountingPlayTime> createState() => _CountingPlayTimeState();
}

class _CountingPlayTimeState extends State<CountingPlayTime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  var _didComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || _didComplete) return;
      _didComplete = true;
      widget.onCompleted?.call();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final value = (_animation.value * widget.timeSeconds).round();
        return Text(
          AppStrings.formatPlayTime(value),
          textAlign: widget.textAlign,
          style: widget.style,
        );
      },
    );
  }
}
