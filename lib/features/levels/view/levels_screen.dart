import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/play_mode_route.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/logic/level_map.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/leaderboard_repository.dart';
import '../../../domain/repositories/level_progress_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';
import '../../../domain/repositories/levels_game_preference_repository.dart';
import '../../../domain/usecases/submit_level_clear.dart';
import '../cubit/level_map_cubit.dart';
import '../logic/level_map_layout.dart';
import 'widgets/level_avatar_pin.dart';
import 'widgets/level_node.dart';
import 'widgets/level_path_painter.dart';
import 'widgets/level_sheet.dart';
import 'widgets/world_backdrop_painter.dart';

/// The Levels tab: one game's levels on a winding map, switched in the
/// header (the choice is remembered). [openLevelId] (from `/levels?open=…`,
/// e.g. Results' Next level) picks its game and opens that level's sheet
/// once the map is loaded.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, this.openLevelId});

  final String? openLevelId;

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  late String _game;

  /// The switcher's games in chip order; a switch slides the map the way
  /// the chips run.
  static const _order = [GameIds.zip, GameIds.pathWords];

  /// 1 when the new map comes in from the right, -1 from the left.
  int _direction = 1;

  /// The shown game's star total, reported by its map once it's loaded.
  ({int stars, int maxStars})? _stars;

  /// [LevelsScreen.openLevelId] until the player switches game: switching
  /// back must not reopen a sheet that was already shown.
  String? _openLevelId;

  @override
  void initState() {
    super.initState();
    _openLevelId = widget.openLevelId;
    final preference = context.read<LevelsGamePreferenceRepository>();
    final opened = _gameOf(widget.openLevelId);
    _game = opened ?? preference.read();
    if (opened != null) unawaited(preference.write(opened));
  }

  /// The game a level id belongs to (`path_words_1_01`), if any.
  static String? _gameOf(String? levelId) {
    if (levelId == null) return null;
    for (final game in levelGameIds) {
      if (levelId.startsWith('${game}_')) return game;
    }
    return null;
  }

  void _select(String game) {
    if (game == _game) return;
    unawaited(context.read<LevelsGamePreferenceRepository>().write(game));
    setState(() {
      _direction = _order.indexOf(game) >= _order.indexOf(_game) ? 1 : -1;
      _game = game;
      _openLevelId = null;
      _stars = null;
    });
  }

  /// A map's star total; only the shown game's counts (the outgoing map
  /// can still emit while it slides away).
  void _onStars(String game, int? stars, int? maxStars) {
    if (!mounted || game != _game) return;
    final next = stars == null || maxStars == null
        ? null
        : (stars: stars, maxStars: maxStars);
    if (next == _stars) return;
    setState(() => _stars = next);
  }

  void _onSudoku() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppStrings.levelsSudokuSoon)));
  }

  @override
  Widget build(BuildContext context) {
    final openLevelId = _openLevelId;
    final still = MediaQuery.disableAnimationsOf(context);
    final map = BlocProvider(
      // A fresh cubit, scroll position and placement for each game.
      key: ValueKey(_game),
      create: (context) => LevelMapCubit(
        worlds: context.read<LevelWorldRepository>(),
        progress: context.read<LevelProgressRepository>(),
        leaderboard: context.read<LeaderboardRepository>(),
        submitLevelClear: context.read<SubmitLevelClear>(),
        game: _game,
      )..load(),
      child: _LevelsView(
        game: _game,
        onStars: _onStars,
        openLevelId: openLevelId != null && _gameOf(openLevelId) == _game
            ? openLevelId
            : null,
      ),
    );
    final stars = _stars;
    return Scaffold(
      body: ZipAtmosphere(
        // The map runs under the shell's glass dock (extendBody puts the
        // dock in padding.bottom); LevelMapLayout keeps its levels above it.
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                game: _game,
                onSelectGame: _select,
                onSudoku: _onSudoku,
                stars: stars?.stars,
                maxStars: stars?.maxStars,
              ),
              Expanded(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey(_game);
                      // The new map slides in from the side the chip is
                      // on; the old one leaves the other way.
                      final from = Offset(
                        (incoming ? _direction : -_direction) * 0.15,
                        0,
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: from,
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: map,
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

class _LevelsView extends StatefulWidget {
  const _LevelsView({
    required this.game,
    required this.onStars,
    this.openLevelId,
  });

  final String game;
  final void Function(String game, int? stars, int? maxStars) onStars;
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
        var offset =
            layout.size.height -
            center.dy -
            (viewport + layout.bottomInset) / 2;
        offset = _clearOfDock(layout, center, offset, viewport);
        _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
      }
      if (open == null) return;
      if (open.playable) {
        showLevelSheet(
          context,
          open,
          boardLevelIds: context.read<LevelMapCubit>().state.boardLevelIds,
        );
      } else {
        _showLocked(map);
      }
    });
  }

  /// [offset], scrolled down just enough that the focused level's world
  /// label (centred on its gate, below the level) clears the dock, while
  /// the level itself stays well inside the view. The bottom world's label
  /// already sits above the dock.
  double _clearOfDock(
    LevelMapLayout layout,
    Offset focus,
    double offset,
    double viewport,
  ) {
    final index = layout.bands.indexWhere(
      (band) => band.rect.top <= focus.dy && focus.dy <= band.rect.bottom,
    );
    if (index <= 0) return offset;
    // About half a two-line label, plus a little air.
    const labelHalf = 30.0;
    const gap = 8.0;
    final labelBottom = layout.bands[index].gateY + labelHalf;
    final visibleBottom = layout.size.height - offset - layout.bottomInset;
    if (labelBottom + gap <= visibleBottom) return offset;
    final wanted = layout.size.height - labelBottom - gap - layout.bottomInset;
    // Never so far that the level nears the top of the view.
    final floor = layout.size.height - viewport - focus.dy + 72;
    return math.max(wanted, math.min(floor, offset));
  }

  void _onTap(LevelMap map, LevelMapNode node) {
    if (node.playable) {
      showLevelSheet(
        context,
        node,
        boardLevelIds: context.read<LevelMapCubit>().state.boardLevelIds,
      );
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
    return BlocConsumer<LevelMapCubit, LevelMapState>(
      listener: (context, state) =>
          widget.onStars(widget.game, state.map?.stars, state.map?.maxStars),
      builder: (context, state) => switch (state.status) {
        LevelMapStatus.ready => _map(context, state.map!),
        // Centred in the part the dock leaves open.
        final status => SafeArea(
          top: false,
          child: switch (status) {
            LevelMapStatus.unavailable => _Message(
              text: AppStrings.levelsNeedConnection,
              onRetry: () => context.read<LevelMapCubit>().load(),
            ),
            LevelMapStatus.empty => _Message(text: AppStrings.levelsComingSoon),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      },
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
  const _Header({
    required this.game,
    required this.onSelectGame,
    required this.onSudoku,
    this.stars,
    this.maxStars,
  });

  final String game;
  final ValueChanged<String> onSelectGame;
  final VoidCallback onSudoku;
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
          // As tall as the star link, so the chips don't move up while a
          // newly shown game's total is still loading.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
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
                  _StarsLink(game: game, text: '$stars / $maxStars'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _GameChip(
                text: AppStrings.zipTitle,
                selected: game == GameIds.zip,
                onTap: () => onSelectGame(GameIds.zip),
              ),
              _GameChip(
                text: AppStrings.pathWordsTitle,
                selected: game == GameIds.pathWords,
                onTap: () => onSelectGame(GameIds.pathWords),
              ),
              _SoonChip(
                text: '${AppStrings.sudokuTitle} · ${AppStrings.levelsSoon}',
                onTap: onSudoku,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The star total as a button: it opens the Levels leaderboard.
class _StarsLink extends StatelessWidget {
  const _StarsLink({required this.game, required this.text});

  final String game;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.levelsStarsToBoard,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () =>
            context.go(levelsBoardLocationFor(game), extra: levelsVisitToken()),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: _Chip(
              icon: AppIcons.star,
              text: text,
              trailing: const AppIcon(
                AppIcons.chevronRight,
                size: 14,
                color: ZipColors.star,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A game's chip in the switcher: a button that's selected when it's the
/// game on show.
class _GameChip extends StatelessWidget {
  const _GameChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: text,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: _Chip(text: text, selected: selected),
          ),
        ),
      ),
    );
  }
}

/// A game whose Levels aren't out yet: the game chips' size and line,
/// dimmed with a lock. Announced as a disabled button; a tap says it's
/// coming soon.
class _SoonChip extends StatelessWidget {
  const _SoonChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      excludeSemantics: true,
      label: text,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Opacity(
              opacity: 0.55,
              child: _Chip(
                text: text,
                icon: AppIcons.lock,
                iconColor: ZipColors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    this.icon,
    this.iconColor = ZipColors.star,
    this.trailing,
    this.selected = false,
  });

  final String text;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // The selected game's ember fades across as the switch happens.
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? ZipColors.ember : ZipColors.paper,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? ZipColors.onInk
                  : (icon != null && iconColor == ZipColors.star
                        ? ZipColors.star
                        : ZipColors.inkSoft),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 2), trailing!],
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
    // A locked world also says how big its boards get.
    final title = [
      AppStrings.levelWorldTitle(
        world.world.order,
        AppStrings.levelWorldDisplayName(world.world),
      ),
      if (!world.open) ?levelBoardSizeRange(world.world.levels),
    ].join(' · ');
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
