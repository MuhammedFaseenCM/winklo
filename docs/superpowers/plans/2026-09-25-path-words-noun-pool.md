# Path Words AI Daily Noun Pool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve Path Words from a shared daily AI-generated noun pool (Cloudflare Worker + KV), with client caching and a bundled `en_nouns.txt` fallback, while keeping local `PathWordsGenerator` packing.

**Architecture:** Worker `GET /v1/path-words/nouns?dateId=` returns or lazily generates a validated noun list into KV. Flutter resolves memory → SharedPreferences → network → bundled nouns, then `GenerateDailyPathWords` feeds that list into the existing generator. Bump `generatorVersion` once so seeds diverge from the old mixed list.

**Tech Stack:** Flutter/Dart, `package:http`, `shared_preferences`, Cloudflare Workers (TypeScript + Wrangler + KV + Workers AI), Vitest, existing Path Words domain.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-25-path-words-noun-pool-design.md`
- Nouns only: lowercase `a–z`, length **3–5**; Worker minimum **80** valid nouns to cache (target ~150)
- Same puzzle for a given `dateId`: shared pool + existing date seed + bumped `generatorVersion`
- Domain stays pure Dart (no Flutter / `http` / `shared_preferences` in `domain/`)
- Public Worker GET (no auth); AI keys stay on Worker
- Stay off Firebase Blaze — Worker only
- User-facing: silent fallback to bundle (no new toast/error copy in v1)
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `assets/words/en_nouns.txt` | Bundled noun fallback (one word per line) |
| `lib/core/config/path_words_nouns_config.dart` | Worker base URL via `--dart-define` |
| `lib/data/clients/path_words/path_words_nouns_client.dart` | Abstract HTTP fetch |
| `lib/data/clients/path_words/http_path_words_nouns_client.dart` | `GET` implementation |
| `lib/domain/repositories/word_list_repository.dart` | Add `loadDailyNouns` |
| `lib/data/repositories/word_list_repository_impl.dart` | Resolve cache → network → bundle |
| `lib/domain/usecases/generate_daily_path_words.dart` | Call `loadDailyNouns` with `dateId` |
| `lib/domain/path_words/path_words_generator.dart` | Bump `generatorVersion` |
| `lib/core/di/app_repositories.dart` | Wire client + prefs into word list repo |
| `pubspec.yaml` | Register `en_nouns.txt` asset |
| `workers/path-words-nouns/` | Wrangler Worker (AI + KV + cron) |
| Tests under `test/...` and `workers/path-words-nouns/` | TDD as below |

---

### Task 1: Bundled noun asset

**Files:**
- Create: `assets/words/en_nouns.txt`
- Modify: `pubspec.yaml` (assets section)
- Test: `test/data/repositories/word_list_repository_impl_test.dart` (extend in Task 4; this task only adds asset)

**Interfaces:**
- Produces: asset path `assets/words/en_nouns.txt` (one lowercase noun per line, many length 3–5)

- [ ] **Step 1: Create the noun list file**

Create `assets/words/en_nouns.txt` with at least **120** unique lowercase ASCII nouns of length 3–5 (so the generator’s length buckets are healthy). Include a mix of lengths. Starter content (extend to ≥120 before finishing the task):

```text
ace
ant
ape
arc
ark
arm
ash
bag
ball
band
bank
barn
bat
bay
beach
bean
bear
bed
bee
bell
belt
bench
bird
boat
bone
book
boot
bowl
box
boy
bread
brick
bridge
brook
broom
brush
bug
bulb
bush
cake
camp
can
cap
car
card
cart
case
cat
cave
chair
cheese
chess
chest
child
chin
chip
city
clam
cliff
clock
cloud
clown
club
coach
coal
coat
cob
coin
comb
cone
cook
cord
corn
couch
cow
crab
crane
crate
crow
crown
cub
cup
desk
dice
dirt
dish
dock
dog
doll
door
dove
drum
duck
dust
ear
earth
eel
egg
elbow
elk
elm
face
fan
farm
feather
fence
fern
field
fig
fin
fire
fish
flag
flame
flask
flea
flood
floor
flour
flower
flute
fly
foam
fog
foil
food
foot
ford
forest
fork
fox
frame
frog
fruit
```

(Trim or add until every line matches `^[a-z]{3,5}$` and count ≥ 120 unique.)

- [ ] **Step 2: Register the asset**

In `pubspec.yaml` under `flutter: assets:`, add:

```yaml
    - assets/words/en_nouns.txt
