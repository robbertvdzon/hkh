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
    this.source,
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
        source: json['source'] as String?,
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

  /// De bron die de beheerder in de workflow-app heeft ingesteld (macbook, windows-laptop, hkh, ...).
  final String? source;
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
    this.source,
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
        source: json['source'] as String?,
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
  final String? source;

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

/// Eén logregel van de workflow-app (INFO, WARN of ERROR).
class AppLogEntry {
  const AppLogEntry({
    required this.id,
    required this.time,
    required this.level,
    required this.logger,
    required this.message,
    required this.source,
    required this.computer,
    this.appVersion,
  });

  factory AppLogEntry.fromJson(Map<String, dynamic> json) => AppLogEntry(
    id: (json['id'] as num).toInt(),
    time: DateTime.parse(json['time'] as String).toLocal(),
    level: json['level'] as String? ?? 'INFO',
    logger: json['logger'] as String? ?? '',
    message: json['message'] as String? ?? '',
    source: json['source'] as String? ?? '',
    computer: json['computer'] as String? ?? '',
    appVersion: json['appVersion'] as String?,
  );

  final int id;
  final DateTime time;
  final String level;
  final String logger;
  final String message;
  final String source;
  final String computer;
  final String? appVersion;
}

/// Een pagina logregels, nieuwste eerst; [next] is de cursor voor de oudere regels.
class AppLogPage {
  const AppLogPage({required this.items, this.next});

  factory AppLogPage.fromJson(Map<String, dynamic> json) => AppLogPage(
    items: [
      for (final item in (json['items'] as List<dynamic>? ?? const []))
        AppLogEntry.fromJson(item as Map<String, dynamic>),
    ],
    next: json['next'] as String?,
  );

  final List<AppLogEntry> items;
  final String? next;
}

/// De stand van één computer in het app-log.
class AppLogOverviewRow {
  const AppLogOverviewRow({
    required this.source,
    required this.computer,
    required this.lastSeen,
    required this.lines24h,
    required this.warnings24h,
    required this.errors24h,
    this.appVersion,
  });

  factory AppLogOverviewRow.fromJson(Map<String, dynamic> json) =>
      AppLogOverviewRow(
        source: json['source'] as String? ?? '',
        computer: json['computer'] as String? ?? '',
        appVersion: json['appVersion'] as String?,
        lastSeen: DateTime.parse(json['lastSeen'] as String).toLocal(),
        lines24h: (json['lines24h'] as num?)?.toInt() ?? 0,
        warnings24h: (json['warnings24h'] as num?)?.toInt() ?? 0,
        errors24h: (json['errors24h'] as num?)?.toInt() ?? 0,
      );

  final String source;
  final String computer;
  final String? appVersion;
  final DateTime lastSeen;
  final int lines24h;
  final int warnings24h;
  final int errors24h;
}

/// De filters van de lijst met logregels; wat null is, filtert niet.
class AppLogFilter {
  const AppLogFilter({
    this.source,
    this.computer,
    this.level,
    this.version,
    this.query,
  });

  final String? source;
  final String? computer;

  /// Minimumniveau: WARN (waarschuwingen en fouten) of ERROR; null = alles.
  final String? level;
  final String? version;
  final String? query;
}

abstract interface class AdminWorkflowLogSource {
  Future<List<AppLogOverviewRow>> appLogOverview(AdminIdentity identity);
  Future<List<String>> appLogVersions(AdminIdentity identity);
  Future<AppLogPage> appLogs(
    AdminIdentity identity,
    AppLogFilter filter, {
    String? before,
  });

  Future<List<String>> sources(AdminIdentity identity);
  Future<List<WorkflowLoginEntry>> logins(
    AdminIdentity identity, {
    String? source,
  });
  Future<List<WorkflowSessionSummary>> sessions(
    AdminIdentity identity,
    WorkflowKind kind, {
    String? source,
  });
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
  Future<List<String>> sources(AdminIdentity identity) async =>
      ((await _get(identity, '/sources')) as List<dynamic>)
          .map((e) => e as String)
          .toList(growable: false);

