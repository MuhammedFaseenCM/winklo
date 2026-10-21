import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/app.dart';
import 'package:winklo/core/config/static_assets_config.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/core/theme/board_text.dart';
import 'package:winklo/core/widgets/dev_run_timer_label.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/app_review_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/language_repository.dart';
import 'package:winklo/domain/repositories/league_repository.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';
import 'package:winklo/domain/usecases/generate_daily_sudoku.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/settings/cubit/locale_cubit.dart';

import '../../test/helpers/mock_app_review_repository.dart';
import 'promo_data.dart';

// ---- the musical grid: 128 BPM in 4/4, as ~/Desktop/winklo-playstore/hype-kit/grid.js
const bpm = 128;
const beat = 60 / bpm, barLen = 4 * beat, six = beat / 4;

/// Seconds from the start of the promo to [bar], [b] beats and [s] sixteenths in (zero-based).
double T(int bar, [num b = 0, num s = 0]) => bar * barLen + b * beat + s * six;

const fps = 60;
const frameDt = Duration(microseconds: 16667);

/// The phone the screens are laid out on: 390×844 dp at 3×, with a 36 dp
/// status bar and a 16 dp gesture bar, so the app keeps clear of both.
const viewSize = Size(390, 844);
const pixelRatio = 3.0;
const insetTop = 36.0, insetBottom = 16.0;

/// The media folder (`~/Desktop/winklo-playstore/app-promo`): `fonts/` and
/// `net/` in, `capture/<shot>/` out.
String get promoDir {
  final dir = Platform.environment['PROMO_DIR'];
  if (dir == null) {
    throw StateError('Set PROMO_DIR (see tool/promo_capture/README.md)');
  }
  return dir;
}

String get ffmpegPath => Platform.environment['PROMO_FFMPEG'] ?? 'ffmpeg';

// ---- fonts: real Lexend (google_fonts' family names), Phosphor, Material icons
Future<void> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> loadPromoFonts() async {
  for (final (variant, weight) in const [
    ('300', 300),
    ('regular', 400),
    ('500', 500),
    ('600', 600),
    ('700', 700),
    ('800', 800),
    ('900', 900),
  ]) {
    await _loadFamily('Lexend_$variant', [
      '$promoDir/fonts/Lexend-$weight.ttf',
    ]);
  }
  for (final (family, file) in const [
    ('PhosphorDuotone', 'Phosphor-Duotone.ttf'),
    ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ('PhosphorRegular', 'Phosphor.ttf'),
  ]) {
    await _loadFamily(family, ['assets/fonts/phosphor/$file']);
  }
  // flutter_tester lives under <flutter>/bin/cache/artifacts/engine/…
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final fonts = Directory('${dir.path}/artifacts/material_fonts');
    if (dir.path.endsWith('bin/cache') && fonts.existsSync()) {
      await _loadFamily('MaterialIcons', [
        '${fonts.path}/MaterialIcons-Regular.otf',
      ]);
      // The Flame boards' numbers and letters are in the phone's sans
      // (Roboto); the test engine's default would draw them as boxes.
      final roboto = [
        for (final f in const ['Regular', 'Medium', 'Bold', 'Black'])
          '${fonts.path}/Roboto-$f.ttf',
      ];
      await _loadFamily('Roboto', roboto);
      BoardText.family = 'Roboto';
      return;
    }
    dir = dir.parent;
  }
}

/// The game tiles and medals come from R2 through CachedNetworkImage, which
/// needs sqflite and path_provider. Seed Flutter's image cache with the real
/// PNGs (`net/<path>`) under the providers' keys instead.
Future<void> seedNetworkImages(WidgetTester tester) async {
  for (final path in const [
    'games/zip_tile_v3.png',
    'games/path_words_tile_v2.png',
    'games/sudoku_tile_v2.png',
    'medals/medal_gold.png',
    'medals/medal_silver.png',
    'medals/medal_bronze.png',
  ]) {
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File('$promoDir/net/$path').readAsBytesSync(),
      );
      return (await codec.getNextFrame()).image;
    });
    PaintingBinding.instance.imageCache.putIfAbsent(
      CachedNetworkImageProvider(StaticAssetsConfig.url(path)),
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image!)),
      ),
    );
  }
}

// ---- fakes
class _MockAuth extends Mock implements AuthRepository {}

class _MockSignIn extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockWatch extends Mock implements WatchLeaderboard {}

class _MockLeagues extends Mock implements LeagueRepository {}

class _MockProfile extends Mock implements ProfileRepository {}

class _MockSubmit extends Mock implements SubmitLeaderboardTime {}

class _MockHistory extends Mock implements LoadGameHistory {}

class _ZipLevels implements ZipLevelRepository {
  @override
  Future<List<ZipLevel>> fetchLevels() async => const [];

  @override
  Future<ZipLevel> fetchDailyLevel(
    DateTime date, {
    Duration period = PlayPeriod.daily,
  }) async => promoZipLevel(date);
}

class _PathWords extends GenerateDailyPathWords {
  @override
  Future<PathWordsPuzzle> call({
    required DateTime day,
    Duration? period,
  }) async => promoPathWords(day);
}

