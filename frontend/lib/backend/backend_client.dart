import 'dart:convert';

import 'package:http/http.dart' as http;

import '../collection/collection_search.dart';

class BackendClient implements CollectionSearchSource {
  BackendClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<CollectionOverview> loadOverview() async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/api/collections'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('De collectie kon niet worden geladen.');
    }
    return CollectionOverview.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<SearchPage> search({
    String? query,
    String? collection,
    Map<String, String> fieldQueries = const {},
    int? year,
    int page = 0,
    int size = 20,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'size': '$size'};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (collection != null && collection.isNotEmpty) {
      params['collection'] = collection;
    }
    if (year != null) params['year'] = '$year';
    final fq = fieldQueries.entries
        .where((e) => e.value.trim().isNotEmpty)
        .map((e) => '${e.key}:${e.value.trim()}')
        .toList(growable: false);
    if (fq.isNotEmpty) params['fq'] = fq;
    final uri = Uri.parse(
      '$apiBaseUrl/api/collections/search',
    ).replace(queryParameters: params);
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Zoeken is mislukt.');
    }
    return SearchPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<CollectionItemDetail> loadDetail(
    String collection,
    String ident,
  ) async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/api/collections/$collection/$ident'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Dit item kon niet worden geladen.');
    }
    return CollectionItemDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
