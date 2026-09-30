# Static assets (R2)

Source PNGs for app UI images served from the public `winklo-avatars` R2 bucket
under `static/`. These are **not** Flutter assets — do not add this folder to
`pubspec.yaml`.

## Object keys

| Local path | R2 key |
|---|---|
| `games/zip_tile.png` | `static/games/zip_tile.png` |
| `games/path_words_tile.png` | `static/games/path_words_tile.png` |
| `games/sudoku_tile.png` | `static/games/sudoku_tile.png` |
| `medals/medal_*.png` | `static/medals/medal_*.png` |
| `avatars/preset_*.png` | `static/avatars/preset_*.png` |

Public URL: `$PUBLIC_BASE_URL/static/...`  
(default `https://pub-94fd8286c7fa4508a0e988821039d2a8.r2.dev`).

After replacing art, re-upload the changed files (same keys) with `--remote`. Clients cache long-lived; bump the filename in code if you need an immediate bust.

```bash
# From repo root:
for f in tools/static-assets/games/*.png tools/static-assets/medals/*.png tools/static-assets/avatars/*.png; do
  rel="${f#tools/static-assets/}"
  npx --prefix workers/avatar-upload wrangler r2 object put \
    "winklo-avatars/static/$rel" \
    --file="$f" \
    --content-type="image/png" \
    --cache-control="public, max-age=31536000" \
    --remote
done
```
