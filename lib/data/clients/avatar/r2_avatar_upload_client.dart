import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/failures.dart';
import 'avatar_upload_client.dart';

class R2AvatarUploadClient implements AvatarUploadClient {
  R2AvatarUploadClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const _maxBytes = 2 * 1024 * 1024;

  @override
  Future<Uri> uploadJpeg({
    required String idToken,
    required List<int> bytes,
  }) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.isEmpty) {
      throw const Failure('Avatar upload is not configured.');
    }
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw const Failure('Could not update profile.');
    }

    final uri = Uri.parse('$root/v1/avatar');
    final response = await _http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Failure(
        'Could not update profile.',
        cause: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const Failure('Could not update profile.');
      }
      final photoUrl = decoded['photoUrl'];
      if (photoUrl is! String || photoUrl.isEmpty) {
        throw const Failure('Could not update profile.');
      }
      return Uri.parse(photoUrl);
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Could not update profile.', cause: e);
    }
  }
}
