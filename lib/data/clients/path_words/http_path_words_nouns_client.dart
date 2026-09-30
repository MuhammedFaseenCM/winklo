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

    final uri = Uri.parse(
      '$root/v1/path-words/nouns',
    ).replace(queryParameters: {'dateId': dateId});
    final response = await _http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Nouns fetch failed: HTTP ${response.statusCode}');
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
