import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';
import '../widgets/full_width_table.dart';

/// Eén verzoek aan de site: een AI-vraag (of de uitwerking ervan) of een
/// zoekopdracht in de collecties.
class RequestLogEntry {
  const RequestLogEntry({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.question,
    required this.expansion,
    required this.status,
    this.ip,
    this.userEmail,
    this.collection,
    this.model,
    this.firstFeedbackMs,
    this.answerMs,
    this.costUsd,
  });

  factory RequestLogEntry.fromJson(Map<String, dynamic> json) =>
      RequestLogEntry(
        id: (json['id'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        kind: json['kind'] as String? ?? 'AI_QUESTION',
        question: json['question'] as String? ?? '',
        expansion: json['expansion'] as bool? ?? false,
        status: json['status'] as String? ?? '',
        ip: json['ip'] as String?,
        userEmail: json['userEmail'] as String?,
        collection: json['collection'] as String?,
        model: json['model'] as String?,
        firstFeedbackMs: (json['firstFeedbackMs'] as num?)?.toInt(),
        answerMs: (json['answerMs'] as num?)?.toInt(),
        costUsd: (json['costUsd'] as num?)?.toDouble(),
      );

  final int id;
  final DateTime createdAt;
  final String kind;
  final String question;
  final bool expansion;
  final String status;
  final String? ip;
  final String? userEmail;
  final String? collection;
  final String? model;
  final int? firstFeedbackMs;
  final int? answerMs;
  final double? costUsd;

  String get kindLabel => switch (kind) {
    'AI_QUESTION' => expansion ? 'AI (uitwerking)' : 'AI',
    'COLLECTION_SEARCH' =>
      collection == null ? 'Collectie' : 'Collectie: $collection',
    _ => kind,
  };
}

abstract interface class AdminRequestLogSource {
  Future<List<RequestLogEntry>> recent(AdminIdentity identity, {int limit});
}

class AdminRequestLogClient implements AdminRequestLogSource {
  AdminRequestLogClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<List<RequestLogEntry>> recent(
    AdminIdentity identity, {
    int limit = 200,
  }) async {
    final response = await _client
        .get(
          Uri.parse(
            '$apiBaseUrl/api/admin/requests',
          ).replace(queryParameters: {'limit': '$limit'}),
          headers: identity.requestHeaders,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Logboek laden mislukt (${response.statusCode})');
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
        .map((item) => RequestLogEntry.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}

/// Beheerblok: het logboek van alle verzoeken, nieuwste eerst.
class AdminRequestLogSection extends StatefulWidget {
  const AdminRequestLogSection({
    required this.identity,
    required this.source,
    super.key,
  });

  final AdminIdentity identity;
  final AdminRequestLogSource source;

  @override
  State<AdminRequestLogSection> createState() => _AdminRequestLogSectionState();
}

class _AdminRequestLogSectionState extends State<AdminRequestLogSection> {
  List<RequestLogEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  int _limit = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await widget.source.recent(
        widget.identity,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message
            : 'Het logboek kon niet worden geladen.';
        _loading = false;
      });
    }
  }

  static String _when(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.day)}-${two(time.month)} ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  static String _seconds(int? ms) {
    if (ms == null) return '';
    if (ms < 1000) return '$ms ms';
    final s = ms / 1000;
    if (s < 60) return '${s.toStringAsFixed(s < 10 ? 1 : 0)} s';
    final m = s ~/ 60;
    return '$m:${(s - m * 60).round().toString().padLeft(2, '0')}';
  }

  static String _cost(double? value) =>
      value == null ? '' : '\$${value.toStringAsFixed(2)}';

  static String _status(String status) => switch (status) {
    'RUNNING' => 'bezig',
    'SUCCEEDED' => 'afgerond',
    'FAILED' => 'mislukt',
    'CANCELLED' => 'gestopt',
    _ => status.toLowerCase(),
  };

  Widget _table(Key key) => DataTable(
    key: key,
    columnSpacing: 16,
    headingTextStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
    ),
    dataTextStyle: const TextStyle(fontSize: 12),
    columns: const [
      DataColumn(label: Text('Wanneer')),
      DataColumn(label: Text('IP-adres')),
      DataColumn(label: Text('Gebruiker')),
      DataColumn(label: Text('Soort')),
      DataColumn(label: Text('Vraag')),
      DataColumn(label: Text('Model')),
      DataColumn(label: Text('1e terugkoppeling')),
      DataColumn(label: Text('Antwoord')),
      DataColumn(label: Text('Status')),
      DataColumn(label: Text('Kosten')),
    ],
    rows: [
      for (final entry in _entries)
        DataRow(
          cells: [
            DataCell(Text(_when(entry.createdAt))),
            DataCell(Text(entry.ip ?? '')),
            DataCell(Text(entry.userEmail ?? '')),
            DataCell(
              Text(
                entry.kindLabel,
                style: entry.expansion
                    ? const TextStyle(fontWeight: FontWeight.w600)
                    : null,
              ),
            ),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Tooltip(
                  message: entry.question,
                  child: Text(
                    entry.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(entry.model ?? '', overflow: TextOverflow.ellipsis),
              ),
            ),
            DataCell(Text(_seconds(entry.firstFeedbackMs))),
            DataCell(Text(_seconds(entry.answerMs))),
            DataCell(Text(_status(entry.status))),
            DataCell(Text(_cost(entry.costUsd))),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Logboek van verzoeken',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              DropdownButton<int>(
                key: const Key('request-log-limit'),
                value: _limit,
                items: const [
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 500, child: Text('500')),
                  DropdownMenuItem(value: 1000, child: Text('1000')),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _limit = value);
                        _load();
                      },
              ),
              IconButton(
                key: const Key('request-log-open'),
                tooltip: 'Openen over de volle breedte',
                onPressed: _loading || _entries.isEmpty
                    ? null
                    : () => showFullWidthTable(
                        context,
                        title: 'Logboek van verzoeken',
                        tableBuilder: (_) =>
                            _table(const Key('request-log-table-full')),
                      ),
                icon: const Icon(Icons.open_in_full),
              ),
              IconButton(
                key: const Key('request-log-refresh'),
                tooltip: 'Verversen',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Alle AI-vragen (met hun uitwerkingen) en zoekopdrachten in de collecties, '
            'nieuwste eerst: wie vroeg wat, hoe snel kwam de eerste terugkoppeling en het '
            'antwoord, welk model en wat het kostte (API-equivalent).',
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries.isEmpty)
            const Text('Nog geen verzoeken.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _table(const Key('request-log-table')),
            ),
        ],
      ),
    ),
  );
}
