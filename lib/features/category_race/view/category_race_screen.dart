import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';

import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/usecases/fetch_categories.dart';
import '../../../domain/usecases/submit_score.dart';
import '../bloc/category_race_bloc.dart';
import '../bloc/category_race_event.dart';
import '../bloc/category_race_state.dart';

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
      submitScore: context.read<SubmitScore>(),
      analytics: context.read<AnalyticsRepository>(),
    )..add(const CategoryRaceEvent.fetchCategories());
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
            if (state.status == CategoryRaceStatus.initial ||
                state.status == CategoryRaceStatus.loading) {
              return const Scaffold(
                backgroundColor: ZipColors.ink,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (state.status == CategoryRaceStatus.failure) {
              return Scaffold(
                backgroundColor: ZipColors.ink,
                appBar: AppBar(
                  title: const Text('Category Race'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  foregroundColor: ZipColors.onInk,
                ),
                body: Center(
                  child: Text(
                    state.error ?? 'Unable to load categories',
                    style: const TextStyle(color: ZipColors.onInk),
                  ),
                ),
              );
            }

            final category = state.category;
            if (category == null) {
              return Scaffold(
                backgroundColor: ZipColors.ink,
                appBar: AppBar(
                  title: const Text('Category Race'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  foregroundColor: ZipColors.onInk,
                ),
                body: const Center(
                  child: Text(
                    'No categories available',
                    style: TextStyle(color: ZipColors.inkSoft),
                  ),
                ),
              );
            }

            final started = state.status == CategoryRaceStatus.playing;
            final remaining = state.remainingSeconds;

            return Scaffold(
              backgroundColor: ZipColors.ink,
              appBar: AppBar(
                title: const Text(
                  'Category Race',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: ZipColors.onInk,
                actions: [
                  if (started)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: remaining <= 10
                                ? const Color(0x33EF4444)
                                : const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: remaining <= 10
                                  ? const Color(0x88EF4444)
                                  : const Color(0x1AFFFFFF),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: remaining <= 10
                                    ? const Color(0xFFEF4444)
                                    : ZipColors.ember,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${remaining}s',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: remaining <= 10
                                      ? const Color(0xFFEF4444)
                                      : ZipColors.onInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              body: ZipAtmosphere(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: ZipColors.cardGradient,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: ZipColors.glassBorder),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x28000000),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              category.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: ZipColors.onInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: ZipColors.emberGradient,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: ZipColors.emberGlow.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                state.letter,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: ZipColors.onInk,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Type words that fit the category and start with ${state.letter}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ZipColors.inkSoft,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!started)
                        ZipPrimaryButton(
                          label: 'Start ${state.totalSeconds}s',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () =>
                              _bloc.add(const CategoryRaceEvent.started()),
                        )
                      else ...[
                        TextField(
                          controller: _controller,
                          focusNode: _focus,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            color: ZipColors.onInk,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Your word',
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
                          label: 'Submit Word',
                          icon: Icons.send_rounded,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: ZipColors.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Accepted (${state.answers.length})',
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
                                        color: ZipColors.success.withValues(
                                          alpha: 0.3,
                                        ),
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
