import 'package:flutter/widgets.dart';

import '../theme/app_icons.dart';

/// How strongly a duotone glyph's fill layer shows under its outline.
const double appIconDuotoneOpacity = 0.22;

/// Draws an [AppIcons] glyph. A Phosphor duotone glyph is two font layers,
/// a faint fill under the outline; a plain [Icon] would draw only the
/// outline. The fill is skipped by screen readers, so the icon is read once.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  /// Like [Icon.icon]: null draws nothing, at the icon's size.
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final outline = Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
    final glyph = icon;
    final fill = glyph == null ? null : AppIcons.duotoneFill(glyph);
    if (fill == null) return outline;

    final base =
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: Icon(
            fill,
            size: size,
            color: base.withValues(alpha: base.a * appIconDuotoneOpacity),
          ),
        ),
        outline,
      ],
    );
  }
}
