import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'leaderboard_submit_client.dart';

class HttpLeaderboardSubmitClient implements LeaderboardSubmitClient {
  HttpLeaderboardSubmitClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// After this the clear is written directly instead.
  final Duration timeout;

  @override
  Future<LeaderboardSubmitResult> submit({
    required String idToken,
    required Map<String, Object?> body,
  }) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.isEmpty) {
      throw const LeaderboardSubmitUnavailable('not configured');
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$root/v1/submit'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const LeaderboardSubmitUnavailable('timeout');
    } catch (e) {
      throw LeaderboardSubmitUnavailable('network: $e');
    }

    final status = response.statusCode;
    if (status >= 500) {
      throw LeaderboardSubmitUnavailable('HTTP $status');
    }
    final decoded = _decode(response.body);
    if (status >= 400) {
      final code = decoded?['error'];
      throw LeaderboardSubmitRejected(status, code is String ? code : '');
    }
    if (status < 200 || status >= 300 || decoded?['accepted'] != true) {
      throw LeaderboardSubmitUnavailable('unexpected reply ($status)');
    }
    return LeaderboardSubmitResult(improved: decoded?['improved'] == true);
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
