import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

typedef TutorialDemoBuilder =
    Widget Function(BuildContext context, int beat, double beatT);

/// Dimmed card overlay that steps through caption beats over a canned demo.
class GameTutorialOverlay extends StatefulWidget {
  const GameTutorialOverlay({
    super.key,
    required this.title,
    required this.captions,
    required this.demoBuilder,
    required this.onGotIt,
    this.beatDuration = const Duration(milliseconds: 2200),
    this.gotItLabel = AppStrings.tutorialGotIt,
    this.skipLabel = AppStrings.tutorialSkip,
    this.nextLabel = AppStrings.tutorialNext,
  });

  final String title;
  final List<String> captions;
  final TutorialDemoBuilder demoBuilder;
  final VoidCallback onGotIt;
  final Duration beatDuration;
  final String gotItLabel;
  final String skipLabel;
  final String nextLabel;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<String> captions,
    required TutorialDemoBuilder demoBuilder,
    required Future<void> Function() onDismissed,
    Duration beatDuration = const Duration(milliseconds: 2200),
    String gotItLabel = AppStrings.tutorialGotIt,
    String skipLabel = AppStrings.tutorialSkip,
    String nextLabel = AppStrings.tutorialNext,
  }) {
    var completed = false;
    Future<void> completeOnce() async {
      if (completed) return;
      completed = true;
      await onDismissed();
    }

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return GameTutorialOverlay(
          title: title,
          captions: captions,
          demoBuilder: demoBuilder,
          beatDuration: beatDuration,
          gotItLabel: gotItLabel,
          skipLabel: skipLabel,
          nextLabel: nextLabel,
          onGotIt: () => Navigator.of(dialogContext).pop(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ).whenComplete(completeOnce);
  }

  @override
  State<GameTutorialOverlay> createState() => _GameTutorialOverlayState();
}

class _GameTutorialOverlayState extends State<GameTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _step = 0;

  int get _stepCount => widget.captions.isEmpty ? 1 : widget.captions.length;

  bool get _isLastStep => _step >= _stepCount - 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.beatDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant GameTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beatDuration != widget.beatDuration) {
      _controller.duration = widget.beatDuration;
      if (!_controller.isAnimating) _controller.repeat();
    }
    if (oldWidget.captions.length != widget.captions.length) {
      _step = _step.clamp(0, _stepCount - 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_isLastStep) return;
    setState(() => _step++);
    _controller
      ..stop()
      ..value = 0
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: ZipColors.wall,
            elevation: 8,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final beat = _step;
                    final beatT = _controller.value;
                    final caption = widget.captions.isEmpty
                        ? ''
                        : widget.captions[beat];

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: ZipColors.onInk,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: widget.demoBuilder(context, beat, beatT),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            caption,
                            key: ValueKey(caption),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: ZipColors.onInk,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (_stepCount > 1) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _stepCount; i++) ...[
                                if (i > 0) const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _step
                                        ? ZipColors.sky
                                        : ZipColors.outlineQuiet,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (_isLastStep)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: widget.onGotIt,
                              child: Text(widget.gotItLabel),
                            ),
                          )
                        else
                          Row(
                            children: [
                              TextButton(
                                onPressed: widget.onGotIt,
                                child: Text(widget.skipLabel),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _goNext,
                                  child: Text(widget.nextLabel),
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
