import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

/// Covers a game board while its run is paused or the app is in the
/// background, so the clock can't be stopped to study the board (fair play)
/// and the app switcher doesn't show it.
///
/// [playing] is whether a run is under way at all (not loading, finished or
/// in review); [paused] is the run's own state (its clock is stopped).
class PausedBoardCover extends StatefulWidget {
  const PausedBoardCover({
    super.key,
    required this.playing,
    required this.paused,
    required this.child,
    this.onResume,
  });

  final bool playing;
  final bool paused;
  final Widget child;

  /// Tapping the cover resumes the run.
  final VoidCallback? onResume;

  @override
  State<PausedBoardCover> createState() => _PausedBoardCoverState();
}

class _PausedBoardCoverState extends State<PausedBoardCover>
    with WidgetsBindingObserver {
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    final current = WidgetsBinding.instance.lifecycleState;
    _inBackground = current != null && current != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state != AppLifecycleState.resumed;
    if (background != _inBackground && mounted) {
      setState(() => _inBackground = background);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final covered = widget.playing && (widget.paused || _inBackground);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (covered)
          Positioned.fill(
            child: Semantics(
              button: widget.onResume != null,
              label: AppStrings.gamePaused,
              child: GestureDetector(
                key: const Key('paused_board_cover'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onResume,
                child: const ColoredBox(
                  color: ZipColors.ink,
                  child: _PausedLabel(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PausedLabel extends StatelessWidget {
  const _PausedLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.pause_circle_filled_rounded,
            size: 56,
            color: ZipColors.ember,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.gamePaused,
            style: theme.textTheme.titleLarge?.copyWith(
              color: ZipColors.onInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.gamePausedResume,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ZipColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