```

Keep the existing `en_words.txt` entry (other callers may still use it).

- [ ] **Step 3: Sanity-check the file**

Run:

```bash
awk 'BEGIN{c=0} /^[a-z]{3,5}$/{c++} END{print c}' assets/words/en_nouns.txt
```

Expected: integer ≥ `120`

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add assets/words/en_nouns.txt pubspec.yaml
git commit -m "assets: add Path Words bundled noun fallback list"
```

---

### Task 2: Config + nouns HTTP client

**Files:**
- Create: `lib/core/config/path_words_nouns_config.dart`
- Create: `lib/data/clients/path_words/path_words_nouns_client.dart`
- Create: `lib/data/clients/path_words/http_path_words_nouns_client.dart`
- Test: `test/core/config/path_words_nouns_config_test.dart`
- Test: `test/data/clients/path_words/http_path_words_nouns_client_test.dart`

**Interfaces:**
- Produces:

```dart
// lib/core/config/path_words_nouns_config.dart
abstract final class PathWordsNounsConfig {
  static const String baseUrl = String.fromEnvironment(
    'PATH_WORDS_NOUNS_BASE_URL',
    defaultValue: '',
  );
  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}

// lib/data/clients/path_words/path_words_nouns_client.dart
abstract class PathWordsNounsClient {
  /// Fetches the shared daily noun list for [dateId] (`yyyyMMdd`).
  /// Throws on network/HTTP/parse failure (caller falls back).
  Future<List<String>> fetchNouns({required String dateId});
}
```

- Consumes: `package:http`

- [ ] **Step 1: Write failing config + client tests**

```dart
// test/core/config/path_words_nouns_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/config/path_words_nouns_config.dart';

void main() {
  test('baseUrl is a String and isConfigured reflects emptiness', () {
    expect(PathWordsNounsConfig.baseUrl, isA<String>());
    expect(
      PathWordsNounsConfig.isConfigured,
      PathWordsNounsConfig.baseUrl.trim().isNotEmpty,
    );
  });
}
```

```dart
// test/data/clients/path_words/http_path_words_nouns_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winklo/data/clients/path_words/http_path_words_nouns_client.dart';

void main() {
  test('fetchNouns parses words from 200 JSON', () async {
    final client = HttpPathWordsNounsClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://example.test/v1/path-words/nouns?dateId=20260925',
        );
        return http.Response(
          '{"dateId":"20260925","words":["cat","tree","oak"]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final words = await client.fetchNouns(dateId: '20260925');
    expect(words, ['cat', 'tree', 'oak']);
  });

  test('fetchNouns throws on non-2xx', () async {
    final client = HttpPathWordsNounsClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => http.Response('nope', 503),
      ),
    );
    expect(
      () => client.fetchNouns(dateId: '20260925'),
      throwsA(isA<Exception>()),
    );
  });

  test('fetchNouns throws when baseUrl empty', () async {
    final client = HttpPathWordsNounsClient(baseUrl: '');
    expect(
      () => client.fetchNouns(dateId: '20260925'),
      throwsA(isA<Exception>()),
    );
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/core/config/path_words_nouns_config_test.dart test/data/clients/path_words/http_path_words_nouns_client_test.dart`  
Expected: FAIL — libraries not found

- [ ] **Step 3: Implement config + client**

```dart
// lib/core/config/path_words_nouns_config.dart
abstract final class PathWordsNounsConfig {
  static const String baseUrl = String.fromEnvironment(
    'PATH_WORDS_NOUNS_BASE_URL',
    defaultValue: '',
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}
```

```dart
// lib/data/clients/path_words/path_words_nouns_client.dart
abstract class PathWordsNounsClient {
  Future<List<String>> fetchNouns({required String dateId});
}
```

