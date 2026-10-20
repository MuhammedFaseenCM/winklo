import 'package:flutter/material.dart';

const leaderboardGold = Color(0xFFFFD700);
const leaderboardSilver = Color(0xFFD4DFEB);
const leaderboardBronze = Color(0xFFE28B52);

/// Gold, silver or bronze for podium place [place]; null below the podium.
Color? podiumColor(int place) => switch (place) {
  1 => leaderboardGold,
  2 => leaderboardSilver,
  3 => leaderboardBronze,
  _ => null,
};

/// A drawn medal with [rank] stamped on it: no network image, so it shows
/// offline and in tests.
class MedalCoin extends StatelessWidget {
  const MedalCoin({super.key, required this.rank, this.size = 22});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = podiumColor(rank) ?? leaderboardSilver;
    final light = Color.lerp(base, Colors.white, 0.55)!;
    final dark = Color.lerp(base, Colors.black, 0.3)!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [light, base, dark],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: dark),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$rank',
        textScaler: TextScaler.noScaling,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: size * 0.5,
          height: 1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E293B),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
