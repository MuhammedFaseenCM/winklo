import { describe, expect, it } from 'vitest';
import {
  checkPathWordsProof,
  checkProof,
  checkSudokuProof,
  checkZipProof,
  parseCell,
  parsePathWordsPuzzle,
  parseSudokuPuzzle,
  parseZipPuzzle,
} from './proofs';

describe('parseCell', () => {
  it('accepts every form the app reads', () => {
    expect(parseCell([1, 2])).toEqual([1, 2]);
    expect(parseCell({ row: 1, col: 2 })).toEqual([1, 2]);
    expect(parseCell('1,2')).toEqual([1, 2]);
  });

  it('refuses anything else', () => {
    for (const bad of [[1], [1, 2, 3], [1.5, 2], ['1', '2'], { row: 1 }, '1;2', null, 3]) {
      expect(parseCell(bad)).toBeNull();
    }
  });
});

// 3×3 serpentine: (0,0)(0,1)(0,2)(1,2)(1,1)(1,0)(2,0)(2,1)(2,2)
const serpentine: [number, number][] = [
  [0, 0], [0, 1], [0, 2],
  [1, 2], [1, 1], [1, 0],
  [2, 0], [2, 1], [2, 2],
];

// As Firestore stores it: solution cells as {row, col}, wall ends as [r, c].
const zipDoc = {
  size: 3,
  numbers: { '0,0': 1, '1,1': 2, '2,2': 3 },
  walls: [{ a: [0, 0], b: [1, 0] }],
  solution: serpentine.map(([row, col]) => ({ row, col })),
};

describe('Zip', () => {
  const puzzle = parseZipPuzzle(zipDoc)!;

  it('parses the stored doc', () => {
    expect(puzzle).not.toBeNull();
    expect(puzzle.size).toBe(3);
    expect(puzzle.maxNumber).toBe(3);
  });

  it('refuses a broken doc', () => {
    expect(parseZipPuzzle({ size: 3 })).toBeNull();
    expect(parseZipPuzzle({ ...zipDoc, size: 0 })).toBeNull();
    expect(parseZipPuzzle({ ...zipDoc, numbers: { x: 1 } })).toBeNull();
    expect(parseZipPuzzle({ ...zipDoc, numbers: {} })).toBeNull();
  });

  it('accepts a path that solves it', () => {
    expect(checkZipProof(puzzle, { path: serpentine })).toBe(true);
  });

  it('refuses a path that does not', () => {
    const cases: Record<string, unknown> = {
      'no proof': undefined,
      'no path': {},
      'short path': { path: serpentine.slice(0, 8) },
      'repeated cell': { path: [...serpentine.slice(0, 8), [2, 1]] },
      'out of bounds': { path: [...serpentine.slice(0, 8), [3, 3]] },
      'diagonal step': {
        path: [[0, 0], [0, 1], [0, 2], [1, 1], [1, 2], [2, 2], [2, 1], [1, 0], [2, 0]],
      },
      'through a wall': {
        path: [[0, 0], [1, 0], [2, 0], [2, 1], [1, 1], [0, 1], [0, 2], [1, 2], [2, 2]],
      },
      'not from 1': { path: [...serpentine].reverse() },
      'bad cell shape': { path: serpentine.map(([r, c]) => ({ row: r, col: c })) },
    };
    for (const [name, proof] of Object.entries(cases)) {
      expect(checkZipProof(puzzle, proof), name).toBe(false);
    }
  });

  it('refuses numbers out of order and a path that ends early on the last number', () => {
    // 1 at (0,0), 2 at (2,2), 3 at (1,1): the serpentine meets 3 before 2.
    const outOfOrder = parseZipPuzzle({
      ...zipDoc,
      walls: [],
      numbers: { '0,0': 1, '2,2': 2, '1,1': 3 },
    })!;
    expect(checkZipProof(outOfOrder, { path: serpentine })).toBe(false);

    // The last number sits mid-path.
    const endsEarly = parseZipPuzzle({
      ...zipDoc,
      walls: [],
      numbers: { '0,0': 1, '1,0': 2 },
    })!;
    expect(checkZipProof(endsEarly, { path: serpentine })).toBe(false);
  });
});

const solution = [
  1, 2, 3, 4, 5, 6,
  4, 5, 6, 1, 2, 3,
  2, 3, 1, 5, 6, 4,
  5, 6, 4, 2, 3, 1,
  3, 1, 2, 6, 4, 5,
  6, 4, 5, 3, 1, 2,
];
const given = solution.map((v, i) => (i % 3 === 0 ? v : 0));