```dart
// lib/data/clients/path_words/http_path_words_nouns_client.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'path_words_nouns_client.dart';

class HttpPathWordsNounsClient implements PathWordsNounsClient {
  HttpPathWordsNounsClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  @override
  Future<List<String>> fetchNouns({required String dateId}) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.isEmpty) {
      throw StateError('Path Words nouns Worker URL is not configured.');
    }

    final uri = Uri.parse('$root/v1/path-words/nouns').replace(
      queryParameters: {'dateId': dateId},
    );
    final response = await _http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Nouns fetch failed: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Nouns fetch returned invalid JSON.');
    }
    final raw = decoded['words'];
    if (raw is! List) {
      throw StateError('Nouns fetch missing words array.');
    }

    return [
      for (final item in raw)
        if (item is String) item.trim().toLowerCase(),
    ].where((w) => RegExp(r'^[a-z]{3,5}$').hasMatch(w)).toList(growable: false);
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/core/config/path_words_nouns_config_test.dart test/data/clients/path_words/http_path_words_nouns_client_test.dart`  
Expected: PASS

- [ ] **Step 5: Format + analyze**

```bash
dart format lib/core/config/path_words_nouns_config.dart \
  lib/data/clients/path_words/path_words_nouns_client.dart \
  lib/data/clients/path_words/http_path_words_nouns_client.dart \
  test/core/config/path_words_nouns_config_test.dart \
  test/data/clients/path_words/http_path_words_nouns_client_test.dart
dart analyze lib/core/config/path_words_nouns_config.dart \
  lib/data/clients/path_words/path_words_nouns_client.dart \
  lib/data/clients/path_words/http_path_words_nouns_client.dart
```

Expected: no issues

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add lib/core/config/path_words_nouns_config.dart \
  lib/data/clients/path_words/ \
  test/core/config/path_words_nouns_config_test.dart \
  test/data/clients/path_words/
git commit -m "feat: add Path Words nouns Worker client and config"
```

---

### Task 3: `loadDailyNouns` on WordListRepository

**Files:**
- Modify: `lib/domain/repositories/word_list_repository.dart`
- Modify: `lib/data/repositories/word_list_repository_impl.dart`
- Modify: `test/data/repositories/word_list_repository_impl_test.dart`
- Create helpers as needed in the test file (MockClient / fake client / `SharedPreferences.setMockInitialValues`)

**Interfaces:**
- Consumes: `PathWordsNounsClient.fetchNouns`, `SharedPreferences`, bundled `en_nouns.txt`
- Produces:

```dart
abstract class WordListRepository {
  Future<List<String>> loadEnglishWords({int minLen = 4, int maxLen = 10});
  Future<List<String>> loadDailyNouns({required String dateId});
}
```

Resolution order inside `loadDailyNouns`: in-memory map → prefs key `path_words_nouns_$dateId` (JSON array string) → network client → load + filter `nounAssetPath` (default `assets/words/en_nouns.txt`, lengths 3–5).

- [ ] **Step 1: Write failing repository tests**

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/clients/path_words/path_words_nouns_client.dart';
import 'package:winklo/data/repositories/word_list_repository_impl.dart';

class _MockNounsClient extends Mock implements PathWordsNounsClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNounsClient nounsClient;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    nounsClient = _MockNounsClient();
  });

  test('loadDailyNouns returns network words and caches them', () async {
    when(() => nounsClient.fetchNouns(dateId: '20260925')).thenAnswer(
      (_) async => ['cat', 'tree', 'ocean'],
    );

    final repo = WordListRepositoryImpl(
      prefs: prefs,
      nounsClient: nounsClient,
      nounAssetPath: 'assets/words/en_nouns.txt',
    );

    final words = await repo.loadDailyNouns(dateId: '20260925');
    expect(words, ['cat', 'ocean', 'tree']); // normalized + sorted
    expect(prefs.getString('path_words_nouns_20260925'), isNotNull);
    verify(() => nounsClient.fetchNouns(dateId: '20260925')).called(1);
  });

  test('loadDailyNouns prefers prefs cache over network', () async {
    await prefs.setString(
      'path_words_nouns_20260925',
      jsonEncode(['dog', 'bird', 'lake']),
    );

    final repo = WordListRepositoryImpl(
      prefs: prefs,
      nounsClient: nounsClient,
      nounAssetPath: 'assets/words/en_nouns.txt',
    );

    final words = await repo.loadDailyNouns(dateId: '20260925');
    expect(words, ['bird', 'dog', 'lake']); // normalized + sorted
    verifyNever(() => nounsClient.fetchNouns(dateId: any(named: 'dateId')));
  });

  test('loadDailyNouns falls back to bundled nouns when network fails', () async {
    when(() => nounsClient.fetchNouns(dateId: '20260925')).thenThrow(
      StateError('offline'),
    );

    final repo = WordListRepositoryImpl(
      prefs: prefs,
      nounsClient: nounsClient,
      nounAssetPath: 'assets/words/en_nouns.txt',
    );

    final words = await repo.loadDailyNouns(dateId: '20260925');
    expect(words, isNotEmpty);
    expect(words.every((w) => w.length >= 3 && w.length <= 5), isTrue);
    expect(words.every((w) => RegExp(r'^[a-z]+$').hasMatch(w)), isTrue);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `flutter test test/data/repositories/word_list_repository_impl_test.dart`  
Expected: FAIL — `loadDailyNouns` missing / constructor args missing

- [ ] **Step 3: Implement interface + repository**

```dart
// lib/domain/repositories/word_list_repository.dart
abstract class WordListRepository {
  Future<List<String>> loadEnglishWords({int minLen = 4, int maxLen = 10});