class _Sudoku extends GenerateDailySudoku {
  _Sudoku(this.puzzle);
  final SudokuPuzzle Function(DateTime day) puzzle;

  @override
  Future<SudokuPuzzle> call({required DateTime day, Duration? period}) async =>
      puzzle(day);
}

String dayId(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// The whole app (real router, screens and Flame games) as a signed-in
/// player, with fixed puzzles and leaderboards that emit when told to.
class PromoApp {
  PromoApp({this.prefs = const {}, this.history, required this.sudoku});

  /// Extra SharedPreferences (streaks, clears) on top of "tutorials seen".
  final Map<String, Object> prefs;
  final GameHistory? history;
  final SudokuPuzzle Function(DateTime day) sudoku;

  static const boundary = Key('promo_frame');

  AppUser user = const AppUser(
    uid: promoUid,
    displayName: promoName,
    avatarId: 'preset_01',
  );
  final profile = StreamController<AppUser?>.broadcast();

  /// Per game: null emits the board at once; a controller emits when the
  /// shot adds to it.
  final Map<String, StreamController<List<LeaderboardEntry>>> held = {};

  Future<void> pump(WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) => Completer<Object?>().future,
        );
    registerFallbackValue(LeaderboardPeriod.daily);
    // This file runs under `flutter test` (as tests do), from tool/.
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: 'Winklo',
      packageName: 'com.winklo.faseencm',
      version: '1.1.4',
      buildNumber: '23',
      buildSignature: '',
    );
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'tutorial_seen_zip': true,
      'tutorial_seen_path_words': true,
      'tutorial_seen_sudoku': true,
      ...prefs,
    });
    final sp = await SharedPreferences.getInstance();

    tester.view.physicalSize = viewSize * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    const pad = FakeViewPadding(
      top: insetTop * pixelRatio,
      bottom: insetBottom * pixelRatio,
    );
    tester.view.padding = pad;
    tester.view.viewPadding = pad;
    addTearDown(tester.view.reset);

    final auth = _MockAuth();
    when(() => auth.currentUser).thenAnswer((_) => user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));

    final watch = _MockWatch();
    Stream<List<LeaderboardEntry>> board(String gameId) =>
        held[gameId]?.stream ?? Stream.value(promoBoard(gameId));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((i) => board(i.namedArguments[#gameId] as String));
    when(
      () => watch.members(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        memberUids: any(named: 'memberUids'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((i) => board(i.namedArguments[#gameId] as String));

    final leagues = _MockLeagues();
    when(
      () => leagues.watchMyLeagues(any()),
    ).thenAnswer((_) => Stream.value(const []));

    final profiles = _MockProfile();
    when(() => profiles.watchProfile(any())).thenAnswer((_) async* {
      yield user;
      yield* profile.stream;
    });
    when(() => profiles.getProfile(any())).thenAnswer((_) async => user);
    when(() => profiles.updateAvatarPreset(any())).thenAnswer((i) async {
      // A short save, so the tile's spinner shows.
      await Future<void>.delayed(const Duration(milliseconds: 260));
      user = AppUser(
        uid: user.uid,
        displayName: user.displayName,
        avatarId: i.positionalArguments.first as String,
      );
      profile.add(user);
      return user;
    });

    final submit = _MockSubmit();
    when(
      () => submit(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        currentStreak: any(named: 'currentStreak'),
        dayId: any(named: 'dayId'),
        playId: any(named: 'playId'),
        proof: any(named: 'proof'),
      ),
    ).thenAnswer((_) async {});

    final review = MockAppReviewRepository();
    stubAppReviewNoAutoPrompt(review);

    final loadHistory = _MockHistory();
    when(
      () => loadHistory(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer(
      (_) async =>
          history ??
          GameHistory(days: const [], streaks: const {}, today: DateTime.now()),
    );

    await seedNetworkImages(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiRepositoryProvider(
          providers: [
            ...buildRepositoryProviders(prefs: sp),
            RepositoryProvider<AuthRepository>.value(value: auth),
            // Silent: a test has no audio plugin, and the video has its own score.
            RepositoryProvider<SfxService>(
              create: (context) => SfxService(
                settings: context.read<SfxSettingsRepository>(),
                playClip: (_) async {},
              ),
            ),
            RepositoryProvider<WatchLeaderboard>.value(value: watch),
            RepositoryProvider<LeagueRepository>.value(value: leagues),
            RepositoryProvider<ProfileRepository>.value(value: profiles),
            RepositoryProvider<UpdateAvatar>.value(
              value: UpdateAvatar(profiles),
            ),
            RepositoryProvider<SubmitLeaderboardTime>.value(value: submit),
            RepositoryProvider<AppReviewRepository>.value(value: review),
            RepositoryProvider<LoadGameHistory>.value(value: loadHistory),
            RepositoryProvider<ZipLevelRepository>.value(value: _ZipLevels()),
            RepositoryProvider<GenerateDailyPathWords>.value(
              value: _PathWords(),
            ),
            RepositoryProvider<GenerateDailySudoku>.value(
              value: _Sudoku(sudoku),
            ),
          ],
          child: BlocProvider(
            create: (_) => AuthCubit(
              authRepository: auth,
              signInWithGoogle: _MockSignIn(),
              signOut: _MockSignOut(),
            ),
            child: BlocProvider(
              create: (context) => LocaleCubit(
                languages: context.read<LanguageRepository>(),
                deviceLanguageCodes: () => const ['en'],
              ),
              child: const WinkloApp(),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// SVGs and images decode off the test clock, so give them real time too.
  static Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  static GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));
}

/// The run clock is a debug-build label (release shows nothing), so blank it
/// before a frame is captured. Returns true when something changed.
bool hideDebugOnly(WidgetTester tester) {
  var changed = false;
  for (final e
      in find
          .descendant(
            of: find.byType(DevRunTimerLabel),
            matching: find.byType(RichText),
          )
          .evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    if (p.text.toPlainText().isNotEmpty) {
      p.text = const TextSpan(text: '');
      changed = true;
    }
  }
  return changed;
}

// ---- where things are on screen (logical px)

/// Cell centres of a Flame board: every game centres a square board in its
/// GameWidget with [padding] around it.
Offset Function(int row, int col) boardCells(
  WidgetTester tester, {
  required int size,
  required double padding,
}) {
  final rect = tester.getRect(
    find.byWidgetPredicate((w) => w is GameWidget).first,
  );
  final usable = math.min(rect.width, rect.height);
  final cell = (usable - padding * 2) / size;
  final board = cell * size;
  final origin =
      rect.topLeft +
      Offset((rect.width - board) / 2, (rect.height - board) / 2);
  return (r, c) => origin + Offset((c + 0.5) * cell, (r + 0.5) * cell);
}

// ---- the recorder

/// A finger on the glass from [down] to [up]; [at] says where it is at time t.
class Touch {
  Touch(this.down, this.up, this.at);

  /// A quick tap on [pos] at [t].
  Touch.tap(double t, Offset pos, {double hold = 0.09})
    : this(t, t + hold, (_) => pos);

  final double down, up;
  final Offset Function(double t) at;
  TestGesture? _g;
}

/// Something the shot does at time [t] (emit a board, navigate...).
class Cue {
  Cue(this.t, this.run);
  final double t;
  final Future<void> Function() run;
}

/// Records [from]..[to] (seconds on the promo's grid) at 60 fps into
/// `capture/<name>/00001.jpg`..., playing [touches] and [cues] on time, and
/// writes `capture/<name>/shot.json` for the compositor.
Future<void> recordShot(
  WidgetTester tester,
  String name, {
  required double from,
  required double to,
  List<Touch> touches = const [],
  List<Cue> cues = const [],
}) async {
  final dir = Directory('$promoDir/capture/$name');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  final w = (viewSize.width * pixelRatio).round();
  final h = (viewSize.height * pixelRatio).round();
  final ff = (await tester.runAsync(
    () => Process.start(ffmpegPath, [
      '-y', '-loglevel', 'error', //
      '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '${w}x$h', '-r', '$fps',
      '-i', '-',
      '-q:v', '2', '${dir.path}/%05d.jpg',
    ]),
  ))!;
  unawaited(ff.stderr.transform(utf8.decoder).forEach(stderr.write));

  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(PromoApp.boundary),
  );
  final pending = [...cues]..sort((a, b) => a.t.compareTo(b.t));
  final track = <List<Object>>[];
  final n = ((to - from) * fps).round();
  final sw = Stopwatch()..start();
  for (var k = 0; k < n; k++) {
    final t = from + k / fps;
    while (pending.isNotEmpty && pending.first.t <= t) {
      await pending.removeAt(0).run();
    }
    for (final touch in touches) {
      if (t < touch.down) continue;
      if (touch._g == null && t < touch.up) {
        final p = touch.at(t);
        touch._g = await tester.startGesture(p);
        track.add([t, p.dx, p.dy, 1]);
      } else if (touch._g != null && t < touch.up) {
        final p = touch.at(t);
        await touch._g!.moveTo(p);
        track.add([t, p.dx, p.dy, 1]);
      } else if (touch._g != null) {
        final p = touch.at(touch.up);
        await touch._g!.moveTo(p);
        await touch._g!.up();
        touch._g = null;
        track.add([t, p.dx, p.dy, 0]);
      }
    }
    await tester.pump(frameDt);
    if (hideDebugOnly(tester)) await tester.pump(Duration.zero);
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      ff.stdin.add(data!.buffer.asUint8List());
      await ff.stdin.flush();
    });
  }
  await tester.runAsync(() async {
    await ff.stdin.close();
    await ff.exitCode;
  });
  File('${dir.path}/shot.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'name': name,
      'from': from,
      'to': to,
      'fps': fps,
      'frames': n,
      'width': w,
      'height': h,
      'scale': pixelRatio,
      'insetTop': insetTop,
      'insetBottom': insetBottom,
      'touches': track,
    }),
  );
  // ignore: avoid_print
  print(
    '$name: $n frames in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
  );
}
