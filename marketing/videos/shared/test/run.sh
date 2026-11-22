#!/usr/bin/env bash
# Asserts: broken fixture is rejected (exit 1), real puzzle is accepted (exit 0).
set -u
cd "$(dirname "$0")/.."
node validate-zip.mjs test/broken-diagonal.json; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: broken fixture exited $rc, expected 1"; exit 1; }
node validate-zip.mjs zip-puzzle.json; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: zip-puzzle.json exited $rc, expected 0"; exit 1; }
echo "PASS"