describe('Sudoku', () => {
  const puzzle = parseSudokuPuzzle({ size: 6, boxRows: 2, boxCols: 3, given, solution })!;

  it('parses the stored doc, with the 6×6 defaults', () => {
    expect(puzzle).not.toBeNull();
    expect(parseSudokuPuzzle({ given, solution })).not.toBeNull();
  });

  it('refuses boards the app cannot play or broken docs', () => {
    expect(parseSudokuPuzzle({ size: 9, given, solution })).toBeNull();
    expect(parseSudokuPuzzle({ given, solution: solution.slice(1) })).toBeNull();
    expect(parseSudokuPuzzle({ given })).toBeNull();
  });

  it('accepts the solution', () => {
    expect(checkSudokuProof(puzzle, { grid: [...solution] })).toBe(true);
  });

  it('refuses anything else', () => {
    const wrong = [...solution];
    [wrong[0], wrong[1]] = [wrong[1], wrong[0]];
    for (const proof of [
      { grid: wrong },
      { grid: solution.slice(1) },
      { grid: solution.map(String) },
      { grid: given },
      {},
      null,
    ]) {
      expect(checkSudokuProof(puzzle, proof)).toBe(false);
    }
  });
});

// 3×3 board, "cat" along the top row and "go" along the bottom:
//   c a t
//   o x d
//   g o .
const pathWordsDoc = {
  size: 3,
  letters: ['C', 'A', 'T', 'O', 'X', 'D', 'G', 'O', ''],
  targets: [
    { id: 't1', word: 'cat', start: [0, 0], path: [{ row: 0, col: 0 }, { row: 0, col: 1 }, { row: 0, col: 2 }] },
    { id: 't2', word: 'GO', start: [2, 0], path: [{ row: 2, col: 0 }, { row: 2, col: 1 }] },
  ],
};

describe('Path Words', () => {
  const puzzle = parsePathWordsPuzzle(pathWordsDoc)!;
  const stored = [
    { targetId: 't1', cells: [[0, 0], [0, 1], [0, 2]] },
    { targetId: 't2', cells: [[2, 0], [2, 1]] },
  ];

  it('parses the stored doc, lowercasing letters', () => {
    expect(puzzle).not.toBeNull();
    expect(puzzle.letters[0]).toBe('c');
    expect(parsePathWordsPuzzle({ ...pathWordsDoc, letters: ['a'] })).toBeNull();
    expect(parsePathWordsPuzzle({ ...pathWordsDoc, targets: [] })).toBeNull();
  });

  it('accepts the stored routes, in any order', () => {
    expect(checkPathWordsProof(puzzle, { strokes: stored })).toBe(true);
    expect(checkPathWordsProof(puzzle, { strokes: [...stored].reverse() })).toBe(true);
  });

  it('accepts another route that spells the word and stays off other words', () => {
    // "go" also runs g(2,0) → o(1,0).
    const strokes = [stored[0], { targetId: 't2', cells: [[2, 0], [1, 0]] }];
    expect(checkPathWordsProof(puzzle, { strokes })).toBe(true);
  });

  it('refuses proofs that do not solve the board', () => {
    const cases: Record<string, unknown> = {
      'no proof': undefined,
      'missing word': { strokes: [stored[0]] },
      'word twice': { strokes: [stored[0], stored[0]] },
      'unknown target': { strokes: [stored[0], { targetId: 't9', cells: [[2, 0], [2, 1]] }] },
      'gap in a stroke': { strokes: [{ targetId: 't1', cells: [[0, 0], [0, 2], [0, 1]] }, stored[1]] },
      'wrong word': { strokes: [stored[0], { targetId: 't2', cells: [[1, 0], [2, 0]] }] },
      'blank cell': { strokes: [stored[0], { targetId: 't2', cells: [[2, 1], [2, 2]] }] },
      'out of bounds': { strokes: [stored[0], { targetId: 't2', cells: [[2, 0], [3, 0]] }] },
      'reused cell': { strokes: [stored[0], { targetId: 't2', cells: [[2, 0], [2, 0]] }] },
      'bad cells': { strokes: [stored[0], { targetId: 't2', cells: 'go' }] },
    };
    for (const [name, proof] of Object.entries(cases)) {
      expect(checkPathWordsProof(puzzle, proof), name).toBe(false);
    }
  });

  it('refuses another route over a different word, as the app does', () => {
    // Each word's other route runs over the other word's stored cells.
    const doc = {
      size: 2,
      letters: ['a', 't', 't', 'a'],
      targets: [
        { id: 'w1', word: 'at', path: [[0, 0], [0, 1]] },
        { id: 'w2', word: 'ta', path: [[1, 0], [1, 1]] },
      ],
    };
    const board = parsePathWordsPuzzle(doc)!;
    const strokes = [
      { targetId: 'w1', cells: [[0, 0], [1, 0]] },
      { targetId: 'w2', cells: [[0, 1], [1, 1]] },
    ];
    expect(checkPathWordsProof(board, { strokes })).toBe(false);
  });
});

describe('checkProof', () => {
  it('reports a missing or unreadable puzzle', () => {
    expect(checkProof('zip', null, { path: serpentine })).toBe('unknown_puzzle');
    expect(checkProof('sudoku', { given }, { grid: solution })).toBe('unknown_puzzle');
  });

  it('checks the proof against the right game', () => {
    expect(checkProof('zip', zipDoc, { path: serpentine })).toBe('ok');
    expect(checkProof('sudoku', { given, solution }, { grid: solution })).toBe('ok');
    expect(checkProof('sudoku', { given, solution }, { grid: given })).toBe('bad_proof');
    expect(checkProof('path_words', pathWordsDoc, { path: serpentine })).toBe('bad_proof');
  });
});
