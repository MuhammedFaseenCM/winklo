# Path Words — AI daily noun pool — design

Date: 2026-09-25  
Status: approved (design sections §1–§3)

## Goal

Path Words must use **nouns only**. Each calendar day, a **shared noun pool** is produced once by **runtime AI on a Cloudflare Worker**, cached, and fetched by clients so every player gets the **same seeded puzzle**. Clients keep packing locally via `PathWordsGenerator`. If the daily pool is unavailable, fall back to a **bundled noun-only** asset; after a successful fetch, **cache locally** so later offline play still matches the global day.

## Product decisions

| Topic | Choice |
|-------|--------|
| Word type | Nouns only (length 3–5, lowercase `a–z`) |
| AI where | Server (Cloudflare Worker), never on-device |
| Same puzzle for all | Yes — shared daily pool + existing date seed |
| Puzzle packing | Remains on client (`PathWordsGenerator`) |
| Offline / fail | Bundled `assets/words/en_nouns.txt` if no network and no local cache for that `dateId` |
| After first fetch | Persist pool for `dateId` (`shared_preferences`) |
| Firebase | No Blaze / Cloud Functions required |
| Old mixed list | Path Words stops using `en_words.txt` |

## Out of scope

- Calling AI from the Flutter app
- Moving path packing to the server
- Thematic / multi-language packs
- Guaranteeing perfect NLP noun purity from the model (charset + length validation only)
- Blocking UX / hard error when falling back to bundled nouns (v1: silent fallback)
- Offline toast / “using offline nouns” messaging (v1 skip)

## Architecture

```text
Cron (UTC day start; pre-warm UTC `dateId` for today + tomorrow) OR first GET miss
    → Cloudflare Worker
        → AI (Workers AI preferred; external LLM secret as fallback)
        → validate: lowercase a–z, length 3–5, dedupe
        → if count < 80: one retry; still short → do not cache (clients fall back)
        → KV put path_words_nouns:{dateId} → { dateId, words: string[] }
    ← 200 JSON

Flutter
    → dateId = PlayPeriod.id(local day) (unchanged; TZ differences already exist today)
    → resolve noun pool:
         1. in-memory
         2. local cache (shared_preferences) for dateId
         3. GET Worker /v1/path-words/nouns?dateId=…
            on success → write local cache
         4. bundled assets/words/en_nouns.txt
    → GenerateDailyPathWords → PathWordsGenerator.generate(day, words)
```

Same `dateId` + same shared `words` + same `generatorVersion` ⇒ identical puzzle for every client on that `dateId`. Other timezones may use a different `dateId` for “today” — same as Path Words seeding today.

### Components

| Piece | Location |
|-------|----------|
| Worker | `workers/path-words-nouns/` (new Wrangler project) |
| KV | Binding for daily pools; key `path_words_nouns:{dateId}` |
| HTTP | Public `GET /v1/path-words/nouns?dateId=yyyyMMdd` (no auth; response is non-secret) |
| Client | `lib/data/clients/path_words/path_words_nouns_client.dart` |
| Config | `lib/core/config/path_words_nouns_config.dart` — `PATH_WORDS_NOUNS_BASE_URL` via `--dart-define` |
| Repository | Add `WordListRepository.loadDailyNouns({required String dateId})` implemented in `WordListRepositoryImpl` (network + cache + `en_nouns.txt` fallback). Keep `loadEnglishWords` for any non–Path Words callers of `en_words.txt`. |
| Usecase | `GenerateDailyPathWords` calls `loadDailyNouns` with the day’s `dateId` |
| Bundle | `assets/words/en_nouns.txt` — curated nouns usable at lengths 3–5 |
| Local cache | `shared_preferences` key scoped by `dateId` |

### State ownership

- **Worker** — source of truth for the global daily noun list (KV)
- **Device cache** — last successful fetch per `dateId`
- **Puzzle** — still owned by client generator + Bloc (unchanged play rules)

## Worker behavior

1. **Read path:** If KV has `path_words_nouns:{dateId}`, return it.
2. **Miss:** Call AI with a fixed prompt requesting common English **nouns**, length 3–5, JSON array only. Target ~150 unique valid nouns after filter; minimum **80** to accept.
3. **Validate:** trim, lowercase, `^[a-z]+$`, length in `[3,5]`, unique. Drop invalid entries.
4. **Retry once** if below minimum; if still below, return error (no KV write) so clients use bundle/cache.
5. **Idempotency:** Concurrent misses should not overwrite with different lists — use single-flight / “write if absent” so the first successful generation wins for that `dateId`.
6. **Cron:** Scheduled trigger at UTC day start pre-warms UTC today + tomorrow. Other `dateId` values (other local midnights) are filled lazily on first GET.

### AI provider

Prefer **Cloudflare Workers AI** if quality/latency is acceptable; otherwise an external LLM via Worker secret. Provider is an implementation detail; the public contract is the JSON noun list.

## Client behavior

**Resolution order:** memory → local cache → network → bundled nouns.

**Loading:** Existing Path Words load UI; network only adds latency on cold miss.

**Fallback:** If network fails and there is no cache for that `dateId`, use `en_nouns.txt`. Players who never fetched may briefly see a **different** puzzle than the global AI day until they sync once — accepted edge case.

**Generator version:** Bump `PathWordsGenerator.generatorVersion` once when shipping so pre-change mixed-list seeds do not collide with noun-pool days.

**Config:**

```bash
flutter run --dart-define=PATH_WORDS_NOUNS_BASE_URL=https://<worker-host>
```

## API contract

`GET /v1/path-words/nouns?dateId=20260925`

Success:

```json
{
  "dateId": "20260925",
  "words": ["cat", "tree", "ocean", "..."]
}
```

- `words`: unique lowercase ASCII nouns, each length 3–5 inclusive  
- Error / not ready: non-2xx; client falls through to cache/bundle  

Health: `GET /v1/health` → `{ "ok": true }` (same pattern as avatar worker).

## Testing

| Layer | Coverage |
|-------|----------|
| Worker | Filter/validate AI-like payloads; refuse cache below min count; second GET returns same KV body |
| Client repository | Resolution order: cache hit skips network; network success writes cache; failure uses bundle |
| Generator / usecase | Fixture noun list; bump version covered by existing determinism tests |
| Integration (manual) | Two devices same day → same targets after both fetch; airplane mode after cache → same; never-fetched → bundle |

## Rollout / docs

- Document Worker setup + dart-define in Worker README (and a short note in `FIREBASE.md` only if cross-linking infra; Path Words nouns are not Firebase).
- Register `assets/words/en_nouns.txt` in `pubspec.yaml`.
- Do not commit Worker secrets; use Wrangler secrets for any external API key.

## Open implementation choices (non-blocking)

- Exact Workers AI model id / prompt wording — tuned during implementation against the ≥80 valid-noun bar.
- Whether `loadDailyNouns` lives on `WordListRepository` vs a dedicated `PathWordsNounPoolRepository` — default to extending `WordListRepository` unless the interface grows awkward.
