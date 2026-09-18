import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../collection/collection_search.dart';
import '../ai_search/ai_search.dart';
import '../ai_search/answer_sharing.dart';
import '../dossier/dossier.dart';
import 'http_client_factory.dart';

class BackendClient
    implements
        CollectionSearchSource,
        AiSearchSource,
        AiSearchAccountSource,
        AiAnswerPdfSource,
        AiAnswerShareSource,
        DossierSource {
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

  static const _dossierTimeout = Duration(seconds: 20);

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
  Future<AiSearchSession> startAiSearch(String question) =>
      _postAi('/api/ai-search/sessions', question);

  @override
  Future<AiSearchSession> askFollowUp(String sessionId, String question) =>
      _postAi('/api/ai-search/sessions/$sessionId/questions', question);

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

  Future<AiSearchSession> _postAi(String path, String question) async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(const {'Content-Type': 'application/json'}),
          body: jsonEncode({'question': question}),
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

  // ---- Dossiers ----

  @override
  Future<List<DossierSummary>> listDossiers() async => _decodeList(
    await _request('GET', '/api/dossiers'),
    DossierSummary.fromJson,
  );

  @override
  Future<DossierDetail> createDossier({
    required String title,
    required String goal,
  }) async => DossierDetail.fromJson(
    _decodeMap(
      await _request('POST', '/api/dossiers', {'title': title, 'goal': goal}),
    ),
  );

  @override
  Future<DossierDetail> loadDossier(String dossierId) async =>
      DossierDetail.fromJson(
        _decodeMap(await _request('GET', '/api/dossiers/$dossierId')),
      );

  @override
  Future<DossierDetail> updateDossier(
    String dossierId, {
    required String title,
    required String goal,
  }) async => DossierDetail.fromJson(
    _decodeMap(
      await _request('PUT', '/api/dossiers/$dossierId', {
        'title': title,
        'goal': goal,
      }),
    ),
  );

  @override
  Future<void> deleteDossier(String dossierId) async {
    _decodeDossierResponse(
      await _request('DELETE', '/api/dossiers/$dossierId'),
    );
  }

  @override
  Future<DossierDetail> setMember(
    String dossierId,
    String email,
    DossierRole role,
  ) async => DossierDetail.fromJson(
    _decodeMap(
      await _request(
        'PUT',
        '/api/dossiers/$dossierId/members/${Uri.encodeComponent(email)}',
        {'role': role.wireName},
      ),
    ),
  );

  @override
  Future<void> removeMember(String dossierId, String email) async {
    _decodeDossierResponse(
      await _request(
        'DELETE',
        '/api/dossiers/$dossierId/members/${Uri.encodeComponent(email)}',
      ),
    );
  }

  @override
  Future<DossierDetail> updateFactSheet(
    String dossierId,
    String markdown,
  ) async => DossierDetail.fromJson(
    _decodeMap(
      await _request('PUT', '/api/dossiers/$dossierId/fact-sheet', {
        'markdown': markdown,
      }),
    ),
  );

  @override
  Future<DossierDetail> refreshFactSheet(String dossierId) async =>
      DossierDetail.fromJson(
        _decodeMap(
          await _request('POST', '/api/dossiers/$dossierId/fact-sheet/refresh'),
        ),
      );

  @override
  Future<List<AiSearchSummary>> listQuestions(String dossierId) async =>
      _decodeList(
        await _request('GET', '/api/dossiers/$dossierId/questions'),
        AiSearchSummary.fromJson,
      );

  @override
  Future<AiSearchSession> askQuestion(
    String dossierId,
    String question,
  ) async => AiSearchSession.fromJson(
    _decodeMap(
      await _request('POST', '/api/dossiers/$dossierId/questions', {
        'question': question,
      }),
    ),
  );

  @override
  Future<AiSearchSession> loadQuestion(
    String dossierId,
    String sessionId,
  ) async => AiSearchSession.fromJson(
    _decodeMap(
      await _request('GET', '/api/dossiers/$dossierId/questions/$sessionId'),
    ),
  );

  @override
  Future<AiSearchSession> askFollowUpQuestion(
    String dossierId,
    String sessionId,
    String question,
  ) async => AiSearchSession.fromJson(
    _decodeMap(
      await _request(
        'POST',
        '/api/dossiers/$dossierId/questions/$sessionId/questions',
        {'question': question},
      ),
    ),
  );

  @override
  Future<AiSearchSession> cancelQuestion(
    String dossierId,
    String sessionId,
  ) async => AiSearchSession.fromJson(
    _decodeMap(
      await _request(
        'POST',
        '/api/dossiers/$dossierId/questions/$sessionId/cancel',
      ),
    ),
  );

  @override
  Future<void> deleteQuestion(String dossierId, String sessionId) async {
    _decodeDossierResponse(
      await _request('DELETE', '/api/dossiers/$dossierId/questions/$sessionId'),
    );
  }

  @override
  Future<AiSearchSession> adoptSearch(
    String dossierId,
    String sessionId,
  ) async => AiSearchSession.fromJson(
    _decodeMap(
      await _request('POST', '/api/dossiers/$dossierId/questions/adopt', {
        'sessionId': sessionId,
      }),
    ),
  );

  // ---- Artikelen ----

  @override
  Future<List<ArticleSummary>> listArticles(String dossierId) async =>
      _decodeList(
        await _request('GET', '/api/dossiers/$dossierId/articles'),
        ArticleSummary.fromJson,
      );

  @override
  Future<ArticleDetail> createArticle(
    String dossierId, {
    required String title,
    required String contentMarkdown,
  }) async => ArticleDetail.fromJson(
    _decodeMap(
      await _request('POST', '/api/dossiers/$dossierId/articles', {
        'title': title,
        'contentMarkdown': contentMarkdown,
      }),
    ),
  );

  @override
  Future<ArticleDetail> generateArticle(
    String dossierId, {
    required String title,
    required String instruction,
  }) async => ArticleDetail.fromJson(
    _decodeMap(
      await _request('POST', '/api/dossiers/$dossierId/articles/generate', {
        'title': title,
        'instruction': instruction,
      }),
    ),
  );

  @override
  Future<ArticleDetail> loadArticle(String articleId) async =>
      ArticleDetail.fromJson(
        _decodeMap(await _request('GET', '/api/articles/$articleId')),
      );

  @override
  Future<ArticleDetail> saveArticle(
    String articleId, {
    required String title,
    required String contentMarkdown,
    required String basedOnVersionId,
  }) async => ArticleDetail.fromJson(
    _decodeMap(
      await _request('PUT', '/api/articles/$articleId', {
        'title': title,
        'contentMarkdown': contentMarkdown,
        'basedOnVersionId': basedOnVersionId,
      }),
    ),
  );

  @override
  Future<void> deleteArticle(String articleId) async {
    _decodeDossierResponse(
      await _request('DELETE', '/api/articles/$articleId'),
    );
  }

  @override
  Future<List<VersionSummary>> listVersions(String articleId) async =>
      _decodeList(
        await _request('GET', '/api/articles/$articleId/versions'),
        VersionSummary.fromJson,
      );

  @override
  Future<ArticleVersion> loadVersion(
    String articleId,
    int versionNumber,
  ) async => ArticleVersion.fromJson(
    _decodeMap(
      await _request('GET', '/api/articles/$articleId/versions/$versionNumber'),
    ),
  );

  @override
  Future<ArticleDiff> loadDiff(
    String articleId, {
    required int versionNumber,
    required int against,
  }) async => ArticleDiff.fromJson(
    _decodeMap(
      await _request(
        'GET',
        '/api/articles/$articleId/versions/$versionNumber/diff',
        null,
        {'against': '$against'},
      ),
    ),
  );

  @override
  Future<ArticleDetail> restoreVersion(
    String articleId,
    int versionNumber,
  ) async => ArticleDetail.fromJson(
    _decodeMap(
      await _request(
        'POST',
        '/api/articles/$articleId/versions/$versionNumber/restore',
      ),
    ),
  );

  @override
  Future<ArticleDetail> proposeChange(
    String articleId, {
    required String instruction,
    required String basedOnVersionId,
  }) async => ArticleDetail.fromJson(
    _decodeMap(
      await _request('POST', '/api/articles/$articleId/proposals', {
        'instruction': instruction,
        'basedOnVersionId': basedOnVersionId,
      }),
    ),
  );

  @override
  Future<ArticleDetail> acceptProposal(
    String articleId,
    String versionId,
  ) async => ArticleDetail.fromJson(
    _decodeMap(
      await _request(
        'POST',
        '/api/articles/$articleId/proposals/$versionId/accept',
      ),
    ),
  );

  @override
  Future<ArticleDetail> rejectProposal(
    String articleId,
    String versionId,
  ) async => ArticleDetail.fromJson(
    _decodeMap(
      await _request(
        'POST',
        '/api/articles/$articleId/proposals/$versionId/reject',
      ),
    ),
  );

  /// Haalt de PDF van de huidige artikelversie op. Alleen een niet-lege `application/pdf`
  /// telt als geslaagd; alles anders wordt een fout, zodat er nooit een leeg of onvolledig
  /// bestand wordt aangeboden.
  @override
  Future<Uint8List> exportArticlePdf(String dossierId, String articleId) async {
    final response = await _client
        .get(
          Uri.parse(
            '$apiBaseUrl/api/dossiers/$dossierId/articles/$articleId/export/pdf',
          ),
          headers: _headers(),
        )
        .timeout(_pdfExportTimeout);
    if (response.statusCode == 401) onUnauthorized?.call();
    if (response.statusCode == 401) _decodeAiResponse(response);
    final contentType = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 ||
        !contentType.startsWith('application/pdf') ||
        response.bodyBytes.isEmpty) {
      throw StateError('De PDF-export kon niet worden opgehaald.');
    }
    return response.bodyBytes;
  }

  // ---- Hulpmethodes voor dossierroutes ----

  Future<http.Response> _request(
    String method,
    String path, [
    Map<String, Object?>? body,
    Map<String, String>? query,
  ]) async {
    var uri = Uri.parse('$apiBaseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final headers = _headers(
      body == null ? null : const {'Content-Type': 'application/json'},
    );
    final encoded = body == null ? null : jsonEncode(body);
    final future = switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encoded),
      'PUT' => _client.put(uri, headers: headers, body: encoded),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method'),
    };
    return future.timeout(_dossierTimeout);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decodeDossierResponse(response);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('De archiefdienst gaf een ongeldig antwoord.');
    }
    return decoded;
  }

  List<T> _decodeList<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parse,
  ) {
    final decoded = _decodeDossierResponse(response);
    if (decoded is! List<dynamic>) {
      throw StateError('De archiefdienst gaf een ongeldig antwoord.');
    }
    return decoded
        .map((item) => parse(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Object? _decodeDossierResponse(http.Response response) =>
      _decodeAiResponse(response);
}
