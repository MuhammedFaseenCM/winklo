import 'package:flutter/material.dart';

import '../theme/app_layout.dart';
import '../theme/app_theme.dart';

/// Soft ink gradient + ambient lighting + faint diagonal path motif behind Zip screens.
class ZipAtmosphere extends StatelessWidget {
  const ZipAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF141F32), ZipColors.ink, Color(0xFF090E18)],
            ),
          ),
        ),
        const Positioned.fill(
          child: CustomPaint(painter: _AtmosphereLightingPainter()),
        ),
        const Positioned.fill(child: CustomPaint(painter: _PathMotifPainter())),
        child,
      ],
    );
  }
}

class _AtmosphereLightingPainter extends CustomPainter {
  const _AtmosphereLightingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Top-right subtle ember glow
    final emberGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              ZipColors.ember.withValues(alpha: 0.11),
              ZipColors.ember.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.88, size.height * 0.08),
              radius: size.width * 0.75,
            ),
          );
    canvas.drawRect(Offset.zero & size, emberGlow);

    // Bottom-left subtle sky glow
    final skyGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              ZipColors.sky.withValues(alpha: 0.07),
              ZipColors.sky.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.12, size.height * 0.88),
              radius: size.width * 0.65,
            ),
          );
    canvas.drawRect(Offset.zero & size, skyGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PathMotifPainter extends CustomPainter {
  const _PathMotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ZipColors.ember.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.75, -20)
      ..lineTo(size.width * 0.75, size.height * 0.22)
      ..lineTo(size.width * 0.35, size.height * 0.22)
      ..lineTo(size.width * 0.35, size.height * 0.48)
      ..lineTo(size.width * 1.05, size.height * 0.48);

    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = ZipColors.onInk.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final path2 = Path()
      ..moveTo(-30, size.height * 0.72)
      ..lineTo(size.width * 0.45, size.height * 0.72)
      ..lineTo(size.width * 0.45, size.height * 1.1);

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Single brand mark used in UI — same asset as launcher / splash.
class ZipMark extends StatelessWidget {
  const ZipMark({super.key, this.size = 56, this.showGlow = true});

  final double size;
  final bool showGlow;

  static const assetPath = 'assets/branding/app_icon.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: showGlow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ZipColors.ember.withValues(alpha: 0.28),
                  blurRadius: size * 0.45,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.32),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class ZipPrimaryButton extends StatelessWidget {
  const ZipPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final isEnabled = onPressed != null;
    final primaryColor = backgroundColor ?? ZipColors.ember;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.space(16)),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: layout.space(18),
                  offset: Offset(0, layout.space(6)),
                ),
              ]
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.space(16)),
          gradient: isEnabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor.withValues(alpha: 0.95),
                    backgroundColor != null
                        ? primaryColor
                        : ZipColors.emberDeep,
                  ],
                )
              : null,
          color: isEnabled ? null : ZipColors.mistDeep,
          border: Border.all(
            color: isEnabled
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: layout.buttonPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(layout.space(16)),
            ),
          ),
          child: icon == null
              ? Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: layout.space(20)),
                    SizedBox(width: layout.space(8)),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class ZipHudPill extends StatelessWidget {
  const ZipHudPill({
    super.key,
    required this.icon,
    required this.label,
    this.emphasize = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        gradient: emphasize
            ? const LinearGradient(
                colors: [ZipColors.emberSoft, Color(0xFF2E1B14)],
              )
            : const LinearGradient(
                colors: [Color(0xFF223049), Color(0xFF1A2438)],
              ),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: emphasize
              ? ZipColors.ember.withValues(alpha: 0.55)
              : ZipColors.outlineQuiet.withValues(alpha: 0.7),
          width: emphasize ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: emphasize
                ? ZipColors.ember.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 14 : 16,
            color: emphasize ? ZipColors.ember : ZipColors.inkSoft,
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? textTheme.labelMedium : textTheme.labelLarge)
                ?.copyWith(
                  color: emphasize ? ZipColors.ember : ZipColors.onInk,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = ZipColors.ember});

  final Color color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 8 + t * 2,
          height: 8 + t * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.55 + t * 0.45),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 + t * 0.3),
                blurRadius: 6 + t * 4,
                spreadRadius: 1 + t,
              ),
            ],
          ),
        );
      },
    );
  }
}
