import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../leaderboard/view/widgets/leaderboard_signed_out_mock.dart';

/// Compact blurred mock board for guest results — tap to claim/save time.
class ResultsBoardTease extends StatelessWidget {
  const ResultsBoardTease({super.key, required this.onTap, this.height = 176});

  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZipColors.glassBorder),
            gradient: ZipColors.cardGradient,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    child: const LeaderboardSignedOutMock(rowCount: 3),
                  ),
                ),
                ColoredBox(color: ZipColors.ink.withValues(alpha: 0.42)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Text(
                      AppStrings.resultsBoardTeaseHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: ZipColors.onInk,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
