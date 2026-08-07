import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';

abstract interface class AdminLatestNewsSource {
  Future<void> create({
    required AdminIdentity identity,
    required String title,
    required String message,
  });
}

class AdminLatestNewsClient implements AdminLatestNewsSource {
  AdminLatestNewsClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<void> create({
    required AdminIdentity identity,
    required String title,
    required String message,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/api/admin/news'),
          headers: {
            'Content-Type': 'application/json',
            ...identity.requestHeaders,
          },
          body: jsonEncode({'title': title, 'message': message}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) {
      throw StateError('Nieuwsbericht geweigerd (${response.statusCode}).');
    }
  }
}
