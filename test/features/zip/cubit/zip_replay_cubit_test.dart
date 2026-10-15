import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/cubit/zip_replay_cubit.dart';

void main() {
  const columnSnake = [
    Cell(0, 0), Cell(1, 0), Cell(2, 0), //
    Cell(2, 1), Cell(1, 1), Cell(0, 1), //
    Cell(0, 2), Cell(1, 2), Cell(2, 2),
  ];

  final level = ZipLevel(
    id: 'replay',
    size: 3,
    numbers: {const Cell(0, 0): 1, const Cell(2, 2): 2},
    walls: const [],
  );

  ZipReplayCubit build(List<Cell> savedPath) =>
      ZipReplayCubit(level: level, savedPath: savedPath);

  test('a saved winning path can be replayed', () {
    final cubit = build(columnSnake);

    expect(cubit.state, const ZipReplayState(available: true));
    expect(cubit.path, columnSnake);
  });

  test('nothing to replay without a saved path', () {
    expect(build(const []).state.available, isFalse);
  });

  test('nothing to replay when the saved path does not win', () {
    // Review shows the setter's solution then, not the player's path.
    expect(build(const [Cell(0, 0), Cell(1, 0)]).state.available, isFalse);
  });

  blocTest<ZipReplayCubit, ZipReplayState>(
    'start plays the replay once',
    build: () => build(columnSnake),
    act: (cubit) {
      expect(cubit.start(), isTrue);
      expect(cubit.start(), isFalse);
    },
    expect: () => const [ZipReplayState(available: true, playing: true)],
  );

  blocTest<ZipReplayCubit, ZipReplayState>(
    'start is refused when there is nothing to replay',
    build: () => build(const []),
    act: (cubit) => expect(cubit.start(), isFalse),
    expect: () => const <ZipReplayState>[],
  );

  blocTest<ZipReplayCubit, ZipReplayState>(
    'finished stops playing',
    build: () => build(columnSnake),
    act: (cubit) {
      cubit.start();
      cubit.finished();
      cubit.finished();
    },
    expect: () => const [
      ZipReplayState(available: true, playing: true),
      ZipReplayState(available: true),
    ],
  );

  test('a replay that ends after the screen closed is ignored', () async {
    final cubit = build(columnSnake)..start();
    await cubit.close();

    expect(cubit.finished, returnsNormally);
  });
}
