import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winklo/data/clients/leaderboard/http_leaderboard_submit_client.dart';
import 'package:winklo/data/clients/leaderboard/leaderboard_submit_client.dart';

void main() {
  HttpLeaderboardSubmitClient clientFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => HttpLeaderboardSubmitClient(
    baseUrl: 'https://lb.example/',
    httpClient: MockClient(handler),
  );

  const body = {'gameId': 'zip', 'timeSeconds': 42};

  test('posts the body with the ID token and reads the reply', () async {
    late http.Request sent;
    final client = clientFor((request) async {
      sent = request;
      return http.Response(
        jsonEncode({'accepted': true, 'improved': true, 'rank': null}),
        200,
      );
    });

    final result = await client.submit(idToken: 'tok', body: body);

    expect(result.improved, isTrue);
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'https://lb.example/v1/submit');
    expect(sent.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(sent.body), body);
  });

  test('a 4xx is a final rejection with its code', () async {
    final client = clientFor(
      (_) async => http.Response(jsonEncode({'error': 'bad_proof'}), 422),
    );
    await expectLater(
      client.submit(idToken: 'tok', body: body),
      throwsA(
        isA<LeaderboardSubmitRejected>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.code, 'code', 'bad_proof'),
      ),
    );
  });

  test('a 401 is a rejection too', () async {
    final client = clientFor(
      (_) async => http.Response(jsonEncode({'error': 'unauthorized'}), 401),
    );
    await expectLater(
      client.submit(idToken: 'tok', body: body),
      throwsA(isA<LeaderboardSubmitRejected>()),
    );
  });

  test('a 5xx means the Worker is unavailable', () async {
    final client = clientFor(
      (_) async => http.Response(jsonEncode({'error': 'busy'}), 503),
    );
    await expectLater(
      client.submit(idToken: 'tok', body: body),
      throwsA(isA<LeaderboardSubmitUnavailable>()),
    );
  });

  test('a network error means the Worker is unavailable', () async {
    final client = clientFor((_) async => throw const SocketException('down'));
    await expectLater(
      client.submit(idToken: 'tok', body: body),
      throwsA(isA<LeaderboardSubmitUnavailable>()),
    );
  });

  test('a slow Worker times out as unavailable', () async {
    final client = HttpLeaderboardSubmitClient(
      baseUrl: 'https://lb.example',
      timeout: const Duration(milliseconds: 10),
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.submit(idToken: 'tok', body: body),
      throwsA(isA<LeaderboardSubmitUnavailable>()),
    );
  });

  test('a garbled 200 is not taken as accepted', () async {
    final client = clientFor((_) async => http.Response('<html>', 200));
    await expectLater(
      client.submit(idToken: 'tok', body: body),
      throwsA(isA<LeaderboardSubmitUnavailable>()),
    );
  });

  test('an empty base URL is unavailable', () async {
    final client = HttpLeaderboardSubmitClient(baseUrl: ' ');
    await expectLater(
      client.submit(idToken: 'tok', body: body),
      throwsA(isA<LeaderboardSubmitUnavailable>()),
    );
  });
}
