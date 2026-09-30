# winklo-path-words-nouns

Cloudflare Worker that serves a shared daily Path Words noun pool (AI-generated, KV-cached).

## API

- `GET /v1/health` → `{"ok":true}`
- `GET /v1/path-words/nouns?dateId=yyyyMMdd` → `{"dateId":"…","words":["cat",…]}`

Words are lowercase ASCII nouns, length 3–5. A pool is cached in KV only when ≥80 valid nouns are produced.

## Setup

```bash
cd workers/path-words-nouns
npm install
npx wrangler kv namespace create path-words-nouns
npx wrangler kv namespace create path-words-nouns --preview
```

Paste the returned KV ids into `wrangler.toml`, then:

```bash
npm test
npm run deploy
```

## Flutter

```bash
flutter run --dart-define=PATH_WORDS_NOUNS_BASE_URL=https://winklo-path-words-nouns.<account>.workers.dev
```

## Notes

- Model: `@cf/meta/llama-3.2-3b-instruct` (older `llama-3.1-8b-instruct` is deprecated on Workers AI).
- If AI returns too few valid 3–5 letter nouns, the Worker fills from a bundled curated list (date-shuffled) so every day still gets a cacheable ≥80-word pool.
- First request for a `dateId` can take ~20–30s; later requests are served from KV.
