import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/strings/app_strings.dart';
import '../../domain/habit/home_widget_snapshot.dart';
import '../../domain/play_period.dart';
import '../../domain/repositories/home_widget_repository.dart';

/// Feeds `WinkloWidgetProvider` (android/app/src/main/kotlin/…) through
/// home_widget's shared preferences. The keys below must match the
/// provider's.
class HomeWidgetRepositoryImpl implements HomeWidgetRepository {
  HomeWidgetRepositoryImpl({bool Function()? isSupported, this._now})
    : _isSupported = isSupported ?? _isAndroid;

  static const provider = 'com.winklo.faseencm.$_providerClass';
  static const _providerClass = 'WinkloWidgetProvider';

  /// Scheduled redraws land this long after midnight, so the provider sees
  /// the new date.
  static const midnightSlack = Duration(seconds: 5);

  final bool Function() _isSupported;
  final DateTime Function()? _now;

  static bool _isAndroid() => !kIsWeb && Platform.isAndroid;

  /// Everything the provider reads, as strings.
  static Map<String, String> values(HomeWidgetSnapshot snapshot) => {
    'winklo_day': snapshot.dayId,
    'winklo_next_day': snapshot.nextDayId,
    'winklo_title': AppStrings.appTitle,
    'winklo_footer': AppStrings.widgetFooter,
    'winklo_play': AppStrings.widgetPlay,
    for (final line in snapshot.today) ...{
      'winklo_${line.gameId}_title': AppStrings.gameTitle(line.gameId),
      'winklo_${line.gameId}_today': _label(line),
    },
    for (final line in snapshot.tomorrow)
      'winklo_${line.gameId}_next': _label(line),
  };

  static String _label(HomeWidgetLine line) => switch (line.mark) {
    HomeWidgetMark.cleared => AppStrings.widgetCleared,
    HomeWidgetMark.streak => AppStrings.widgetStreak(line.streak),
    HomeWidgetMark.play => AppStrings.widgetPlay,
  };

  @override
  Future<void> update(HomeWidgetSnapshot snapshot) async {
    if (!_isSupported()) return;
    try {
      for (final MapEntry(:key, :value) in values(snapshot).entries) {
        await HomeWidget.saveWidgetData<String>(key, value);
      }
      final widgets = await HomeWidget.getInstalledWidgets();
      // Android reports the short class name (".WinkloWidgetProvider").
      final placed = widgets.any(
        (w) => w.androidClassName?.endsWith(_providerClass) ?? false,
      );
      if (!placed) {
        // The data waits for a widget being added; no alarms meanwhile.
        await HomeWidget.cancelScheduledWidgetUpdates(
          qualifiedAndroidName: provider,
        );
        return;
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: provider);
      // Redraws at the next two midnights even if the app stays closed; the
      // provider then shows tomorrow's rows (or Play) by date.
      final now = _now?.call() ?? DateTime.now();
      final midnight = PlayPeriod.nextStart(now, PlayPeriod.daily);
      final after = PlayPeriod.nextStart(
        midnight.add(const Duration(hours: 12)),
        PlayPeriod.daily,
      );
      await HomeWidget.scheduleWidgetUpdates([
        midnight.add(midnightSlack),
        after.add(midnightSlack),
      ], qualifiedAndroidName: provider);
    } catch (e) {
      debugPrint('Home widget update failed: $e');
    }
  }
}
