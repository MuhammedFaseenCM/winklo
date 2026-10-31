import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/logic/level_map.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/level_progress_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';
import '../cubit/level_map_cubit.dart';
import '../logic/level_map_layout.dart';
import 'widgets/level_avatar_pin.dart';
import 'widgets/level_node.dart';
import 'widgets/level_path_painter.dart';
import 'widgets/level_sheet.dart';
import 'widgets/world_backdrop_painter.dart';

/// The Levels tab: Zip's levels on a winding map. [openLevelId] (from
/// `/levels?open=…`, e.g. Results' Next level) opens that level's sheet
/// once the map is loaded.
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key, this.openLevelId});

  final String? openLevelId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LevelMapCubit(
        worlds: context.read<LevelWorldRepository>(),
        progress: context.read<LevelProgressRepository>(),
      )..load(),
      child: _LevelsView(openLevelId: openLevelId),
    );
  }
}

class _LevelsView extends StatefulWidget {
  const _LevelsView({this.openLevelId});

  final String? openLevelId;

  @override
  State<_LevelsView> createState() => _LevelsViewState();
}

class _LevelsViewState extends State<_LevelsView> {
  final _scroll = ScrollController();

  /// The level the view was last placed for (the current one, or the last
  /// when all are cleared); '' when placed with nothing to focus, null
  /// before the first placement.
  String? _placedFor;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Places the view: on the first ready build, and again whenever the
  /// current level changes (a clear moves it on), never for a re-emit
  /// that leaves it where it was. The first placement focuses
  /// [openLevelId] when it's on the map and opens its sheet (or, for a
  /// locked level, says what to clear first); later ones follow the
  /// current level. The focus goes mid-way down the part of the
  /// [viewport] the shell's dock leaves open. The scroll waits for the
  /// frame, when the scroll view has its new extent.
  void _place(LevelMap map, LevelMapLayout layout, double viewport) {
    final currentId =
        map.currentId ??
        (layout.nodes.isEmpty ? null : layout.nodes.last.slot.entry.id);
    final key = currentId ?? '';
    if (key == _placedFor) return;
    final first = _placedFor == null;
    _placedFor = key;
    final open = first && widget.openLevelId != null
        ? map.node(widget.openLevelId!)
        : null;
    final focusId = open != null ? widget.openLevelId! : currentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = focusId == null ? null : layout.centers[focusId];
      if (center != null && _scroll.hasClients) {
        final offset =
            layout.size.height -
            center.dy -
            (viewport + layout.bottomInset) / 2;
        _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
      }
      if (open == null) return;
      if (open.playable) {
        showLevelSheet(context, open);
      } else {
        _showLocked(map);
      }
    });
  }

  void _onTap(LevelMap map, LevelMapNode node) {
    if (node.playable) {
      showLevelSheet(context, node);
    } else {
      _showLocked(map);
    }
  }

  /// Says which level to clear first (the current one).
  void _showLocked(LevelMap map) {
    final current = map.currentId == null ? null : map.node(map.currentId!);
    if (current == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppStrings.levelLocked(current.slot.number))),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZipAtmosphere(
        // The map runs under the shell's glass dock (extendBody puts the
        // dock in padding.bottom); LevelMapLayout keeps its levels above it.
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<LevelMapCubit, LevelMapState>(
            builder: (context, state) {
              final map = state.map;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(stars: map?.stars, maxStars: map?.maxStars),
                  Expanded(
                    child: switch (state.status) {
                      LevelMapStatus.ready => _map(context, map!),
                      // Centred in the part the dock leaves open.
                      final status => SafeArea(
                        top: false,
                        child: switch (status) {
                          LevelMapStatus.unavailable => _Message(
                            text: AppStrings.levelsNeedConnection,
                            onRetry: () => context.read<LevelMapCubit>().load(),
                          ),
                          LevelMapStatus.empty => _Message(
                            text: AppStrings.levelsComingSoon,
                          ),
                          _ => const Center(child: CircularProgressIndicator()),
                        },
                      ),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _map(BuildContext context, LevelMap map) {
    final user = context.read<AuthRepository>().currentUser;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = LevelMapLayout.of(
          map,
          constraints.maxWidth,
          minHeight: constraints.maxHeight,
          bottomInset: MediaQuery.paddingOf(context).bottom,
        );
        _place(map, layout, constraints.maxHeight);
        final current = map.currentId == null
            ? null
            : layout.centers[map.currentId];
        return SingleChildScrollView(
          controller: _scroll,
          reverse: true,
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              children: [
                // Its own layer, so scrolling doesn't repaint the whole map.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            isComplex: true,
                            painter: WorldBackdropPainter(layout.bands),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: LevelPathPainter(layout)),
                        ),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < layout.bands.length; i++)
                  _worldLabel(layout, i),
                for (final node in layout.nodes)
                  _node(map, node, layout.centers[node.slot.entry.id]!),
                if (current != null)
                  Positioned(
                    left: current.dx - LevelAvatarPin.width / 2,
                    top:
                        current.dy -
                        LevelNode.diameter / 2 -
                        LevelAvatarPin.height,
                    child: LevelAvatarPin(user: user),
                  ),
                if (map.allCleared)
                  Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    child: Center(child: _Chip(text: AppStrings.levelAllDone)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// World [i]'s label, on the side of its gate away from the line and
  /// within that half, short of the middle by the pin's half-width (a
  /// level at the middle carries the pin there). It's centred on the gate,
  /// so a taller label grows both ways. The bottom world's "gate" is the
  /// map's bottom edge: its label sits just above the dock's strip.
  Widget _worldLabel(LevelMapLayout layout, int i) {
    final band = layout.bands[i];
    final onRight = layout.labelOnRight(i);
    final label = Align(
      alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
      heightFactor: 1,
      child: _WorldLabel(
        band: band,
        previousLast: i == 0 ? null : layout.bands[i - 1].world.lastNumber,
      ),
    );
    return Positioned(
      left: onRight ? null : 14,
      right: onRight ? 14 : null,
      width: layout.size.width / 2 - 14 - LevelAvatarPin.width / 2 - 4,
      top: i == 0 ? null : band.gateY,
      bottom: i == 0
          ? layout.size.height - band.gateY + layout.bottomInset + 12
          : null,
      child: i == 0
          ? label
          : FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: label,
            ),
    );
  }

  Widget _node(LevelMap map, LevelMapNode node, Offset center) => Positioned(
    left: center.dx - LevelNode.width / 2,
    top: center.dy - LevelNode.diameter / 2,
    child: LevelNode(node: node, onTap: () => _onTap(map, node)),
  );
}

class _Header extends StatelessWidget {
  const _Header({this.stars, this.maxStars});

  final int? stars;
  final int? maxStars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.levelsTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (stars != null && maxStars != null)
                _Chip(icon: AppIcons.star, text: '$stars / $maxStars'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(text: AppStrings.zipTitle, selected: true),
              _Chip(
                text: '${AppStrings.pathWordsTab} · ${AppStrings.levelsSoon}',
              ),
              _Chip(
                text: '${AppStrings.sudokuTitle} · ${AppStrings.levelsSoon}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.icon, this.selected = false});

  final String text;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? ZipColors.ember : ZipColors.paper,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 14, color: ZipColors.star),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? ZipColors.onInk
                  : (icon != null ? ZipColors.star : ZipColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldLabel extends StatelessWidget {
  const _WorldLabel({required this.band, this.previousLast});

  final LevelMapBand band;

  /// The last level of the world below, which opens this one.
  final int? previousLast;

  @override
  Widget build(BuildContext context) {
    final world = band.world;
    final title = AppStrings.levelWorldTitle(
      world.world.order,
      world.world.theme,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ZipColors.ink.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The stars drop under the title when both don't fit, so the
          // title keeps the label's whole width.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!world.open) ...[
                    const AppIcon(
                      AppIcons.lock,
                      size: 13,
                      color: ZipColors.inkSoft,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ZipColors.onInk,
                      ),
                    ),
                  ),
                ],
              ),
              if (world.open)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(
                      AppIcons.star,
                      size: 11,
                      color: ZipColors.star,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${world.stars}/${world.maxStars}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ZipColors.star,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (!world.open && previousLast != null)
            Text(
              AppStrings.levelWorldLocked(previousLast!),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: ZipColors.inkSoft),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: ZipColors.onInk),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const AppIcon(AppIcons.refresh),
                label: Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
