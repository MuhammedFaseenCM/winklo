import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/path_words/path_words_generator.dart';
import 'package:winklo/domain/path_words/path_words_rules.dart';

List<String> _bundledPracticeWords() => File(
  'assets/words/en_practice_words.txt',
).readAsLinesSync().where((w) => w.trim().isNotEmpty).toList();

void main() {
  final words = _bundledPracticeWords();

  test('the bundled practice list has 5-6 letter words and no palindromes', () {
    expect(words.length, greaterThan(150));
    for (final word in words) {
      expect(word, matches(RegExp(r'^[a-z]{5,6}$')));
      expect(word, isNot(word.split('').reversed.join()));
    }
  });

  test('practice boards are hard dailies: 6x6, 5-6 letter words, 3-6 lone '
      'blanks, every letter in a word, one route per word', () {
    for (var seed = 0; seed < 60; seed++) {
      final puzzle = PathWordsGenerator.practice(seed: seed, words: words);
      expect(puzzle.size, 6);
      final blanks = [
        for (var r = 0; r < 6; r++)
          for (var c = 0; c < 6; c++)
            if (!puzzle.hasLetter(Cell(r, c))) Cell(r, c),
      ];
      expect(blanks.length, inInclusiveRange(3, 6), reason: 'seed $seed');
      final covered = <Cell>{};
      for (final target in puzzle.targets) {
        expect(target.word.length, inInclusiveRange(5, 6));
        expect(words, contains(target.word));
        expect(PathWordsRules.spell(puzzle, target.path), target.word);
        expect(PathWordsGenerator.routeCount(puzzle, target.word), 1);
        for (var i = 1; i < target.path.length; i++) {
          final a = target.path[i - 1];
          final b = target.path[i];
          expect((a.row - b.row).abs() + (a.col - b.col).abs(), 1);
        }
        covered.addAll(target.path);
      }
      expect(covered.length + blanks.length, 36, reason: 'seed $seed');
      expect(PathWordsGenerator.practiceBoardIssues(puzzle), isEmpty);
      expect(
        puzzle.targets.map((t) => t.word).toSet().length,
        puzzle.targets.length,
      );
    }
  });

  test('the app reads a practice board as it reads a daily', () {
    final puzzle = PathWordsGenerator.practice(seed: 3, words: words);
    final parsed = PathWordsPuzzle.fromJson(puzzle.toJson());
    expect(parsed.fingerprint, puzzle.fingerprint);
  });

  test('the same seed gives the same board; other seeds differ', () {
    final a = PathWordsGenerator.practice(seed: 11, words: words);
    final b = PathWordsGenerator.practice(seed: 11, words: words);
    final c = PathWordsGenerator.practice(seed: 12, words: words);
    expect(a.fingerprint, b.fingerprint);
    expect(a.fingerprint, isNot(c.fingerprint));
    expect(a.id, 'practice_11');
  });

  test('too few words to fill a board is an error, not a broken board', () {
    expect(
      () => PathWordsGenerator.practice(
        seed: 1,
        words: const ['candle', 'rocket'],
        attempts: 5,
      ),
      throwsStateError,
    );
  });
}