  /// Shared daily noun pool for Path Words (`dateId` = PlayPeriod id).
  Future<List<String>> loadDailyNouns({required String dateId});
}
```

```dart
// lib/data/repositories/word_list_repository_impl.dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/word_list_repository.dart';
import '../clients/path_words/path_words_nouns_client.dart';

class WordListRepositoryImpl implements WordListRepository {
  WordListRepositoryImpl({
    this.assetPath = 'assets/words/en_words.txt',
    this.nounAssetPath = 'assets/words/en_nouns.txt',
    SharedPreferences? prefs,
    PathWordsNounsClient? nounsClient,
  }) : _prefs = prefs,
       _nounsClient = nounsClient;

  final String assetPath;
  final String nounAssetPath;
  final SharedPreferences? _prefs;
  final PathWordsNounsClient? _nounsClient;

  List<String>? _englishCache;
  final Map<String, List<String>> _dailyMemory = {};

  static String prefsKey(String dateId) => 'path_words_nouns_$dateId';

  @override
  Future<List<String>> loadEnglishWords({
    int minLen = 4,
    int maxLen = 10,
  }) async {
    final all = await _loadAsset(assetPath, cacheEnglish: true);
    return all
        .where((w) => w.length >= minLen && w.length <= maxLen)
        .toList(growable: false);
  }

  @override
  Future<List<String>> loadDailyNouns({required String dateId}) async {
    final mem = _dailyMemory[dateId];
    if (mem != null) return mem;

    final prefs = _prefs;
    if (prefs != null) {
      final raw = prefs.getString(prefsKey(dateId));
      if (raw != null && raw.isNotEmpty) {
        final parsed = _parseJsonWords(raw);
        if (parsed.isNotEmpty) {
          _dailyMemory[dateId] = parsed;
          return parsed;
        }
      }
    }

    final client = _nounsClient;
    if (client != null) {
      try {
        final remote = await client.fetchNouns(dateId: dateId);
        final cleaned = _normalizeNouns(remote);
        if (cleaned.isNotEmpty) {
          await prefs?.setString(prefsKey(dateId), jsonEncode(cleaned));
          _dailyMemory[dateId] = cleaned;
          return cleaned;
        }
      } catch (_) {
        // Fall through to bundle.
      }
    }

    final bundled = _normalizeNouns(
      await _loadAsset(nounAssetPath, cacheEnglish: false),
    );
    _dailyMemory[dateId] = bundled;
    return bundled;
  }

