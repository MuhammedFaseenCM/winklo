import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winklo/data/clients/avatar/r2_avatar_upload_client.dart';
import 'package:winklo/domain/failures.dart';

void main() {
  test('PUT sends Bearer token and JPEG body; returns photoUrl', () async {
    final client = R2AvatarUploadClient(
      baseUrl: 'https://avatar.example',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.toString(), 'https://avatar.example/v1/avatar');
        expect(request.headers['Authorization'], 'Bearer tok');
        expect(request.headers['Content-Type'], 'image/jpeg');
        expect(request.bodyBytes, [1, 2, 3]);
        return http.Response(
          jsonEncode({'photoUrl': 'https://pub.example/avatars/u1.jpg'}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final uri = await client.uploadJpeg(idToken: 'tok', bytes: [1, 2, 3]);
    expect(uri.toString(), 'https://pub.example/avatars/u1.jpg');
  });

  test('401 throws Failure', () async {
    final client = R2AvatarUploadClient(
      baseUrl: 'https://avatar.example',
      httpClient: MockClient(
        (_) async => http.Response('{"error":"unauthorized"}', 401),
      ),
    );

    expect(
      () => client.uploadJpeg(idToken: 'bad', bytes: [1]),
      throwsA(isA<Failure>()),
    );
  });

  test('empty baseUrl throws Failure before HTTP', () async {
    final client = R2AvatarUploadClient(baseUrl: '');
    expect(
      () => client.uploadJpeg(idToken: 'tok', bytes: [1]),
      throwsA(isA<Failure>()),
    );
  });
}
