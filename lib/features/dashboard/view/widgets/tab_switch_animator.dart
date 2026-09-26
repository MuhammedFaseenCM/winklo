import 'package:flutter/material.dart';

/// Fades and lightly slides [child] whenever [index] changes.
///
/// Keeps a single child subtree (e.g. go_router [StatefulNavigationShell] /
/// IndexedStack) so tab state is preserved — only the visibility transform
/// animates.
class TabSwitchAnimator extends StatefulWidget {
  const TabSwitchAnimator({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  final int index;
  final Widget child;
  final Duration duration;

  @override
  State<TabSwitchAnimator> createState() => _TabSwitchAnimatorState();
}

class _TabSwitchAnimatorState extends State<TabSwitchAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = const AlwaysStoppedAnimation<double>(1);
    _slide = const AlwaysStoppedAnimation<Offset>(Offset.zero);
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(TabSwitchAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;

    _direction = widget.index > oldWidget.index ? 1.0 : -1.0;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: Offset(0.08 * _direction, 0),
      end: Offset.zero,
    ).animate(curved);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacity,
          child: SlideTransition(position: _slide, child: child),
        );
      },
      child: widget.child,
    );
  }
}
