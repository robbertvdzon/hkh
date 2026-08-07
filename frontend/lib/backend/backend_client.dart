import 'dart:convert';

import 'package:http/http.dart' as http;

import '../news/latest_news.dart';

class BackendClient implements LatestNewsSource {
  BackendClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<List<LatestNewsItem>> loadLatestNews() async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/api/news'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Het laatste nieuws kon niet worden geladen.');
    }
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => LatestNewsItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
