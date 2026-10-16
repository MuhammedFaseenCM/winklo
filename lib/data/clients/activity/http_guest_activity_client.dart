import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'guest_activity_client.dart';

class HttpGuestActivityClient implements GuestActivityClient {
  HttpGuestActivityClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  final Duration timeout;

  @override
  Future<void> recordOpen(Map<String, Object?> body) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.isEmpty) {
      throw const GuestActivityUnavailable('not configured');
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$root/v1/open'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GuestActivityUnavailable('timeout');
    } catch (e) {
      throw GuestActivityUnavailable('network: $e');
    }

    if (response.statusCode != 200 || _decode(response.body)?['ok'] != true) {
      throw GuestActivityUnavailable('HTTP ${response.statusCode}');
    }
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }
}
