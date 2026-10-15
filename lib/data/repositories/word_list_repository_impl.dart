import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/word_list_repository.dart';
import '../clients/path_words/path_words_nouns_client.dart';

class WordListRepositoryImpl implements WordListRepository {
  WordListRepositoryImpl({
    this.assetPath = 'assets/words/en_bonus_words.txt',
    this.nounAssetPath = 'assets/words/en_nouns.txt',
    this._prefs,
    this._nounsClient,
    AssetBundle? bundle,
  }) : _bundle = bundle;

  /// The English word list: ENABLE, 4–8 letters (see [loadBonusWords]).
  final String assetPath;
  final String nounAssetPath;
  final SharedPreferences? _prefs;
  final PathWordsNounsClient? _nounsClient;
  final AssetBundle? _bundle;

  List<String>? _englishCache;
  Future<Set<String>>? _bonusWords;
  final Map<String, List<String>> _dailyMemory = {};

  AssetBundle get _assets => _bundle ?? rootBundle;

  @override
  Future<Set<String>> loadBonusWords() {
    return _bonusWords ??= _readBonusWords().catchError((
      Object error,
      StackTrace stack,
    ) {
      _bonusWords = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<Set<String>> _readBonusWords() async {
    final raw = await _assets.loadString(assetPath, cache: false);
    final pattern = RegExp(r'^[a-z]{4,8}$');
    return Set<String>.unmodifiable({
      for (final line in raw.split('\n'))
        if (pattern.hasMatch(line.trim())) line.trim(),
    });
  }

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
    final raw = await _assets.loadString(path);
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
