#!/usr/bin/env bash
# Renders the critter SVGs in assets/avatars/ to 512 px PNGs under the R2
# preset keys (avatars/preset_XX.png), for app builds from before the
# critters were bundled. Run from the repo root; needs Google Chrome.
set -euo pipefail

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT=tools/static-assets/avatars
WORK=$(mktemp -d)
trap 'pkill -f "$WORK/profile" 2>/dev/null || true; rm -rf "$WORK"' EXIT

# id:critter, as in lib/domain/avatars/avatar_catalog.dart (a test checks).
PRESETS=(
  preset_01:fox
  preset_02:panda
  preset_03:cat
  preset_04:bear
  preset_05:owl
  preset_06:bunny
  preset_07:frog
  preset_08:penguin
  preset_09:tiger
  preset_10:koala
  preset_11:raccoon
  preset_12:chick
)

for pair in "${PRESETS[@]}"; do
  id=${pair%%:*}
  critter=${pair#*:}
  page="$WORK/$id.html"
  printf '<!doctype html><html><body style="margin:0"><img src="file://%s" width="512" height="512" style="display:block"></body></html>' \
    "$PWD/assets/avatars/$critter.svg" > "$page"
  rm -f "$OUT/$id.png"
  "$CHROME" --headless=new --disable-gpu --no-first-run --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=512,512 \
    --virtual-time-budget=1000 --allow-file-access-from-files \
    --user-data-dir="$WORK/profile" --screenshot="$PWD/$OUT/$id.png" \
    "file://$page" >/dev/null 2>&1 &
  pid=$!
  # Chrome 155 can hang after writing the file: wait up to 40 s, then kill it.
  for _ in $(seq 1 40); do
    [ -s "$OUT/$id.png" ] && break
    sleep 1
  done
  sleep 1
  kill "$pid" 2>/dev/null || true
  pkill -f "$WORK/profile" 2>/dev/null || true
  [ -s "$OUT/$id.png" ] || { echo "Failed: $id" >&2; exit 1; }
  echo "$OUT/$id.png ($critter)"
done