  List<String> _parseJsonWords(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return _normalizeNouns([
        for (final item in decoded)
          if (item is String) item,
      ]);
    } catch (_) {
      return const [];
    }
  }

  List<String> _normalizeNouns(Iterable<String> words) {
    return words
        .map((w) => w.trim().toLowerCase())
        .where((w) => RegExp(r'^[a-z]{3,5}$').hasMatch(w))
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  Future<List<String>> _loadAsset(
    String path, {
    required bool cacheEnglish,
  }) async {
    if (cacheEnglish) {
      final cached = _englishCache;
      if (cached != null) return cached;
    }
    final raw = await rootBundle.loadString(path);
    final parsed =
        raw
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim().toLowerCase())
            .where((w) => RegExp(r'^[a-z]+$').hasMatch(w))
            .toSet()
            .toList()
          ..sort();
    if (cacheEnglish) _englishCache = parsed;
    return parsed;
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/data/repositories/word_list_repository_impl_test.dart`  
Expected: PASS (keep the existing `loadEnglishWords` test working; construct repo without required client/prefs for that test or pass mocks)

- [ ] **Step 5: Format + analyze changed Dart files**

```bash
dart format lib/domain/repositories/word_list_repository.dart \
  lib/data/repositories/word_list_repository_impl.dart \
  test/data/repositories/word_list_repository_impl_test.dart
dart analyze lib/domain/repositories/word_list_repository.dart \
  lib/data/repositories/word_list_repository_impl.dart
```

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add lib/domain/repositories/word_list_repository.dart \
  lib/data/repositories/word_list_repository_impl.dart \
  test/data/repositories/word_list_repository_impl_test.dart
git commit -m "feat: resolve Path Words daily nouns via cache, network, bundle"
```

---

### Task 4: Usecase + generator version + DI

**Files:**
- Modify: `lib/domain/usecases/generate_daily_path_words.dart`
- Modify: `lib/domain/path_words/path_words_generator.dart` (`generatorVersion` → `6`)
- Modify: `lib/core/di/app_repositories.dart`
- Modify: `test/domain/usecases/generate_daily_path_words_test.dart`
- Modify any generator tests that hard-assert version `5` if present

**Interfaces:**
- Consumes: `WordListRepository.loadDailyNouns({required String dateId})`
- Produces: usecase still returns `Future<PathWordsPuzzle>`

- [ ] **Step 1: Update usecase test to expect `loadDailyNouns`**

```dart
test('loads daily nouns and generates puzzle', () async {
  when(
    () => repo.loadDailyNouns(dateId: '20260917'),
  ).thenAnswer((_) async => fixtureWords);

  final puzzle = await usecase(day: DateTime(2026, 9, 17));

  expect(puzzle.id, 'path_words_20260917');
  expect(puzzle.size, inInclusiveRange(3, 6));
  expect(puzzle.targets.length, inInclusiveRange(3, 6));
  verify(() => repo.loadDailyNouns(dateId: '20260917')).called(1);
});
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `flutter test test/domain/usecases/generate_daily_path_words_test.dart`  
Expected: FAIL — still calling `loadEnglishWords` / missing stub

- [ ] **Step 3: Implement usecase + bump version + DI**

```dart
// lib/domain/usecases/generate_daily_path_words.dart
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/path_words/path_words_generator.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/word_list_repository.dart';

class GenerateDailyPathWords {
  GenerateDailyPathWords(this._words, {this.period = PlayPeriod.daily});
  final WordListRepository _words;
  final Duration period;

  Future<PathWordsPuzzle> call({required DateTime day}) async {
    final local = day.toLocal();
    final bucket = PlayPeriod.bucket(local, period);
    final dateId = PlayPeriod.id(bucket, period);
    final list = await _words.loadDailyNouns(dateId: dateId);
    return PathWordsGenerator.generate(day: day, words: list, period: period);
  }
}
```

In `path_words_generator.dart`:

```dart
static const generatorVersion = 6;
```

In `app_repositories.dart`, import config + HTTP client, change WordList registration to:

```dart
RepositoryProvider<PathWordsNounsClient>(
  create: (_) => HttpPathWordsNounsClient(
    baseUrl: PathWordsNounsConfig.baseUrl,
  ),
),
RepositoryProvider<WordListRepository>(
  create: (context) => WordListRepositoryImpl(
    prefs: context.read<SharedPreferences>(),
    nounsClient: context.read<PathWordsNounsClient>(),
  ),
),
```

- [ ] **Step 4: Run related tests**

```bash
flutter test \
  test/domain/usecases/generate_daily_path_words_test.dart \
  test/domain/path_words/path_words_generator_test.dart \
  test/data/repositories/word_list_repository_impl_test.dart
```

Expected: PASS

- [ ] **Step 5: Format + analyze**

```bash
dart format lib/domain/usecases/generate_daily_path_words.dart \
  lib/domain/path_words/path_words_generator.dart \
  lib/core/di/app_repositories.dart \
  test/domain/usecases/generate_daily_path_words_test.dart
dart analyze lib/domain/usecases/generate_daily_path_words.dart \
  lib/domain/path_words/path_words_generator.dart \
  lib/core/di/app_repositories.dart
```

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add lib/domain/usecases/generate_daily_path_words.dart \
  lib/domain/path_words/path_words_generator.dart \
  lib/core/di/app_repositories.dart \
  test/domain/usecases/generate_daily_path_words_test.dart
git commit -m "feat: Path Words daily puzzles use noun pools and generator v6"
```

---

### Task 5: Worker noun validation module (TDD)

**Files:**
- Create: `workers/path-words-nouns/package.json`
- Create: `workers/path-words-nouns/tsconfig.json`
- Create: `workers/path-words-nouns/vitest.config.ts`
- Create: `workers/path-words-nouns/src/nouns.ts`
- Create: `workers/path-words-nouns/src/nouns.test.ts`

**Interfaces:**
- Produces:

```ts
export const MIN_NOUN_COUNT = 80;
export const TARGET_NOUN_COUNT = 150;

export function normalizeNouns(input: unknown): string[];
/** true if length >= MIN_NOUN_COUNT */
export function hasEnoughNouns(words: string[]): boolean;
```

- [ ] **Step 1: Scaffold package + failing test**

`package.json`:

```json
{
  "name": "winklo-path-words-nouns",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20250901.0",
    "typescript": "^5.6.0",
    "vitest": "^3.0.0",
    "wrangler": "^4.0.0"
  }
}
```

`src/nouns.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { hasEnoughNouns, normalizeNouns, MIN_NOUN_COUNT } from './nouns';

describe('normalizeNouns', () => {
  it('lowercases, filters length 3-5, dedupes, sorts', () => {
    expect(
      normalizeNouns(['Cat', 'TREE', 'ok', 'ab', 'toolong', 'cat', 'oak!']),
    ).toEqual(['cat', 'tree']);
  });

  it('accepts only array inputs', () => {
    expect(normalizeNouns(null)).toEqual([]);
    expect(normalizeNouns('cat')).toEqual([]);
  });
});

describe('hasEnoughNouns', () => {
  it(`requires at least ${MIN_NOUN_COUNT}`, () => {
    expect(hasEnoughNouns(Array(MIN_NOUN_COUNT - 1).fill('cat'))).toBe(false);
    expect(hasEnoughNouns(Array(MIN_NOUN_COUNT).fill('dog'))).toBe(true);
  });
});
```

- [ ] **Step 2: Run vitest — expect FAIL**

```bash
cd workers/path-words-nouns && npm install && npm test
```

Expected: FAIL — module missing

- [ ] **Step 3: Implement `nouns.ts`**

```ts
export const MIN_NOUN_COUNT = 80;
export const TARGET_NOUN_COUNT = 150;

const NOUN_RE = /^[a-z]{3,5}$/;

export function normalizeNouns(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  const set = new Set<string>();
  for (const item of input) {
    if (typeof item !== 'string') continue;
    const w = item.trim().toLowerCase();
    if (NOUN_RE.test(w)) set.add(w);
  }
  return [...set].sort();
}

export function hasEnoughNouns(words: string[]): boolean {
  return words.length >= MIN_NOUN_COUNT;
}
```

- [ ] **Step 4: Run vitest — expect PASS**

```bash
cd workers/path-words-nouns && npm test
```

Expected: PASS

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add workers/path-words-nouns/
git commit -m "feat: add Path Words nouns Worker validation helpers"
```

---

### Task 6: Worker HTTP + KV + AI + cron

**Files:**
- Create: `workers/path-words-nouns/wrangler.toml`
- Create: `workers/path-words-nouns/src/index.ts`
- Create: `workers/path-words-nouns/src/ai.ts`
- Create: `workers/path-words-nouns/README.md`
- Modify: `workers/path-words-nouns/src/nouns.test.ts` (optional parse helpers if extracted)

**Interfaces:**
- Produces: `GET /v1/health`, `GET /v1/path-words/nouns?dateId=yyyyMMdd`
- Env: `NOUNS` KV namespace, `AI` Workers AI binding
- Cron: `0 0 * * *` (UTC midnight) pre-warms UTC today + tomorrow

- [ ] **Step 1: Add `wrangler.toml`**

```toml
name = "winklo-path-words-nouns"
main = "src/index.ts"
compatibility_date = "2026-09-01"

[[kv_namespaces]]
binding = "NOUNS"
id = "REPLACE_AFTER_wrangler_kv_namespace_create"
preview_id = "REPLACE_PREVIEW"

[ai]
binding = "AI"

[triggers]
crons = ["0 0 * * *"]
```

Create the KV namespace once:

```bash
cd workers/path-words-nouns
npx wrangler kv namespace create path-words-nouns
npx wrangler kv namespace create path-words-nouns --preview
```

Paste the returned ids into `wrangler.toml`.

- [ ] **Step 2: Implement AI helper**

```ts
// src/ai.ts
import {
  TARGET_NOUN_COUNT,
  normalizeNouns,
} from './nouns';

export interface AiBinding {
  run(model: string, inputs: Record<string, unknown>): Promise<unknown>;
}

const PROMPT = `Return ONLY a JSON array of about ${TARGET_NOUN_COUNT} common English nouns.
Each noun must be lowercase ASCII letters only and length 3, 4, or 5.
No verbs, adjectives, proper nouns, or explanations. Example: ["cat","tree","ocean"]`;

export async function generateNounCandidates(ai: AiBinding): Promise<string[]> {
  const result = await ai.run('@cf/meta/llama-3.1-8b-instruct', {
    messages: [
      { role: 'system', content: 'You output JSON arrays only.' },
      { role: 'user', content: PROMPT },
    ],
  });

  const text = extractText(result);
  const json = extractJsonArray(text);
  return normalizeNouns(json);
}

function extractText(result: unknown): string {
  if (typeof result === 'string') return result;
  if (result && typeof result === 'object') {
    const r = result as Record<string, unknown>;
    if (typeof r.response === 'string') return r.response;
    if (typeof r.text === 'string') return r.text;
  }
  return '';
}

function extractJsonArray(text: string): unknown {
  const start = text.indexOf('[');
  const end = text.lastIndexOf(']');
  if (start < 0 || end < start) return [];
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return [];
  }
}
```

(If the model id differs in your account, swap to a Workers AI text model that is enabled; keep the same prompt contract.)

- [ ] **Step 3: Implement `index.ts`**

```ts
import { generateNounCandidates } from './ai';
import { hasEnoughNouns, normalizeNouns, MIN_NOUN_COUNT } from './nouns';

