import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/daily_special.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/entities/zip_level.dart';

const _solution = <int>[
  1, 2, 3, 4, 5, 6, //
  4, 5, 6, 1, 2, 3,
  2, 3, 1, 5, 6, 4,
  5, 6, 4, 2, 3, 1,
  3, 1, 2, 6, 4, 5,
  6, 4, 5, 3, 1, 2,
];

Map<String, dynamic> _pathWordsJson() => {
  'size': 2,
  'day': '2026-10-17T00:00:00.000Z',
  'letters': ['c', 'a', 't', ''],
  'targets': [
    {
      'id': 't0',
      'word': 'cat',
      'start': [0, 0],
      'path': [
        [0, 0],
        [0, 1],
        [1, 0],
      ],
      'colorIndex': 0,
    },
  ],
};

Map<String, dynamic> _zipJson() => {
  'size': 3,
  'numbers': {'0,0': 1, '2,2': 2},
  'walls': <Object>[],
};

Map<String, dynamic> _sudokuJson() => {
  'dateId': '20261017',
  'size': 6,
  'boxRows': 2,
  'boxCols': 3,
  'difficulty': 'hard',
  'given': [for (final d in _solution) d.isEven ? d : 0],
  'solution': _solution,
};

void main() {
  group('PathWordsPuzzle theme and definitions', () {
    test('reads the theme, definitions and special', () {
      final puzzle = PathWordsPuzzle.fromJson({
        ..._pathWordsJson(),
        'theme': 'Kitchen tools',
        'definitions': {'CAT': 'A small furry pet that purrs', 'dog': 7},
        'special': 'weekend',
        'somethingNew': true,
      }, id: 'daily_20261017');
      expect(puzzle.theme, 'Kitchen tools');
      expect(puzzle.definitionFor('cat'), 'A small furry pet that purrs');
      expect(puzzle.definitionFor('CAT'), 'A small furry pet that purrs');
      expect(puzzle.definitions.containsKey('dog'), isFalse);
      expect(puzzle.special, 'weekend');
      expect(puzzle.isWeekendSpecial, isTrue);
    });

    test(
      'has no theme, no definitions and no special when the doc has none',
      () {
        final puzzle = PathWordsPuzzle.fromJson(_pathWordsJson(), id: 'd');
        expect(puzzle.theme, isNull);
        expect(puzzle.definitions, isEmpty);
        expect(puzzle.definitionFor('cat'), isNull);
        expect(puzzle.special, isNull);
        expect(puzzle.isWeekendSpecial, isFalse);
      },
    );

    test('reads a blank or malformed theme and definitions as none', () {
      final puzzle = PathWordsPuzzle.fromJson({
        ..._pathWordsJson(),
        'theme': '   ',
        'definitions': ['cat'],
        'special': 3,
      }, id: 'd');
      expect(puzzle.theme, isNull);
      expect(puzzle.definitions, isEmpty);
      expect(puzzle.special, isNull);
    });

    test('a blank definition is no definition', () {
      final puzzle = PathWordsPuzzle.fromJson({
        ..._pathWordsJson(),
        'definitions': {'cat': '  '},
      }, id: 'd');
      expect(puzzle.definitionFor('cat'), isNull);
    });

    test('the fingerprint ignores them, so a new theme keeps a saved run', () {
      final plain = PathWordsPuzzle.fromJson(_pathWordsJson(), id: 'd');
      final themed = PathWordsPuzzle.fromJson({
        ..._pathWordsJson(),
        'theme': 'Pets',
        'definitions': {'cat': 'A small furry pet that purrs'},
        'special': 'weekend',
      }, id: 'd');
      expect(themed.fingerprint, plain.fingerprint);
    });

    test('toJson keeps them when set and leaves them out otherwise', () {
      final themed = PathWordsPuzzle.fromJson({
        ..._pathWordsJson(),
        'theme': 'Pets',
        'definitions': {'cat': 'A small furry pet that purrs'},
        'special': 'weekend',
      }, id: 'd');
      final json = themed.toJson();
      expect(json['theme'], 'Pets');
      expect(json['definitions'], {'cat': 'A small furry pet that purrs'});
      expect(json['special'], 'weekend');
      final plain = PathWordsPuzzle.fromJson(
        _pathWordsJson(),
        id: 'd',
      ).toJson();
      expect(plain.containsKey('theme'), isFalse);
      expect(plain.containsKey('definitions'), isFalse);
      expect(plain.containsKey('special'), isFalse);
    });
  });

  group('weekend specials', () {
    test('ZipLevel reads special without changing its fingerprint', () {
      final plain = ZipLevel.fromJson(_zipJson(), id: 'daily_20261017');
      final weekend = ZipLevel.fromJson({
        ..._zipJson(),
        'special': 'weekend',
      }, id: 'daily_20261017');
      expect(plain.special, isNull);
      expect(weekend.special, 'weekend');
      expect(weekend.isWeekendSpecial, isTrue);
      expect(weekend.fingerprint, plain.fingerprint);
      expect(weekend.toJson()['special'], 'weekend');
      expect(plain.toJson().containsKey('special'), isFalse);
    });

    test('SudokuPuzzle reads special without changing its fingerprint', () {
      final plain = SudokuPuzzle.fromJson(_sudokuJson(), id: 'daily_20261017');
      final weekend = SudokuPuzzle.fromJson({
        ..._sudokuJson(),
        'special': 'weekend',
      }, id: 'daily_20261017');
      expect(plain.special, isNull);
      expect(weekend.special, 'weekend');
      expect(weekend.isWeekendSpecial, isTrue);
      expect(weekend.fingerprint, plain.fingerprint);
      expect(weekend.toJson()['special'], 'weekend');
      expect(plain.toJson().containsKey('special'), isFalse);
    });

    test('an unknown special is kept but is not a weekend', () {
      final level = ZipLevel.fromJson({
        ..._zipJson(),
        'special': 'holiday',
      }, id: 'd');
      expect(level.special, 'holiday');
      expect(level.isWeekendSpecial, isFalse);
    });

    test('isWeekendSpecial reads the field', () {
      expect(isWeekendSpecial(DailySpecial.weekend), isTrue);
      expect(isWeekendSpecial(null), isFalse);
      expect(isWeekendSpecial('holiday'), isFalse);
      expect(readDailySpecial(' weekend '), 'weekend');
      expect(readDailySpecial(''), isNull);
      expect(readDailySpecial(5), isNull);
    });
  });
}
