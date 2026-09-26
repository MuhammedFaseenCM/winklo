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
      httpClient: MockClient((_) async => http.Response('nope', 503)),
    );
    expect(
      () => client.fetchNouns(dateId: '20260925'),
      throwsA(isA<StateError>()),
    );
  });

  test('fetchNouns throws when baseUrl empty', () async {
    final client = HttpPathWordsNounsClient(baseUrl: '');
    expect(
      () => client.fetchNouns(dateId: '20260925'),
      throwsA(isA<StateError>()),
    );
  });
}