export interface Env {
  NOUNS: KVNamespace;
  AI: AiBinding;
}

interface AiBinding {
  run(model: string, inputs: Record<string, unknown>): Promise<unknown>;
}

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

function kvKey(dateId: string): string {
  return `path_words_nouns:${dateId}`;
}

function isValidDateId(dateId: string): boolean {
  return /^\d{8}$/.test(dateId);
}

function utcDateId(d = new Date()): string {
  const y = d.getUTCFullYear().toString().padStart(4, '0');
  const m = (d.getUTCMonth() + 1).toString().padStart(2, '0');
  const day = d.getUTCDate().toString().padStart(2, '0');
  return `${y}${m}${day}`;
}

function addUtcDays(dateId: string, days: number): string {
  const y = Number(dateId.slice(0, 4));
  const m = Number(dateId.slice(4, 6));
  const d = Number(dateId.slice(6, 8));
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + days);
  return utcDateId(dt);
}

async function readPool(
  env: Env,
  dateId: string,
): Promise<{ dateId: string; words: string[] } | null> {
  const raw = await env.NOUNS.get(kvKey(dateId));
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as { dateId?: string; words?: unknown };
    const words = normalizeNouns(parsed.words);
    if (!hasEnoughNouns(words)) return null;
    return { dateId, words };
  } catch {
    return null;
  }
}

