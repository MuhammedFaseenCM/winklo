import { describe, expect, it } from 'vitest';
import { pathWordsBoard, shortName, sudokuBoard, topEntry, zipBoard } from './today';

describe('zipBoard', () => {
  const data = {
    size: 3,
    numbers: { '2,2': 3, '0,0': 1, '1,2': 2 },
    walls: [{ a: [0, 1], b: [1, 1] }],
    solution: [{ row: 0, col: 0 }],
    difficulty: 'hard',
  };

  it('keeps numbers in order and walls as cell pairs', () => {
    expect(zipBoard(data)).toEqual({
      size: 3,
      numbers: [
        [0, 0, 1],
        [1, 2, 2],
        [2, 2, 3],
      ],
      walls: [[0, 1, 1, 1]],
    });
  });

  it('never passes the solution on', () => {
    expect(JSON.stringify(zipBoard(data))).not.toContain('row');
  });

  it('allows a board without walls', () => {
    expect(zipBoard({ ...data, walls: undefined })?.walls).toEqual([]);
  });

  it('rejects cells outside the board', () => {
    expect(zipBoard({ ...data, numbers: { '3,0': 1 } })).toBeNull();
    expect(zipBoard({ ...data, walls: [{ a: [0, 0], b: [0, 9] }] })).toBeNull();
  });

  it('rejects a missing or silly size', () => {
    expect(zipBoard({ ...data, size: undefined })).toBeNull();
    expect(zipBoard({ ...data, size: 99 })).toBeNull();
  });
});

describe('sudokuBoard', () => {
  const given = [5, 0, 0, 0, 0, 1, ...Array(30).fill(0)];
  const data = { size: 6, boxRows: 2, boxCols: 3, given, solution: Array(36).fill(4) };

  it('keeps the givens and box shape only', () => {
    expect(sudokuBoard(data)).toEqual({ size: 6, boxRows: 2, boxCols: 3, given });
  });

  it('rejects boxes that do not tile the board', () => {
    expect(sudokuBoard({ ...data, boxRows: 3 })).toBeNull();
  });

  it('rejects givens of the wrong length or range', () => {
    expect(sudokuBoard({ ...data, given: given.slice(1) })).toBeNull();
    expect(sudokuBoard({ ...data, given: [7, ...given.slice(1)] })).toBeNull();
  });
});

describe('pathWordsBoard', () => {
  const letters = ['c', 'a', '', 't'];
  const targets = [
    { word: 'cat', path: [{ row: 0, col: 0 }] },
    { word: 'act', path: [{ row: 0, col: 1 }] },
  ];

  it('upper-cases letters, keeps gaps and counts the words', () => {
    expect(pathWordsBoard({ size: 2, letters, targets })).toEqual({
      size: 2,
      letters: ['C', 'A', '', 'T'],
      words: 2,
    });
  });

  it('never passes the words or their routes on', () => {
    const json = JSON.stringify(pathWordsBoard({ size: 2, letters, targets }));
    expect(json).not.toContain('cat');
    expect(json).not.toContain('row');
  });

  it('rejects a board without words', () => {
    expect(pathWordsBoard({ size: 2, letters, targets: [] })).toBeNull();
  });

  it('rejects cells holding more than one letter', () => {
    expect(pathWordsBoard({ size: 2, letters: ['ca', 'a', '', 't'], targets })).toBeNull();
  });
});

describe('shortName', () => {
  it('keeps the first word and the last word’s initial', () => {
    expect(shortName('Arun Kumar')).toBe('Arun K.');
    expect(shortName('  Muhammed  Faseen   cm ')).toBe('Muhammed C.');
  });

  it('keeps a single word as it is', () => {
    expect(shortName('Karna')).toBe('Karna');
  });

  it('caps a long first word', () => {
    expect(shortName('Abcdefghijklmnopqrstuvwxyz')).toBe('Abcdefghijklmnop');
  });

  it('falls back to Player', () => {
    expect(shortName('')).toBe('Player');
    expect(shortName('   ')).toBe('Player');
    expect(shortName(null)).toBe('Player');
  });

  it('does not split characters outside the BMP', () => {
    expect(shortName('Ann 😀x')).toBe('Ann 😀.');
  });
});

describe('topEntry', () => {
  const entry = {
    timeSeconds: 48,
    displayName: 'Arun Kumar',
    usedHints: false,
    hadMistakes: false,
    currentStreak: 5,
    photoUrl: 'https://example.com/me.jpg',
  };

  it('shows the short name, time and clean-run flags, and no photo', () => {
    expect(topEntry('sudoku', entry)).toEqual({
      name: 'Arun K.',
      timeSeconds: 48,
      hintFree: true,
      flawless: true,
      streak: 5,
    });
  });

  it('only calls Sudoku runs flawless', () => {
    expect(topEntry('zip', entry)?.flawless).toBe(false);
  });

  it('needs an explicit false for hint-free', () => {
    expect(topEntry('zip', { ...entry, usedHints: undefined })?.hintFree).toBe(false);
  });

  it('drops times under one second (no per-game speed floor)', () => {
    expect(topEntry('zip', { ...entry, timeSeconds: 0 })).toBeNull();
    expect(topEntry('zip', { ...entry, timeSeconds: 1 })).not.toBeNull();
    expect(topEntry('path_words', { ...entry, timeSeconds: 1 })).not.toBeNull();
  });

  it('drops a missing or fractional time', () => {
    expect(topEntry('zip', { ...entry, timeSeconds: undefined })).toBeNull();
    expect(topEntry('zip', { ...entry, timeSeconds: 12.5 })).toBeNull();
  });

  it('treats a missing streak as none', () => {
    expect(topEntry('zip', { ...entry, currentStreak: undefined })?.streak).toBe(0);
  });
});
