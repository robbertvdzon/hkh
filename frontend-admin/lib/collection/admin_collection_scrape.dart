import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';

/// Status van een scrape-run zoals de backend die teruggeeft.
class ScrapeStatus {
  const ScrapeStatus({
    required this.status,
    required this.running,
    required this.total,
    required this.processed,
    required this.skipped,
    required this.failed,
    required this.currentCollection,
    required this.message,
    required this.perCollection,
    required this.startedAt,
    required this.finishedAt,
  });

  factory ScrapeStatus.fromJson(Map<String, dynamic> json) => ScrapeStatus(
    status: json['status'] as String? ?? 'UNKNOWN',
    running: json['running'] as bool? ?? false,
    total: json['total'] as int? ?? 0,
    processed: json['processed'] as int? ?? 0,
    skipped: json['skipped'] as int? ?? 0,
    failed: json['failed'] as int? ?? 0,
    currentCollection: json['currentCollection'] as String?,
    message: json['message'] as String?,
    perCollection:
        (json['perCollection'] as Map<String, dynamic>? ?? const {})
            .map((key, value) => MapEntry(key, (value as num).toInt())),
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.tryParse(json['startedAt'] as String),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateTime.tryParse(json['finishedAt'] as String),
  );

  final String status;
  final bool running;
  final int total;
  final int processed;
  final int skipped;
  final int failed;
  final String? currentCollection;
  final String? message;
  final Map<String, int> perCollection;
  final DateTime? startedAt;
  final DateTime? finishedAt;
}

abstract interface class AdminScrapeSource {
  Future<ScrapeStatus?> loadStatus(AdminIdentity identity);
  Future<ScrapeStatus> start({
    required AdminIdentity identity,
    required bool force,
  });
}

class AdminScrapeClient implements AdminScrapeSource {
  AdminScrapeClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<ScrapeStatus?> loadStatus(AdminIdentity identity) async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/admin/collections/scrape/status'),
          headers: identity.requestHeaders,
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Status ophalen mislukt (${response.statusCode}).');
    }
    if (response.body.isEmpty || response.body == 'null') return null;
    return ScrapeStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<ScrapeStatus> start({
    required AdminIdentity identity,
    required bool force,
  }) async {
    final response = await _client
        .post(
          Uri.parse(
            '$apiBaseUrl/api/admin/collections/scrape?force=$force',
          ),
          headers: identity.requestHeaders,
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 409) {
      throw StateError('Er loopt al een scrape.');
    }
    if (response.statusCode != 202) {
      throw StateError('Scrape starten mislukt (${response.statusCode}).');
    }
    return ScrapeStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
