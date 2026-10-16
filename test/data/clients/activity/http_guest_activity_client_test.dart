import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winklo/data/clients/activity/guest_activity_client.dart';
import 'package:winklo/data/clients/activity/http_guest_activity_client.dart';

void main() {
  HttpGuestActivityClient clientFor(
    Future<http.Response> Function(http.Request request) handler, {
    String baseUrl = 'https://activity.example/',
  }) => HttpGuestActivityClient(
    baseUrl: baseUrl,
    httpClient: MockClient(handler),
  );

  const body = {
    'installId': '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b',
    'dayId': '2026-10-17',
    'platform': 'android',
    'appVersion': '1.1.0',
    'build': 19,
  };

  test('posts the open as JSON to /v1/open', () async {
    late http.Request sent;
    final client = clientFor((request) async {
      sent = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await client.recordOpen(body);

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'https://activity.example/v1/open');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), body);
  });

  test('a refusal, a 5xx or an odd reply is unavailable', () async {
    for (final reply in [
      http.Response(jsonEncode({'error': 'bad_request'}), 400),
      http.Response(jsonEncode({'error': 'rate_limited'}), 429),
      http.Response('down', 503),
      http.Response('<html>', 200),
    ]) {
      final client = clientFor((_) async => reply);
      await expectLater(
        client.recordOpen(body),
        throwsA(isA<GuestActivityUnavailable>()),
      );
    }
  });

  test('a network error is unavailable', () async {
    final client = clientFor((_) async => throw http.ClientException('off'));
    await expectLater(
      client.recordOpen(body),
      throwsA(isA<GuestActivityUnavailable>()),
    );
  });

  test('an empty base URL is unavailable without a request', () async {
    var called = false;
    final client = clientFor((_) async {
      called = true;
      return http.Response('{}', 200);
    }, baseUrl: '  ');
    await expectLater(
      client.recordOpen(body),
      throwsA(isA<GuestActivityUnavailable>()),
    );
    expect(called, isFalse);
  });
}
