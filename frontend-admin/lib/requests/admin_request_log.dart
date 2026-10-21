import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';

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
    this.userAgent,
    this.bot = false,
    this.test = false,
    this.ipAnonymized = false,
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
        userAgent: json['userAgent'] as String?,
        bot: json['bot'] as bool? ?? false,
        test: json['test'] as bool? ?? false,
        ipAnonymized: json['ipAnonymized'] as bool? ?? false,
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
  final String? userAgent;

  /// Bot of script: telt niet mee in de bezoekersaantallen.
  final bool bot;

  /// Testverkeer: telt mee, maar is gemarkeerd.
  final bool test;

  /// Het IP-adres is na de bewaartermijn afgekapt.
  final bool ipAnonymized;

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

/// Pagina met het logboek van alle verzoeken, nieuwste eerst, over de volle breedte.
class AdminRequestLogPage extends StatefulWidget {
  const AdminRequestLogPage({
    required this.identity,
    required this.source,
    super.key,
  });

  final AdminIdentity identity;
  final AdminRequestLogSource source;

  @override
  State<AdminRequestLogPage> createState() => _AdminRequestLogPageState();
}

enum _KindFilter { all, ai, collection }

class _AdminRequestLogPageState extends State<AdminRequestLogPage> {
  List<RequestLogEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  int _limit = 200;
  _KindFilter _kind = _KindFilter.all;
  bool _showBots = false;
  bool _showTest = true;
  final _horizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
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

  List<RequestLogEntry> get _visible => [
    for (final entry in _entries)
      if ((_showBots || !entry.bot) &&
          (_showTest || !entry.test) &&
          switch (_kind) {
            _KindFilter.all => true,
            _KindFilter.ai => entry.kind == 'AI_QUESTION',
            _KindFilter.collection => entry.kind == 'COLLECTION_SEARCH',
          })
        entry,
  ];

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

  Widget _table(List<RequestLogEntry> entries) => DataTable(
    key: const Key('request-log-table'),
    columnSpacing: 20,
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
      DataColumn(label: Text('Browser')),
      DataColumn(label: Text('Markering')),
    ],
    rows: [
      for (final entry in entries)
        DataRow(
          cells: [
            DataCell(Text(_when(entry.createdAt))),
            DataCell(
              Tooltip(
                message: entry.ipAnonymized
                    ? 'Afgekapt na de bewaartermijn'
                    : 'Volledig adres',
                child: Text(
                  entry.ip == null
                      ? ''
                      : (entry.ipAnonymized ? '${entry.ip} *' : entry.ip!),
                ),
              ),
            ),
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
                constraints: const BoxConstraints(maxWidth: 420),
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
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(entry.model ?? '', overflow: TextOverflow.ellipsis),
              ),
            ),
            DataCell(Text(_seconds(entry.firstFeedbackMs))),
            DataCell(Text(_seconds(entry.answerMs))),
            DataCell(Text(_status(entry.status))),
            DataCell(Text(_cost(entry.costUsd))),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Tooltip(
                  message: entry.userAgent ?? '',
                  child: Text(
                    entry.userAgent ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            DataCell(
              Text([if (entry.bot) 'bot', if (entry.test) 'test'].join(', ')),
            ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Alle AI-vragen (met hun uitwerkingen) en zoekopdrachten in de '
          'collecties, nieuwste eerst: wie vroeg wat, hoe snel kwam de eerste '
          'terugkoppeling en het antwoord, welk model en wat het kostte '
          '(API-equivalent). IP-adressen worden na 30 dagen afgekapt (met een '
          '* gemarkeerd).',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_KindFilter>(
              key: const Key('request-log-kind'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _KindFilter.all, label: Text('Alles')),
                ButtonSegment(value: _KindFilter.ai, label: Text('AI')),
                ButtonSegment(
                  value: _KindFilter.collection,
                  label: Text('Collectie'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) =>
                  setState(() => _kind = value.single),
            ),
            FilterChip(
              key: const Key('request-log-bots'),
              label: const Text('Bots tonen'),
              selected: _showBots,
              onSelected: (value) => setState(() => _showBots = value),
            ),
            FilterChip(
              key: const Key('request-log-test'),
              label: const Text('Testverkeer tonen'),
              selected: _showTest,
              onSelected: (value) => setState(() => _showTest = value),
            ),
            DropdownButton<int>(
              key: const Key('request-log-limit'),
              value: _limit,
              items: const [
                DropdownMenuItem(value: 50, child: Text('50 regels')),
                DropdownMenuItem(value: 200, child: Text('200 regels')),
                DropdownMenuItem(value: 500, child: Text('500 regels')),
                DropdownMenuItem(value: 1000, child: Text('1000 regels')),
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
              key: const Key('request-log-refresh'),
              tooltip: 'Verversen',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            Text(
              '${visible.length} van ${_entries.length} regels',
              key: const Key('request-log-count'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visible.isEmpty)
          const Text('Geen verzoeken die aan de filters voldoen.')
        else
          Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 16),
              child: _table(visible),
            ),
          ),
      ],
    );
  }
}
