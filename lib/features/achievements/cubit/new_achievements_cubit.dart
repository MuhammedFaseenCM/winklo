import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/achievements/achievement.dart';
import '../../../domain/usecases/claim_new_achievements.dart';

/// The achievements to announce on one Results screen ([occasion]). They are
/// marked seen only once emitted to a live banner; empty when there are none
/// or the lookup fails.
class NewAchievementsCubit extends Cubit<List<Achievement>> {
  NewAchievementsCubit({required this._claim, this.occasion})
    : super(const []) {
    unawaited(_load());
  }

  final ClaimNewAchievements _claim;
  final Object? occasion;

  Future<void> _load() async {
    try {
      final fresh = await _claim.pending(occasion: occasion);
      if (isClosed || fresh.isEmpty) return;
      emit(List.unmodifiable(fresh));
      await _claim.markShown(fresh, occasion: occasion);
    } catch (_) {
      // Decoration only: Results never fails over a badge.
    }
  }
}
