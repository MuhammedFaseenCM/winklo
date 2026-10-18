import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics_service.dart';
import '../../../core/sfx/sfx_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bonus_game_chrome.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/fetch_categories.dart';
import '../bloc/category_race_bloc.dart';
import '../bloc/category_race_event.dart';
import '../bloc/category_race_state.dart';

/// A Category Race round: words for one category and letter against the
/// clock. A bonus game: its best count stays on the device.
class CategoryRaceScreen extends StatefulWidget {
  const CategoryRaceScreen({super.key});

  @override
  State<CategoryRaceScreen> createState() => _CategoryRaceScreenState();
}

class _CategoryRaceScreenState extends State<CategoryRaceScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  late final CategoryRaceBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = CategoryRaceBloc(
      fetchCategories: context.read<FetchCategories>(),
      records: context.read<PlayModeRecordRepository>(),
      analytics: context.read<AnalyticsRepository>(),
      sfx: context.read<SfxService?>(),
      haptics: context.read<HapticsService?>(),
    )..add(const CategoryRaceEvent.fetchCategories());
    // The round waits for Start, so the rules can open over the card.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BonusHowToPlay.maybeShow(
        context,
        gameId: GameIds.categoryRace,
        title: AppStrings.zipHowToPlayTitle,
        body: AppStrings.categoryRaceHowToBody,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _bloc.close();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    _controller.clear();
    _bloc.add(CategoryRaceEvent.answerSubmitted(raw));
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: [
          BlocListener<CategoryRaceBloc, CategoryRaceState>(
            listenWhen: (p, c) =>
                p.status != c.status &&
                c.status == CategoryRaceStatus.navigating,
            listener: (context, state) {
              context.pushReplacement('/results', extra: state.resultsExtra);
            },
          ),
          BlocListener<CategoryRaceBloc, CategoryRaceState>(
            listenWhen: (p, c) =>
                p.status != c.status && c.status == CategoryRaceStatus.playing,
            listener: (context, state) => _focus.requestFocus(),
          ),
        ],
        child: BlocBuilder<CategoryRaceBloc, CategoryRaceState>(
          builder: (context, state) {
            final started = state.status == CategoryRaceStatus.playing;
            return Scaffold(
              body: ZipAtmosphere(
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BonusGameHeader(
                        title: AppStrings.categoryRace,
                        gameId: GameIds.categoryRace,
                        howToPlayBody: AppStrings.categoryRaceHowToBody,
                        secondsLeft: started ? state.remainingSeconds : null,
                      ),
                      Expanded(child: _body(context, state)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CategoryRaceState state) {
    switch (state.status) {
      case CategoryRaceStatus.initial:
      case CategoryRaceStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CategoryRaceStatus.failure:
        return BonusGameMessage(
          message: state.error ?? AppStrings.bonusLoadFailed,
          onRetry: () => _bloc.add(const CategoryRaceEvent.fetchCategories()),
        );
      case CategoryRaceStatus.ready:
      case CategoryRaceStatus.playing:
      case CategoryRaceStatus.submitting:
      case CategoryRaceStatus.navigating:
        break;
    }
    final category = state.category;
    if (category == null) {
      return BonusGameMessage(message: AppStrings.categoryRaceNoCategories);
    }
    final started = state.status == CategoryRaceStatus.playing;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: ZipColors.cardGradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ZipColors.glassBorder),
            ),
            child: Column(
              children: [
                Text(
                  category.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: ZipColors.emberGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: ZipColors.emberGlow.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    state.letter,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: ZipColors.onInk,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.categoryRaceInstruction(state.letter),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ZipColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!started)
            ZipPrimaryButton(
              label: AppStrings.categoryRaceStart(state.totalSeconds),
              icon: Icons.play_arrow_rounded,
              onPressed: state.status == CategoryRaceStatus.ready
                  ? () => _bloc.add(const CategoryRaceEvent.started())
                  : null,
            )
          else ...[
            TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              style: const TextStyle(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: AppStrings.categoryRaceYourWord,
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  color: ZipColors.inkSoft,
                ),
                errorText: state.feedback,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            ZipPrimaryButton(
              label: AppStrings.categoryRaceSubmit,
              icon: Icons.send_rounded,
              compact: true,
              onPressed: _submit,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: ZipColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  AppStrings.categoryRaceAccepted(state.answers.length),
                  style: const TextStyle(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final word in state.answers)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ZipColors.successSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: ZipColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          word,
                          style: const TextStyle(
                            color: ZipColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
