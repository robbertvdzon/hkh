import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../collection/collection_search.dart';
import '../ai_search/ai_search.dart';
import '../ai_search/answer_sharing.dart';
import 'http_client_factory.dart';

class BackendClient
    implements
        CollectionSearchSource,
        AiSearchSource,
        AiSearchAccountSource,
        AiAnswerPdfSource,
        AiAnswerShareSource {
  BackendClient(
    this.apiBaseUrl, {
    http.Client? client,
    this.tokenProvider,
    this.onUnauthorized,
  }) : _client = client ?? createHttpClient();

  final String apiBaseUrl;
  final http.Client _client;

  /// Levert het HKH-sessietoken van de ingelogde gebruiker, of null. Als er een token is,
  /// gaat het als `Authorization: Bearer` mee met elk verzoek (ook AI-zoeken en collectie).
  final String? Function()? tokenProvider;

  /// Wordt aangeroepen als een privéroute 401 geeft: de sessie is verlopen of ingetrokken.
  final void Function()? onUnauthorized;

  /// De backend genereert de PDF on-demand; dit is de bovengrens van dat verzoek.
  static const _pdfExportTimeout = Duration(seconds: 30);

  Map<String, String>? _headers([Map<String, String>? extra]) {
    final token = tokenProvider?.call();
    if (token == null || token.isEmpty) return extra;
    return {...?extra, 'Authorization': 'Bearer $token'};
  }

  @override
  Future<CollectionOverview> loadOverview() async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/api/collections'), headers: _headers())
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
    CollectionSearchOptions? options,
  }) async {
    final params = <String, dynamic>{
      'page': '$page',
      'size': '$size',
      ...?options?.toParameters(includeView: false),
    };
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
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Zoeken is mislukt.');
    }
    return SearchPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<CollectionFacet> loadFacet({
    required String collection,
    required String field,
    String query = '',
    Map<String, String> fieldQueries = const {},
    int? year,
    CollectionSearchOptions? options,
    String valueQuery = '',
  }) async {
    final params = <String, dynamic>{
      'collection': collection,
      'facet': field,
      'facetQuery': valueQuery,
      'q': query,
      ...?options?.toParameters(includeView: false),
      if (year != null) 'year': '$year',
      if (fieldQueries.isNotEmpty)
        'fq': [for (final e in fieldQueries.entries) '${e.key}:${e.value}'],
    };
    final response = await _client
        .get(
          Uri.parse(
            '$apiBaseUrl/api/collections/facets',
          ).replace(queryParameters: params),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Filterwaarden konden niet worden geladen.');
    }
    return CollectionFacet.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<CollectionItemDetail> loadDetail(
    String collection,
    String ident,
  ) async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/collections/$collection/$ident'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Dit item kon niet worden geladen.');
    }
    return CollectionItemDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> syncAiSearchAccount() async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/api/ai-search/sessions/claim'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204) _decodeAiResponse(response);
  }

  @override
  Future<List<AiSearchSummary>> listAiSearches() async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/ai-search/sessions'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeAiResponse(response);
    if (decoded is! List<dynamic>) {
      throw StateError('De archiefdienst gaf een ongeldig antwoord.');
    }
    return decoded
        .map((item) => AiSearchSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<AiSearchSession> startAiSearch(
    String question, {
    AiResearchDepth depth = AiResearchDepth.fast,
  }) => _postAi('/api/ai-search/sessions', question, depth);

  @override
  Future<AiSearchSession> askFollowUp(
    String sessionId,
    String question, {
    AiResearchDepth depth = AiResearchDepth.fast,
  }) =>
      _postAi('/api/ai-search/sessions/$sessionId/questions', question, depth);

  @override
  Future<AiSearchSession> loadAiSearch(String sessionId) async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/ai-search/sessions/$sessionId'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return _parseAiResponse(response);
  }

  @override
  Future<AiSearchSession> cancelAiSearch(String sessionId) async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/api/ai-search/sessions/$sessionId/cancel'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return _parseAiResponse(response);
  }

  @override
  Future<AiSearchSession> steerAiSearch(
    String sessionId,
    String turnId, {
    bool? stop,
    String? hint,
  }) async {
    final response = await _client
        .post(
          Uri.parse(
            '$apiBaseUrl/api/ai-search/sessions/$sessionId/turns/$turnId/steer',
          ),
          headers: _headers(const {'Content-Type': 'application/json'}),
          body: jsonEncode({
            if (stop != null) 'stop': stop,
            if (hint != null) 'hint': hint,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parseAiResponse(response);
  }

  @override
  Future<void> deleteAiSearch(String sessionId) async {
    final response = await _client
        .delete(
          Uri.parse('$apiBaseUrl/api/ai-search/sessions/$sessionId'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeAiResponse(response);
    }
  }

  /// De export gebruikt dezelfde client, en dus dezelfde bezoekerscookie
  /// (inclusief `withCredentials` op web), als de overige AI-zoekverzoeken.
  @override
  Future<Uint8List> exportAnswerPdf(String answerId) async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/ai-search/$answerId/export/pdf'),
          headers: _headers(),
        )
        .timeout(_pdfExportTimeout);
    if (response.statusCode == 401) _decodeAiResponse(response);
    final contentType = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 ||
        !contentType.startsWith('application/pdf') ||
        response.bodyBytes.isEmpty) {
      throw StateError('De PDF-export kon niet worden opgehaald.');
    }
    return response.bodyBytes;
  }

  @override
  Future<String?> answerShareToken(String answerId) async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/ai-search/answers/$answerId/share'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return (_decodeAiResponse(response) as Map<String, dynamic>)['token']
        as String?;
  }

  @override
  Future<String> shareAnswer(String answerId) async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/api/ai-search/answers/$answerId/share'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return (_decodeAiResponse(response) as Map<String, dynamic>)['token']
        as String;
  }

  @override
  Future<void> revokeAnswerShare(String answerId) async {
    final response = await _client
        .delete(
          Uri.parse('$apiBaseUrl/api/ai-search/answers/$answerId/share'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204) _decodeAiResponse(response);
  }

  @override
  Future<SharedAiAnswer?> loadSharedAnswer(String token) async {
    final response = await _client
        .get(
          Uri.parse(
            '$apiBaseUrl/api/shared-answers/${Uri.encodeComponent(token)}',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404 || response.statusCode == 400) return null;
    return SharedAiAnswer.fromJson(
      _decodeAiResponse(response) as Map<String, dynamic>,
    );
  }

  Future<AiSearchSession> _postAi(
    String path,
    String question,
    AiResearchDepth depth,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(const {'Content-Type': 'application/json'}),
          body: jsonEncode({'question': question, 'depth': depth.apiValue}),
        )
        .timeout(const Duration(seconds: 15));
    return _parseAiResponse(response);
  }

  AiSearchSession _parseAiResponse(http.Response response) {
    final decoded = _decodeAiResponse(response);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('De archiefdienst gaf een ongeldig antwoord.');
    }
    return AiSearchSession.fromJson(decoded);
  }

  Object? _decodeAiResponse(http.Response response) {
    if (response.statusCode == 401) {
      final sentToken =
          response.request?.headers['Authorization'] ??
          response.request?.headers['authorization'];
      // Een vertraagd antwoord van een oude sessie mag een nieuwe login niet afmelden.
      if (sentToken == null || sentToken == 'Bearer ${tokenProvider?.call()}') {
        onUnauthorized?.call();
      }
      throw StateError('Je sessie is verlopen. Log opnieuw in.');
    }
    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['detail'] ?? decoded['message'])?.toString()
          : null;
      throw StateError(message ?? 'De archiefvraag kon niet worden verwerkt.');
    }
    return decoded;
  }
}