  @override
  Future<List<WorkflowLoginEntry>> logins(
    AdminIdentity identity, {
    String? source,
  }) async =>
      ((await _get(identity, '/logins', {
                'limit': '500',
                if (source != null) 'source': source,
              }))
              as List<dynamic>)
          .map((e) => WorkflowLoginEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

  @override
  Future<List<WorkflowSessionSummary>> sessions(
    AdminIdentity identity,
    WorkflowKind kind, {
    String? source,
  }) async =>
      ((await _get(identity, '/sessions', {
                'kind': kind.api,
                'limit': '500',
                if (source != null) 'source': source,
              }))
              as List<dynamic>)
          .map(
            (e) => WorkflowSessionSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false);

  @override
  Future<List<AppLogOverviewRow>> appLogOverview(
    AdminIdentity identity,
  ) async => ((await _get(identity, '/app-logs/overview')) as List<dynamic>)
      .map((e) => AppLogOverviewRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);

  @override
  Future<List<String>> appLogVersions(AdminIdentity identity) async =>
      ((await _get(identity, '/app-logs/versions')) as List<dynamic>)
          .map((e) => e as String)
          .toList(growable: false);

  @override
  Future<AppLogPage> appLogs(
    AdminIdentity identity,
    AppLogFilter filter, {
    String? before,
  }) async => AppLogPage.fromJson(
    (await _get(identity, '/app-logs', {
          'limit': '200',
          if (filter.source != null) 'source': filter.source!,
          if (filter.computer != null) 'computer': filter.computer!,
          if (filter.level != null) 'level': filter.level!,
          if (filter.version != null) 'version': filter.version!,
          if (filter.query != null && filter.query!.trim().isNotEmpty)
            'q': filter.query!.trim(),
          if (before != null) 'before': before,
        }))
        as Map<String, dynamic>,
  );

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

/// `nl.vdzon.hkhworkflow.testrun.TestRunService` wordt `n.v.h.t.TestRunService`.
String _shortLogger(String logger) {
  final parts = logger.split('.');
  if (parts.length < 2) return logger;
  return [
    for (var i = 0; i < parts.length - 1; i++)
      parts[i].isEmpty ? '' : parts[i][0],
    parts.last,
  ].join('.');
}

Color _levelColor(BuildContext context, String level) => switch (level) {
  'ERROR' => Theme.of(context).colorScheme.error,
  'WARN' => Colors.orange.shade800,
  _ => Colors.black54,
};

String _describeError(Object error) => error is StateError
    ? error.message
    : 'Het logboek kon niet worden geladen.';

enum _Tab { logins, created, edited, appLog }

/// De laatst gekozen tab, zodat je na een sessie weer op dezelfde lijst terugkomt.
_Tab _lastTab = _Tab.created;
String? _lastSource;

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
  List<String> _sources = const [];

  /// De gekozen bron; null = alle bronnen.
  String? _source = _lastSource;
  bool _loading = true;
  String? _error;
  final _horizontal = ScrollController();

  // Tabblad App-log.
  List<AppLogOverviewRow> _overview = const [];
  List<String> _versions = const [];
  List<AppLogEntry> _appLogs = const [];
  String? _appLogNext;
  bool _loadingMore = false;
  String? _computer;
  String? _level;
  String? _version;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sources = await widget.source.sources(widget.identity);
      if (_source != null && !sources.contains(_source)) _source = null;
      if (_tab == _Tab.appLog) {
        final overview = await widget.source.appLogOverview(widget.identity);
        final versions = await widget.source.appLogVersions(widget.identity);
        if (_computer != null &&
            !overview.any(
              (row) =>
                  row.computer == _computer &&
                  (_source == null || row.source == _source),
            )) {
          _computer = null;
        }
        if (_version != null && !versions.contains(_version)) _version = null;
        final page = await widget.source.appLogs(
          widget.identity,
          _appLogFilter,
        );
        if (!mounted) return;
        setState(() {
          _sources = sources;
          _overview = overview;
          _versions = versions;
          _appLogs = page.items;
          _appLogNext = page.next;
          _error = null;
          _loading = false;
        });
      } else if (_tab == _Tab.logins) {
        final logins = await widget.source.logins(
          widget.identity,
          source: _source,
        );
        if (!mounted) return;
        setState(() {
          _sources = sources;
          _logins = logins;
          _error = null;
          _loading = false;
        });
      } else {
        final sessions = await widget.source.sessions(
          widget.identity,
          _tab == _Tab.created ? WorkflowKind.newFiles : WorkflowKind.edit,
          source: _source,
        );
        if (!mounted) return;
        setState(() {
          _sources = sources;
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

  AppLogFilter get _appLogFilter => AppLogFilter(
    source: _source,
    computer: _computer,
    level: _level,
    version: _version,
    query: _query.text,
  );

  Future<void> _loadMore() async {
    final before = _appLogNext;
    if (before == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.source.appLogs(
        widget.identity,
        _appLogFilter,
        before: before,
      );
      if (!mounted) return;
      setState(() {
        _appLogs = [..._appLogs, ...page.items];
        _appLogNext = page.next;
        _error = null;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(error);
        _loadingMore = false;
      });
    }
  }

  void _filter(void Function() change) {
    setState(change);
    _load();
  }

  /// Een computer zonder melding in de laatste 24 uur is grijs.
  Widget _overviewTable() {
    final now = DateTime.now();
    return DataTable(
      key: const Key('app-log-overview'),
      showCheckboxColumn: false,
      columnSpacing: 20,
      headingTextStyle: _headingStyle,
      dataTextStyle: _dataStyle,
      columns: const [
        DataColumn(label: Text('Bron')),
        DataColumn(label: Text('Computer')),
        DataColumn(label: Text('Versie')),
        DataColumn(label: Text('Laatst gezien')),
        DataColumn(label: Text('Regels 24 uur'), numeric: true),
        DataColumn(label: Text('Waarschuwingen'), numeric: true),
        DataColumn(label: Text('Fouten'), numeric: true),
      ],
      rows: [
        for (final row in _overview)
          () {
            final stale =
                now.difference(row.lastSeen) > const Duration(hours: 24);
            final grey = stale ? const TextStyle(color: Colors.black38) : null;
            return DataRow(
              key: ValueKey('${row.source}/${row.computer}'),
              onSelectChanged: (_) => _filter(() {
                _source = row.source;
                _lastSource = row.source;
                _computer = row.computer;
              }),
              cells: [
                DataCell(Text(row.source, style: grey)),
                DataCell(Text(row.computer, style: grey)),
                DataCell(Text(row.appVersion ?? '', style: grey)),
                DataCell(Text(_when(row.lastSeen), style: grey)),
                DataCell(Text('${row.lines24h}', style: grey)),
                DataCell(
                  Text(
                    '${row.warnings24h}',
                    style: stale
                        ? grey
                        : TextStyle(
                            color: row.warnings24h > 0
                                ? Colors.orange.shade800
                                : null,
                          ),
                  ),
                ),
                DataCell(
                  Text(
                    '${row.errors24h}',
                    style: stale
                        ? grey
                        : TextStyle(
                            color: row.errors24h > 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                            fontWeight: row.errors24h > 0
                                ? FontWeight.w600
                                : null,
                          ),
                  ),
                ),
              ],
            );
          }(),
      ],
    );
  }

  Widget _appLogFilters() {
    final computers = {
      for (final row in _overview)
        if (_source == null || row.source == _source) row.computer,
    }.toList()..sort();
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String?>(
          key: const Key('app-log-computer'),
          value: computers.contains(_computer) ? _computer : null,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Alle computers'),
            ),
            for (final computer in computers)
              DropdownMenuItem<String?>(value: computer, child: Text(computer)),
          ],
          onChanged: _loading
              ? null
              : (value) => _filter(() => _computer = value),
        ),
        DropdownButton<String?>(
          key: const Key('app-log-level'),
          value: _level,
          items: const [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Alle niveaus (INFO en hoger)'),
            ),
            DropdownMenuItem<String?>(
              value: 'WARN',
              child: Text('Waarschuwingen en fouten'),
            ),
            DropdownMenuItem<String?>(
              value: 'ERROR',
              child: Text('Alleen fouten'),
            ),
          ],
          onChanged: _loading ? null : (value) => _filter(() => _level = value),
        ),
        DropdownButton<String?>(
          key: const Key('app-log-version'),
          value: _versions.contains(_version) ? _version : null,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Alle versies'),
            ),
            for (final version in _versions)
              DropdownMenuItem<String?>(value: version, child: Text(version)),
          ],
          onChanged: _loading
              ? null
              : (value) => _filter(() => _version = value),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            key: const Key('app-log-query'),
            controller: _query,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Zoek in bericht of logger',
              suffixIcon: IconButton(
                key: const Key('app-log-search'),
                tooltip: 'Zoeken',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
      ],
    );
  }

  Widget _appLogView() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_overview.isEmpty)
          const Text('Nog geen app-log ontvangen.')
        else
          Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 16),
              child: _overviewTable(),
            ),
          ),
        const SizedBox(height: 8),
        _appLogFilters(),
        const SizedBox(height: 12),
        if (_appLogs.isEmpty)
          const Text('Geen regels voor deze keuze.')
        else
          SelectionArea(
            child: Column(
              key: const Key('app-log-lines'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in _appLogs)
                  _AppLogRow(
                    key: ValueKey('app-log-${entry.id}'),
                    entry: entry,
                  ),
              ],
            ),
          ),
        if (_appLogNext != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('app-log-more'),
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Laden…' : 'Meer laden'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Het app-log bevat de regels van INFO en hoger en wordt na 30 dagen '
          'opgeruimd.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
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
      DataColumn(label: Text('Bron')),
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
            DataCell(Text(entry.source ?? '')),
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
        const DataColumn(label: Text('Bron')),
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
              DataCell(Text(s.source ?? '')),
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
    final count = switch (_tab) {
      _Tab.logins => _logins.length,
      _Tab.appLog => _appLogs.length,
      _ => _sessions.length,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wat de workflow-app van de vrijwilligers meldt: elke inlogpoging, '
          'elke doorloop om nieuwe bestanden in ZCBS te zetten en elke '
          'doorloop om records aan te passen. Klik op een doorloop voor de '
          'volledige log. Het tabblad App-log toont de logregels van de app '
          'zelf. De gegevens komen ongecontroleerd binnen via een '
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
                ButtonSegment(value: _Tab.appLog, label: Text('App-log')),
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
            DropdownButton<String?>(
              key: const Key('workflow-log-source'),
              value: _source,
              hint: const Text('Alle bronnen'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Alle bronnen'),
                ),
                for (final source in _sources)
                  DropdownMenuItem<String?>(value: source, child: Text(source)),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() {
                        _source = value;
                        _lastSource = value;
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
        else if (_tab == _Tab.appLog)
          _appLogView()
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

/// Eén logregel: tijd, niveau, versie, ingekorte logger en het bericht; een bericht met meer regels (een stacktrace) klapt uit.
class _AppLogRow extends StatefulWidget {
  const _AppLogRow({required this.entry, super.key});

  final AppLogEntry entry;

  @override
  State<_AppLogRow> createState() => _AppLogRowState();
}

class _AppLogRowState extends State<_AppLogRow> {
  static const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final lines = entry.message.split('\n');
    final more = lines.length - 1;
    final shown = _expanded ? entry.message : lines.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: _mono,
              children: [
                TextSpan(text: '${_when(entry.time)}  '),
                TextSpan(
                  text: entry.level.padRight(5),
                  style: TextStyle(
                    color: _levelColor(context, entry.level),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.appVersion != null)
                  TextSpan(
                    text: '  ${entry.appVersion}',
                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                TextSpan(
                  text: '  ${_shortLogger(entry.logger)}  ',
                  style: const TextStyle(color: Colors.black54),
                ),
                TextSpan(text: shown),
              ],
            ),
          ),
          if (more > 0)
            InkWell(
              key: Key('app-log-expand-${entry.id}'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _expanded ? '▾ inklappen' : '▸ $more regels meer',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
            ),
        ],
      ),
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
        line('Bron', s.source ?? ''),
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