async function getOrCreatePool(
  env: Env,
  dateId: string,
): Promise<{ dateId: string; words: string[] } | null> {
  const existing = await readPool(env, dateId);
  if (existing) return existing;

  let words = await generateNounCandidates(env.AI);
  if (!hasEnoughNouns(words)) {
    words = await generateNounCandidates(env.AI);
  }
  if (!hasEnoughNouns(words)) {
    return null;
  }

  const raced = await readPool(env, dateId);
  if (raced) return raced;

  const body = { dateId, words };
  await env.NOUNS.put(kvKey(dateId), JSON.stringify(body));
  return body;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/v1/health') {
      return jsonResponse({ ok: true });
    }

    if (
      request.method === 'GET' &&
      url.pathname === '/v1/path-words/nouns'
    ) {
      const dateId = url.searchParams.get('dateId') ?? '';
      if (!isValidDateId(dateId)) {
        return jsonResponse({ error: 'invalid_dateId' }, 400);
      }
      const pool = await getOrCreatePool(env, dateId);
      if (!pool) {
        return jsonResponse(
          { error: 'insufficient_nouns', min: MIN_NOUN_COUNT },
          503,
        );
      }
      return jsonResponse(pool);
    }

    return jsonResponse({ error: 'not_found' }, 404);
  },

  async scheduled(
    _controller: ScheduledController,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<void> {
    const today = utcDateId();
    const tomorrow = addUtcDays(today, 1);
    ctx.waitUntil(
      Promise.all([getOrCreatePool(env, today), getOrCreatePool(env, tomorrow)]),
    );
  },
};
```

- [ ] **Step 4: Local smoke**

```bash
cd workers/path-words-nouns
npm run test
npx wrangler dev
```

In another terminal:

```bash
curl -s http://127.0.0.1:8787/v1/health
curl -s 'http://127.0.0.1:8787/v1/path-words/nouns?dateId=20260925' | head -c 400
```

Expected: `{"ok":true}` then JSON with `words` length ≥ 80 (requires AI binding in dev; if AI unavailable locally, stub `generateNounCandidates` behind an env flag for tests only — do not ship empty lists).

- [ ] **Step 5: README**

Document: `npm install`, KV create, deploy, Flutter dart-define:

```bash
flutter run --dart-define=PATH_WORDS_NOUNS_BASE_URL=https://winklo-path-words-nouns.<account>.workers.dev
```

- [ ] **Step 6: Deploy** (when ready)

```bash
cd workers/path-words-nouns && npm run deploy
```

- [ ] **Step 7: Commit** (only if user asked; do not commit secrets or `node_modules`)

```bash
git add workers/path-words-nouns/README.md \
  workers/path-words-nouns/package.json \
  workers/path-words-nouns/package-lock.json \
  workers/path-words-nouns/tsconfig.json \
  workers/path-words-nouns/vitest.config.ts \
  workers/path-words-nouns/wrangler.toml \
  workers/path-words-nouns/src/
