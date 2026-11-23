#!/usr/bin/env bash
# Asserts: broken fixture is rejected (exit 1), real puzzles are accepted (exit 0), and all differ.
set -u
cd "$(dirname "$0")/.."
node validate-zip.mjs test/broken-diagonal.json; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: broken fixture exited $rc, expected 1"; exit 1; }
for f in zip-puzzle.json zip-puzzle-b.json zip-puzzle-c.json zip-puzzle-d.json; do
  node validate-zip.mjs "$f" >/dev/null; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL: $f exited $rc, expected 0"; exit 1; }
done
node test/distinct.mjs || { echo "FAIL: puzzles not distinct"; exit 1; }
node test/shape.mjs || { echo "FAIL: puzzle shape rule"; exit 1; }
echo "PASS"
