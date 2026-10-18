import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/home_widget_repository_impl.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/home_widget_snapshot.dart';
import 'package:winklo/domain/usecases/refresh_habit_surfaces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  late List<MethodCall> calls;
  late List<Map<String, Object?>> installed;
  late bool failing;

  const snapshot = HomeWidgetSnapshot(
    dayId: '20261015',
    nextDayId: '20261016',
    today: [
      HomeWidgetLine(gameId: GameIds.zip, mark: HomeWidgetMark.cleared),
      HomeWidgetLine(
        gameId: GameIds.pathWords,
        mark: HomeWidgetMark.streak,
        streak: 12,
      ),
      HomeWidgetLine(gameId: GameIds.sudoku, mark: HomeWidgetMark.play),
    ],
    tomorrow: [
      HomeWidgetLine(
        gameId: GameIds.zip,
        mark: HomeWidgetMark.streak,
        streak: 5,
      ),
      HomeWidgetLine(gameId: GameIds.pathWords, mark: HomeWidgetMark.play),
      HomeWidgetLine(gameId: GameIds.sudoku, mark: HomeWidgetMark.play),
    ],
  );

  setUp(() {
    calls = [];
    failing = false;
    installed = [
      {'widgetId': 7, 'androidClassName': '.WinkloWidgetProvider'},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (failing) throw PlatformException(code: '-6');
          if (call.method == 'getInstalledWidgets') return installed;
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  HomeWidgetRepositoryImpl build() => HomeWidgetRepositoryImpl(
    isSupported: () => true,
    now: () => DateTime(2026, 10, 15, 22, 30),
  );

  Map<String, Object?> saved() => {
    for (final call in calls.where((c) => c.method == 'saveWidgetData'))
      (call.arguments as Map)['id'] as String: (call.arguments as Map)['data'],
  };

  test('values carries the day ids, each line and the copy', () {
    final values = HomeWidgetRepositoryImpl.values(snapshot);
    expect(values['winklo_day'], '20261015');
    expect(values['winklo_next_day'], '20261016');
    expect(values['winklo_zip_title'], AppStrings.zipTitle);
    expect(values['winklo_zip_today'], AppStrings.widgetCleared);
    expect(values['winklo_zip_next'], '🔥5');
    expect(values['winklo_path_words_title'], AppStrings.pathWordsTitle);
    expect(values['winklo_path_words_today'], '🔥12');
    expect(values['winklo_path_words_next'], AppStrings.widgetPlay);
    expect(values['winklo_sudoku_today'], AppStrings.widgetPlay);
    expect(values['winklo_play'], AppStrings.widgetPlay);
    expect(values['winklo_footer'], AppStrings.widgetFooter);
    expect(values['winklo_title'], AppStrings.appTitle);
  });

  test('saves the data, updates the widget and arms two midnights', () async {
    await build().update(snapshot);

    expect(saved(), HomeWidgetRepositoryImpl.values(snapshot));
    final update = calls.singleWhere((c) => c.method == 'updateWidget');
    expect(
      (update.arguments as Map)['qualifiedAndroidName'],
      HomeWidgetRepositoryImpl.provider,
    );
    final schedule = calls.singleWhere(
      (c) => c.method == 'scheduleWidgetUpdates',
    );
    expect((schedule.arguments as Map)['updateTimes'], [
      DateTime(2026, 10, 16, 0, 0, 5).millisecondsSinceEpoch,
      DateTime(2026, 10, 17, 0, 0, 5).millisecondsSinceEpoch,
    ]);
    // Data first, then the redraw.
    expect(calls.last.method, 'scheduleWidgetUpdates');
  });

  test('without a widget on the home screen, only saves the data', () async {
    installed = [];
    await build().update(snapshot);
    expect(saved(), isNotEmpty);
    expect(calls.where((c) => c.method == 'updateWidget'), isEmpty);
    expect(
      calls.where((c) => c.method == 'cancelScheduledWidgetUpdates'),
      hasLength(1),
    );
  });

  test('platform errors are swallowed', () async {
    failing = true;
    await expectLater(build().update(snapshot), completes);
  });

  test('does nothing off Android', () async {
    await HomeWidgetRepositoryImpl(isSupported: () => false).update(snapshot);
    expect(calls, isEmpty);
  });

  test('the Kotlin provider reads the keys values writes', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/winklo/faseencm/'
      'WinkloWidgetProvider.kt',
    ).readAsStringSync();
    final read = RegExp(
      r'getString\("([a-z_]+)"',
    ).allMatches(kotlin).map((m) => m.group(1)!).toSet();
    final ids = RegExp(
      r'id = "([a-z_]+)"',
    ).allMatches(kotlin).map((m) => m.group(1)!).toList();
    expect(ids, RefreshHabitSurfaces.gameIds);
    expect(kotlin, contains(r'getString("winklo_${game.id}_title"'));
    expect(kotlin, contains(r'getString("winklo_${game.id}_$it"'));
    expect(kotlin, contains('-> "today"'));
    expect(kotlin, contains('-> "next"'));

    final written = HomeWidgetRepositoryImpl.values(snapshot).keys.toSet();
    final perGame = {
      for (final id in ids) ...{
        'winklo_${id}_title',
        'winklo_${id}_today',
        'winklo_${id}_next',
      },
    };
    expect(written, {...read, ...perGame});
  });
}
