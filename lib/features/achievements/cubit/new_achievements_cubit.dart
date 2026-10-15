import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/achievements/achievement.dart';
import '../../../domain/usecases/claim_new_achievements.dart';

/// The achievements to announce on this Results screen: claimed once on
/// creation (which marks them seen), empty when there are none or the claim
/// fails.
class NewAchievementsCubit extends Cubit<List<Achievement>> {
  NewAchievementsCubit({required this._claim}) : super(const []) {
    unawaited(_load());
  }

  final ClaimNewAchievements _claim;

  Future<void> _load() async {
    try {
      final fresh = await _claim();
      if (isClosed || fresh.isEmpty) return;
      emit(List.unmodifiable(fresh));
    } catch (_) {
      // Decoration only: Results never fails over a badge.
    }
  }
}
