import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';

/// Eén inlogpoging in de workflow-app.
class WorkflowLoginEntry {
  const WorkflowLoginEntry({
    required this.id,
    required this.createdAt,
    required this.success,
    required this.method,
    this.user,
    this.detail,
    this.appVersion,
    this.computer,
    this.ip,
  });

  factory WorkflowLoginEntry.fromJson(Map<String, dynamic> json) =>
      WorkflowLoginEntry(
        id: (json['id'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        success: json['success'] as bool? ?? false,
        method: json['method'] as String? ?? '',
        user: json['user'] as String?,
        detail: json['detail'] as String?,
        appVersion: json['appVersion'] as String?,
        computer: json['computer'] as String?,
        ip: json['ip'] as String?,
      );

  final int id;
  final DateTime createdAt;
  final bool success;
  final String method;
  final String? user;
  final String? detail;
  final String? appVersion;
  final String? computer;
  final String? ip;
}

/// De twee soorten doorlopen in de workflow-app.
enum WorkflowKind {
  newFiles('NEW_FILES'),
  edit('EDIT');

  const WorkflowKind(this.api);
  final String api;
}

/// Eén doorloop (sessie) in de lijst.
class WorkflowSessionSummary {
  const WorkflowSessionSummary({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.phase,
    required this.phaseCount,
    required this.status,
    required this.fileCount,
    required this.updates,
    this.user,
    this.collection,
    this.phaseLabel,
    this.appVersion,
    this.computer,
    this.ip,
  });

  factory WorkflowSessionSummary.fromJson(Map<String, dynamic> json) =>
      WorkflowSessionSummary(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
        phase: (json['phase'] as num?)?.toInt() ?? 0,
        phaseCount: (json['phaseCount'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
        updates: (json['updates'] as num?)?.toInt() ?? 0,
        user: json['user'] as String?,
        collection: json['collection'] as String?,
        phaseLabel: json['phaseLabel'] as String?,
        appVersion: json['appVersion'] as String?,
        computer: json['computer'] as String?,
        ip: json['ip'] as String?,
      );

  final String id;
  final String kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int phase;
  final int phaseCount;
  final String status;
  final int fileCount;
  final int updates;
  final String? user;
  final String? collection;
  final String? phaseLabel;
  final String? appVersion;
  final String? computer;
  final String? ip;

  /// "5 van 7: images.exe", of alleen de naam als het aantal fasen onbekend is.
  String get phaseText {
    final label = phaseLabel ?? '';
    if (phaseCount <= 0) return label;
    final done = phase > phaseCount ? 'klaar' : '$phase van $phaseCount';
    return label.isEmpty ? done : '$done: $label';
  }
}

/// Eén regel in de tijdlijn van een sessie.
class WorkflowEvent {
  const WorkflowEvent({
    required this.createdAt,
    required this.phase,
    required this.status,
    required this.message,
    this.phaseLabel,
  });

  factory WorkflowEvent.fromJson(Map<String, dynamic> json) => WorkflowEvent(
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    phase: (json['phase'] as num?)?.toInt() ?? 0,
    phaseLabel: json['phaseLabel'] as String?,
    status: json['status'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );

  final DateTime createdAt;
  final int phase;
  final String? phaseLabel;
  final String status;
  final String message;
}

/// Een sessie met de laatst ontvangen volledige momentopname en de tijdlijn.
class WorkflowSessionDetail {
  const WorkflowSessionDetail({
    required this.summary,
    required this.snapshot,
    required this.events,
  });

  factory WorkflowSessionDetail.fromJson(Map<String, dynamic> json) =>
      WorkflowSessionDetail(
        summary: WorkflowSessionSummary.fromJson(
          json['summary'] as Map<String, dynamic>,
        ),
        snapshot: (json['snapshot'] as Map<String, dynamic>?) ?? const {},
        events: [
          for (final item in (json['events'] as List<dynamic>? ?? const []))
            WorkflowEvent.fromJson(item as Map<String, dynamic>),
        ],
      );

  final WorkflowSessionSummary summary;
  final Map<String, dynamic> snapshot;
  final List<WorkflowEvent> events;
}

abstract interface class AdminWorkflowLogSource {
  Future<List<WorkflowLoginEntry>> logins(AdminIdentity identity);
  Future<List<WorkflowSessionSummary>> sessions(
    AdminIdentity identity,
    WorkflowKind kind,
  );
  Future<WorkflowSessionDetail> session(AdminIdentity identity, String id);
}

class AdminWorkflowLogClient implements AdminWorkflowLogSource {
  AdminWorkflowLogClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Future<dynamic> _get(
    AdminIdentity identity,
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await _client
        .get(
          Uri.parse(
            '$apiBaseUrl/api/admin/workflow-log$path',
          ).replace(queryParameters: query),
          headers: identity.requestHeaders,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError(
        'Workflow-logboek laden mislukt (${response.statusCode})',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  @override
  Future<List<WorkflowLoginEntry>> logins(AdminIdentity identity) async =>
      ((await _get(identity, '/logins', {'limit': '500'})) as List<dynamic>)
          .map((e) => WorkflowLoginEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

  @override
  Future<List<WorkflowSessionSummary>> sessions(
    AdminIdentity identity,
    WorkflowKind kind,
  ) async =>
      ((await _get(identity, '/sessions', {'kind': kind.api, 'limit': '500'}))
              as List<dynamic>)
          .map(
            (e) => WorkflowSessionSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false);

  @override
  Future<WorkflowSessionDetail> session(
    AdminIdentity identity,
    String id,
  ) async => WorkflowSessionDetail.fromJson(
    (await _get(identity, '/sessions/$id')) as Map<String, dynamic>,
  );
}

String _when(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.day)}-${two(time.month)} ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

String _statusLabel(String status) => switch (status) {
  'RUNNING' => 'bezig',
  'FINISHED' => 'klaar',
  'FAILED' => 'mislukt',
  'ABANDONED' => 'verlaten',
  _ => status.toLowerCase(),
};

Color? _statusColor(BuildContext context, String status) => switch (status) {
  'FAILED' => Theme.of(context).colorScheme.error,
  'ABANDONED' => Colors.orange.shade800,
  'FINISHED' => Colors.green.shade700,
  _ => null,
};

String _describeError(Object error) => error is StateError
    ? error.message
    : 'Het logboek kon niet worden geladen.';

enum _Tab { logins, created, edited }

/// De laatst gekozen tab, zodat je na een sessie weer op dezelfde lijst terugkomt.
_Tab _lastTab = _Tab.created;

/// Overzicht van het workflow-logboek: inlogpogingen en de sessies van de workflow-app.
class AdminWorkflowLogPage extends StatefulWidget {
  const AdminWorkflowLogPage({
    required this.identity,
    required this.source,
    required this.onOpenSession,
    super.key,
  });

  final AdminIdentity identity;
  final AdminWorkflowLogSource source;
  final void Function(String id) onOpenSession;

  @override
  State<AdminWorkflowLogPage> createState() => _AdminWorkflowLogPageState();
}

class _AdminWorkflowLogPageState extends State<AdminWorkflowLogPage> {
  _Tab _tab = _lastTab;
  List<WorkflowLoginEntry> _logins = const [];
  List<WorkflowSessionSummary> _sessions = const [];
  bool _loading = true;
  String? _error;
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
      if (_tab == _Tab.logins) {
        final logins = await widget.source.logins(widget.identity);
        if (!mounted) return;
        setState(() {
          _logins = logins;
          _error = null;
          _loading = false;
        });
      } else {
        final sessions = await widget.source.sessions(
          widget.identity,
          _tab == _Tab.created ? WorkflowKind.newFiles : WorkflowKind.edit,
        );
        if (!mounted) return;
        setState(() {
          _sessions = sessions;
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(error);
        _loading = false;
      });
    }
  }

  static const _headingStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 12,
  );
  static const _dataStyle = TextStyle(fontSize: 12);

  Widget _loginTable() => DataTable(
    key: const Key('workflow-login-table'),
    columnSpacing: 20,
    headingTextStyle: _headingStyle,
    dataTextStyle: _dataStyle,
    columns: const [
      DataColumn(label: Text('Wanneer')),
      DataColumn(label: Text('Gebruiker')),
      DataColumn(label: Text('Resultaat')),
      DataColumn(label: Text('Via')),
      DataColumn(label: Text('Opmerking')),
      DataColumn(label: Text('Computer')),
      DataColumn(label: Text('Versie')),
      DataColumn(label: Text('IP-adres')),
    ],
    rows: [
      for (final entry in _logins)
        DataRow(
          cells: [
            DataCell(Text(_when(entry.createdAt))),
            DataCell(Text(entry.user ?? '')),
            DataCell(
              Text(
                entry.success ? 'gelukt' : 'mislukt',
                style: TextStyle(
                  color: entry.success
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(Text(entry.method == 'COOKIE' ? 'cookie' : 'wachtwoord')),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  entry.detail ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(Text(entry.computer ?? '')),
            DataCell(Text(entry.appVersion ?? '')),
            DataCell(Text(entry.ip ?? '')),
          ],
        ),
    ],
  );

  Widget _sessionTable() {
    final edit = _tab == _Tab.edited;
    return DataTable(
      key: const Key('workflow-session-table'),
      showCheckboxColumn: false,
      columnSpacing: 20,
      headingTextStyle: _headingStyle,
      dataTextStyle: _dataStyle,
      columns: [
        const DataColumn(label: Text('Gestart')),
        const DataColumn(label: Text('Laatste bericht')),
        const DataColumn(label: Text('Gebruiker')),
        const DataColumn(label: Text('Collectie')),
        DataColumn(label: Text(edit ? 'Records' : 'Bestanden'), numeric: true),
        const DataColumn(label: Text('Fase')),
        const DataColumn(label: Text('Status')),
        const DataColumn(label: Text('Berichten'), numeric: true),
        const DataColumn(label: Text('Computer')),
        const DataColumn(label: Text('Versie')),
      ],
      rows: [
        for (final s in _sessions)
          DataRow(
            key: ValueKey(s.id),
            onSelectChanged: (_) => widget.onOpenSession(s.id),
            cells: [
              DataCell(Text(_when(s.createdAt))),
              DataCell(Text(_when(s.updatedAt))),
              DataCell(Text(s.user ?? '')),
              DataCell(Text(s.collection ?? '')),
              DataCell(Text('${s.fileCount}')),
              DataCell(Text(s.phaseText)),
              DataCell(
                Text(
                  _statusLabel(s.status),
                  style: TextStyle(
                    color: _statusColor(context, s.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(Text('${s.updates}')),
              DataCell(Text(s.computer ?? '')),
              DataCell(Text(s.appVersion ?? '')),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _tab == _Tab.logins ? _logins.length : _sessions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wat de workflow-app van de vrijwilligers meldt: elke inlogpoging, '
          'elke doorloop om nieuwe bestanden in ZCBS te zetten en elke '
          'doorloop om records aan te passen. Klik op een doorloop voor de '
          'volledige log. De gegevens komen ongecontroleerd binnen via een '
          'open meldpunt en zijn dus indicatief.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_Tab>(
              key: const Key('workflow-log-tabs'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Tab.created, label: Text('Aangemaakt')),
                ButtonSegment(value: _Tab.edited, label: Text('Aangepast')),
                ButtonSegment(value: _Tab.logins, label: Text('Inloggen')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) {
                setState(() {
                  _tab = value.single;
                  _lastTab = _tab;
                });
                _load();
              },
            ),
            IconButton(
              key: const Key('workflow-log-refresh'),
              tooltip: 'Verversen',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            Text(
              '$count regels',
              key: const Key('workflow-log-count'),
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
        else if (count == 0)
          const Text('Nog niets gemeld.')
        else
          Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 16),
              child: _tab == _Tab.logins ? _loginTable() : _sessionTable(),
            ),
          ),
      ],
    );
  }
}

/// De volledige log van één doorloop: samenvatting, tijdlijn en alles uit de laatste momentopname.
class AdminWorkflowSessionPage extends StatefulWidget {
  const AdminWorkflowSessionPage({
    required this.identity,
    required this.source,
    required this.sessionId,
    super.key,
  });

  final AdminIdentity identity;
  final AdminWorkflowLogSource source;
  final String sessionId;

  @override
  State<AdminWorkflowSessionPage> createState() =>
      _AdminWorkflowSessionPageState();
}

class _AdminWorkflowSessionPageState extends State<AdminWorkflowSessionPage> {
  WorkflowSessionDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await widget.source.session(
        widget.identity,
        widget.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(error);
        _loading = false;
      });
    }
  }

  static const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12);

  /// Tekst blijft tekst; al het andere wordt als ingesprongen JSON getoond.
  static String _render(Object? value) => value is String
      ? value
      : const JsonEncoder.withIndent('  ').convert(value);

  static String _title(String key, Object? value) => switch (value) {
    List<dynamic> list => '$key (${list.length})',
    Map<String, dynamic> map => '$key (${map.length})',
    _ => key,
  };

  Widget _summary(WorkflowSessionSummary s) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line('Sessie', s.id),
        line(
          'Soort',
          s.kind == 'EDIT'
              ? 'Records aanpassen'
              : 'Nieuwe bestanden in ZCBS zetten',
        ),
        line('Gebruiker', s.user ?? ''),
        line('Collectie', s.collection ?? ''),
        line(s.kind == 'EDIT' ? 'Records' : 'Bestanden', '${s.fileCount}'),
        line('Fase', s.phaseText),
        line('Status', _statusLabel(s.status)),
        line('Gestart', _when(s.createdAt)),
        line(
          'Laatste bericht',
          '${_when(s.updatedAt)} (${s.updates} berichten)',
        ),
        line('Computer', s.computer ?? ''),
        line('Versie', s.appVersion ?? ''),
        line('IP-adres', s.ip ?? ''),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = _detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Doorloop', style: theme.textTheme.titleLarge),
            IconButton(
              key: const Key('workflow-session-refresh'),
              tooltip: 'Verversen',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        if (_loading && detail == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (detail != null) ...[
          _summary(detail.summary),
          const SizedBox(height: 16),
          Text('Tijdlijn', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          SelectionArea(
            child: Column(
              key: const Key('workflow-session-events'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final event in detail.events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_when(event.createdAt)}  ·  ${event.message}'
                      '${event.phase > 0 ? '  (fase ${event.phase}${event.phaseLabel == null ? '' : ': ${event.phaseLabel}'})' : ''}',
                      style: _mono,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Laatste momentopname van de app',
            style: theme.textTheme.titleMedium,
          ),
          if (detail.snapshot.isEmpty) const Text('Nog niets ontvangen.'),
          for (final entry in detail.snapshot.entries)
            ExpansionTile(
              key: Key('workflow-snapshot-${entry.key}'),
              tilePadding: EdgeInsets.zero,
              title: Text(_title(entry.key, entry.value)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxHeight: 520),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(_render(entry.value), style: _mono),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}
