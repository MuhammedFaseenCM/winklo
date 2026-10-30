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
  bool _placed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Once, after the map first lays out: scroll to the level to show
  /// ([openLevelId] or the current one) and open its sheet if asked (or,
  /// for a locked level, say what to clear first).
  ///
  /// [_placed] is set when the callback is scheduled, so rebuilds before
  /// that frame don't schedule it twice.
  void _place(LevelMap map, LevelMapLayout layout, double viewport) {
    if (_placed) return;
    _placed = true;
    final focusId = widget.openLevelId ?? map.currentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = focusId == null ? null : layout.centers[focusId];
      if (center != null && _scroll.hasClients) {
        final offset = layout.size.height - center.dy - viewport / 2;
        _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
      }
      final open = widget.openLevelId == null
          ? null
          : map.node(widget.openLevelId!);
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
        child: SafeArea(
          child: BlocBuilder<LevelMapCubit, LevelMapState>(
            builder: (context, state) {
              final map = state.map;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(stars: map?.stars, maxStars: map?.maxStars),
                  Expanded(
                    child: switch (state.status) {
                      LevelMapStatus.loading => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      LevelMapStatus.unavailable => _Message(
                        text: AppStrings.levelsNeedConnection,
                        onRetry: () => context.read<LevelMapCubit>().load(),
                      ),
                      LevelMapStatus.empty => _Message(
                        text: AppStrings.levelsComingSoon,
                      ),
                      LevelMapStatus.ready => _map(context, map!),
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
                  Positioned(
                    // Away from where the line crosses the gate.
                    left: layout.labelOnRight(i) ? null : 14,
                    right: layout.labelOnRight(i) ? 14 : null,
                    // Centred on its gate; the bottom world's "gate" is
                    // the map's bottom edge, so its label sits just above.
                    top: i == 0
                        ? layout.bands[i].gateY - 52
                        : layout.bands[i].gateY - 20,
                    child: _WorldLabel(
                      band: layout.bands[i],
                      previousLast: i == 0
                          ? null
                          : layout.bands[i - 1].world.lastNumber,
                    ),
                  ),
                for (final node in layout.nodes)
                  Positioned(
                    left:
                        layout.centers[node.slot.entry.id]!.dx -
                        LevelNode.width / 2,
                    top:
                        layout.centers[node.slot.entry.id]!.dy -
                        LevelNode.diameter / 2,
                    child: LevelNode(
                      node: node,
                      onTap: () => _onTap(map, node),
                    ),
                  ),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ZipColors.onInk,
                ),
              ),
              if (world.open) ...[
                const SizedBox(width: 8),
                const AppIcon(AppIcons.star, size: 11, color: ZipColors.star),
                const SizedBox(width: 3),
                Text(
                  '${world.stars}/${world.maxStars}',
                  style: const TextStyle(fontSize: 11, color: ZipColors.star),
                ),
              ],
            ],
          ),
          if (!world.open && previousLast != null)
            Text(
              AppStrings.levelWorldLocked(previousLast!),
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
