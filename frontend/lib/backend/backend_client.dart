import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_status.dart';

class BackendClient implements BackendStatusSource {
  BackendClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<BackendStatus> load() async {
    final responses = await Future.wait([
      _client.get(Uri.parse('$apiBaseUrl/actuator/health')),
      _client.get(Uri.parse('$apiBaseUrl/api/version')),
    ]).timeout(const Duration(seconds: 10));

    if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
      throw StateError('HKH backend is unavailable.');
    }

    final health = jsonDecode(responses[0].body) as Map<String, dynamic>;
    if (health['status'] != 'UP') throw StateError('HKH backend is unhealthy.');
    return BackendStatus.fromJson(
      jsonDecode(responses[1].body) as Map<String, dynamic>,
    );
  }
}