git commit -m "feat: add Path Words daily nouns Cloudflare Worker"
```

Ensure `.gitignore` ignores Worker deps — add (if missing):

```gitignore
workers/**/node_modules/
```

Do not commit `node_modules` or Wrangler account caches.

---

### Task 7: End-to-end verification

**Files:** none new (manual + automated regression)

- [ ] **Step 1: Flutter regression**

```bash
flutter test \
  test/data/repositories/word_list_repository_impl_test.dart \
  test/data/clients/path_words/http_path_words_nouns_client_test.dart \
  test/domain/usecases/generate_daily_path_words_test.dart \
  test/domain/path_words/ \
  test/features/path_words/
```

Expected: PASS

- [ ] **Step 2: Manual device check**

1. Run app with dart-define pointing at deployed Worker.
2. Open Path Words — words should all read as nouns.
3. Two devices / two installs same local calendar day after successful fetch → same target words.
4. Kill network after one successful open → still same puzzle (prefs cache).
5. Clear app data + airplane mode → bundled nouns puzzle (may differ until first fetch).

- [ ] **Step 3: Commit docs touch if README/FIREBASE note added** (only if user asked)

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Nouns only length 3–5 | Tasks 1, 3, 5, 6 |
| Runtime AI on Worker, not device | Task 6 |
| Shared daily pool / same puzzle per `dateId` | Tasks 4, 6 |
| Client packing retained | Task 4 |
| Resolution memory → cache → network → bundle | Task 3 |
| Bundled `en_nouns.txt` | Task 1 |
| Min 80 / target ~150 + retry | Tasks 5–6 |
| Cron pre-warm UTC today+tomorrow | Task 6 |
| Public GET API contract | Task 6 |
| `PATH_WORDS_NOUNS_BASE_URL` | Tasks 2, 4, 6 |
| `generatorVersion` bump | Task 4 |
| Worker + client tests | Tasks 2, 3, 5, 7 |
| No Firebase Blaze | Task 6 (Worker only) |
