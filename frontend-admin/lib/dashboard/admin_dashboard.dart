import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';

/// Aantallen over een periode, uit het logboek van verzoeken.
class UsagePeriod {
  const UsagePeriod({
    this.aiQuestions = 0,
    this.expansions = 0,
    this.searches = 0,
    this.uniqueVisitors = 0,
    this.testVisitors = 0,
    this.testRequests = 0,
    this.botRequests = 0,
    this.failed = 0,
    this.costUsd = 0,
    this.averageAnswerMs,
  });

  factory UsagePeriod.fromJson(Map<String, dynamic> json) => UsagePeriod(
    aiQuestions: (json['aiQuestions'] as num?)?.toInt() ?? 0,
    expansions: (json['expansions'] as num?)?.toInt() ?? 0,
    searches: (json['searches'] as num?)?.toInt() ?? 0,
    uniqueVisitors: (json['uniqueVisitors'] as num?)?.toInt() ?? 0,
    testVisitors: (json['testVisitors'] as num?)?.toInt() ?? 0,
    testRequests: (json['testRequests'] as num?)?.toInt() ?? 0,
    botRequests: (json['botRequests'] as num?)?.toInt() ?? 0,
    failed: (json['failed'] as num?)?.toInt() ?? 0,
    costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
    averageAnswerMs: (json['averageAnswerMs'] as num?)?.toInt(),
  );

  final int aiQuestions;
  final int expansions;
  final int searches;
  final int uniqueVisitors;
  final int testVisitors;
  final int testRequests;
  final int botRequests;
  final int failed;
  final double costUsd;
  final int? averageAnswerMs;
}

class DashboardRole {
  const DashboardRole({required this.label, required this.model});

  factory DashboardRole.fromJson(Map<String, dynamic> json) => DashboardRole(
    label: json['label'] as String? ?? '',
    model: json['model'] as String? ?? '',
  );

  final String label;
  final String model;
}

class DashboardAi {
  const DashboardAi({
    required this.method,
    required this.roles,
    required this.writeBudgetChars,
    required this.runtimeConfigured,
    required this.runtimeReachable,
    required this.workersOnline,
  });

  factory DashboardAi.fromJson(Map<String, dynamic> json) => DashboardAi(
    method: json['method'] as String? ?? 'AGENT',
    roles: (json['roles'] as List<dynamic>? ?? const [])
        .map((item) => DashboardRole.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    writeBudgetChars: (json['writeBudgetChars'] as num?)?.toInt() ?? 0,
    runtimeConfigured: json['runtimeConfigured'] as bool? ?? false,
    runtimeReachable: json['runtimeReachable'] as bool? ?? false,
    workersOnline: (json['workersOnline'] as num?)?.toInt() ?? 0,
  );

  final String method;
  final List<DashboardRole> roles;
  final int writeBudgetChars;
  final bool runtimeConfigured;
  final bool runtimeReachable;
  final int workersOnline;
}

class DashboardRun {
  const DashboardRun({
    required this.status,
    required this.mode,
    required this.startedAt,
    required this.failed,
    this.finishedAt,
    this.message,
  });

  factory DashboardRun.fromJson(Map<String, dynamic> json) => DashboardRun(
    status: json['status'] as String? ?? '',
    mode: json['mode'] as String? ?? '',
    startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateTime.parse(json['finishedAt'] as String).toLocal(),
    failed: (json['failed'] as num?)?.toInt() ?? 0,
    message: json['message'] as String?,
  );

  final String status;
  final String mode;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int failed;
  final String? message;
}

class DashboardCollection {
  const DashboardCollection({
    required this.totalRecords,
    required this.running,
    required this.cardsDone,
    required this.cardsFailed,
    required this.cardsPending,
    this.lastRun,
  });

  factory DashboardCollection.fromJson(Map<String, dynamic> json) {
    final cards = json['cards'] as Map<String, dynamic>? ?? const {};
    final run = json['lastRun'] as Map<String, dynamic>?;
    return DashboardCollection(
      totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
      running: json['running'] as bool? ?? false,
      cardsDone: (cards['cards'] as num?)?.toInt() ?? 0,
      cardsFailed: (cards['failed'] as num?)?.toInt() ?? 0,
      cardsPending: (cards['pending'] as num?)?.toInt() ?? 0,
      lastRun: run == null ? null : DashboardRun.fromJson(run),
    );
  }

  final int totalRecords;
  final bool running;
  final int cardsDone;
  final int cardsFailed;
  final int cardsPending;
  final DashboardRun? lastRun;
}

class DashboardData {
  const DashboardData({
    required this.ai,
    required this.collection,
    required this.today,
    required this.last7Days,
    required this.last30Days,
    required this.retentionDays,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'] as Map<String, dynamic>? ?? const {};
    UsagePeriod period(String key) =>
        UsagePeriod.fromJson(usage[key] as Map<String, dynamic>? ?? const {});
    return DashboardData(
      ai: DashboardAi.fromJson(json['ai'] as Map<String, dynamic>? ?? const {}),
      collection: DashboardCollection.fromJson(
        json['collection'] as Map<String, dynamic>? ?? const {},
      ),
      today: period('today'),
      last7Days: period('last7Days'),
      last30Days: period('last30Days'),
      retentionDays: (usage['retentionDays'] as num?)?.toInt() ?? 30,
    );
  }

  final DashboardAi ai;
  final DashboardCollection collection;
  final UsagePeriod today;
  final UsagePeriod last7Days;
  final UsagePeriod last30Days;
  final int retentionDays;
}

abstract interface class AdminDashboardSource {
  Future<DashboardData> load(AdminIdentity identity);
}

class AdminDashboardClient implements AdminDashboardSource {
  AdminDashboardClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  @override
  Future<DashboardData> load(AdminIdentity identity) async {
    final response = await _client
        .get(
          Uri.parse('$apiBaseUrl/api/admin/dashboard'),
          headers: identity.requestHeaders,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('Overzicht laden mislukt (${response.statusCode})');
    }
    return DashboardData.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

String _thousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _when(DateTime? time) {
  if (time == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.day)}-${two(time.month)} ${two(time.hour)}:${two(time.minute)}';
}

String _duration(int? ms) {
  if (ms == null) return '–';
  final seconds = (ms / 1000).round();
  if (seconds < 60) return '$seconds s';
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _runStatus(String status) => switch (status) {
  'COMPLETED' => 'voltooid',
  'FAILED' => 'mislukt',
  'RUNNING' => 'bezig',
  _ => status.toLowerCase(),
};

String _runMode(String mode) => switch (mode) {
  'FAST' => 'snel ophalen',
  'FULL' => 'volledig ophalen',
  'TEXT' => 'documenttekst',
  'CARDS' => 'AI-kaarten',
  _ => mode.toLowerCase(),
};

/// De startpagina: wat er nu speelt en een knop naar elk onderdeel.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    required this.identity,
    required this.onOpen,
    this.source,
    this.showCollection = true,
    this.showAiSettings = true,
    this.showAiCompare = true,
    this.showAiCapacity = false,
    this.showRequestLog = true,
    this.showWorkflowLog = true,
    super.key,
  });

  final AdminIdentity identity;
  final AdminDashboardSource? source;
  final void Function(String path) onOpen;
  final bool showCollection;
  final bool showAiSettings;
  final bool showAiCompare;
  final bool showAiCapacity;
  final bool showRequestLog;
  final bool showWorkflowLog;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final source = widget.source;
    if (source == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await source.load(widget.identity);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message
            : 'De statusgegevens konden niet worden geladen.';
        _loading = false;
      });
    }
  }

  List<String> _attention(DashboardData data) => [
    if (data.ai.runtimeConfigured && !data.ai.runtimeReachable)
      'De AI-runtime is niet bereikbaar; AI-vragen blijven wachten.',
    if (data.ai.runtimeReachable && data.ai.workersOnline == 0)
      'Er is geen worker online voor de AI-runtime.',
    if (data.today.failed > 0)
      '${data.today.failed} AI-vraag${data.today.failed == 1 ? '' : 'en'} mislukt vandaag.',
    if (data.collection.lastRun?.status == 'FAILED')
      'De laatste inleesrun van het archief is mislukt.',
    if (data.collection.cardsPending > 0 && !data.collection.running)
      '${_thousands(data.collection.cardsPending)} records hebben nog geen AI-kaart.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Beheerder geverifieerd · ${widget.identity.email}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              key: const Key('dashboard-refresh'),
              tooltip: 'Verversen',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading && data == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (data != null) ...[
          if (_attention(data).isNotEmpty) ...[
            Card(
              key: const Key('dashboard-attention'),
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Aandacht',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    for (final line in _attention(data))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _usageCard(context, data),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (widget.showCollection)
              _tile(
                key: const Key('admin-tile-archief'),
                icon: Icons.cloud_download_outlined,
                title: 'Archief',
                path: '/archief',
                lines: data == null ? const [] : _collectionLines(data),
                fallback: 'Records ophalen, documentteksten en AI-kaarten.',
              ),
            if (widget.showAiSettings)
              _tile(
                key: const Key('admin-tile-ai-instellingen'),
                icon: Icons.psychology_outlined,
                title: 'AI-instellingen',
                path: '/ai-instellingen',
                lines: data == null ? const [] : _aiLines(data),
                fallback: 'Methode, modellen per rol en tekstbudget.',
              ),
            if (widget.showAiCapacity)
              _tile(
                key: const Key('admin-tile-ai-capaciteit'),
                icon: Icons.speed,
                title: 'Capaciteitstests',
                path: '/ai-capaciteit',
                lines: const [],
                fallback:
                    'Duurtests per provider en model, met parallelle zoekopdrachten.',
              ),
            if (widget.showAiCompare)
              _tile(
                key: const Key('admin-tile-ai-vergelijken'),
                icon: Icons.compare_arrows,
                title: 'AI vergelijken',
                path: '/ai-vergelijken',
                lines: const [],
                fallback: 'Testset draaien en recente onderzoeken bekijken.',
              ),
            if (widget.showRequestLog)
              _tile(
                key: const Key('admin-tile-logboek'),
                icon: Icons.receipt_long_outlined,
                title: 'Logboek van verzoeken',
                path: '/logboek',
                lines: data == null
                    ? const []
                    : [
                        '${_thousands(data.today.aiQuestions + data.today.expansions + data.today.searches)} verzoeken vandaag',
                        '${_thousands(data.last7Days.uniqueVisitors)} unieke bezoekers in 7 dagen',
                      ],
                fallback:
                    'Alle AI-vragen en zoekopdrachten met adres en tijden.',
              ),
            if (widget.showWorkflowLog)
              _tile(
                key: const Key('admin-tile-workflow-logboek'),
                icon: Icons.fact_check_outlined,
                title: 'Workflow-logboek',
                path: '/workflow-logboek',
                lines: const [],
                fallback:
                    'Inlogpogingen en doorlopen van de workflow-app, met alle logs.',
              ),
          ],
        ),
      ],
    );
  }

  List<String> _collectionLines(DashboardData data) {
    final c = data.collection;
    final run = c.lastRun;
    return [
      '${_thousands(c.totalRecords)} records',
      if (c.running)
        'Er loopt nu een run'
      else if (run != null)
        'Laatste run: ${_runStatus(run.status)} (${_runMode(run.mode)}) ${_when(run.finishedAt ?? run.startedAt)}',
      'AI-kaarten: ${_thousands(c.cardsDone)} klaar, ${_thousands(c.cardsFailed)} mislukt, ${_thousands(c.cardsPending)} te doen',
    ];
  }

  List<String> _aiLines(DashboardData data) {
    final ai = data.ai;
    String role(String label) {
      for (final r in ai.roles) {
        if (r.label == label) return r.model;
      }
      return '';
    }

    return [
      'Methode: ${ai.method == 'PIPELINE' ? 'pijplijn' : 'agent'}',
      if (ai.method == 'PIPELINE')
        'Richten: ${role('Richten')} · Schrijven: ${role('Schrijven')}'
      else
        'Agent: ${role('Agent')}',
      if (!ai.runtimeConfigured)
        'Runtime niet ingesteld'
      else if (!ai.runtimeReachable)
        'Runtime niet bereikbaar'
      else
        'Runtime bereikbaar, ${ai.workersOnline} worker${ai.workersOnline == 1 ? '' : 's'} online',
    ];
  }

  Widget _tile({
    required Key key,
    required IconData icon,
    required String title,
    required String path,
    required List<String> lines,
    required String fallback,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 300,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onOpen(path),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 10),
                if (lines.isEmpty)
                  Text(fallback, style: theme.textTheme.bodySmall)
                else
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(line, style: theme.textTheme.bodySmall),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _usageCard(BuildContext context, DashboardData data) {
    final theme = Theme.of(context);
    String visitors(UsagePeriod p) => p.testVisitors > 0
        ? '${_thousands(p.uniqueVisitors)} (waarvan ${p.testVisitors} test)'
        : _thousands(p.uniqueVisitors);
    final rows = <(String, String Function(UsagePeriod))>[
      ('Unieke bezoekers', visitors),
      ('AI-vragen', (p) => _thousands(p.aiQuestions)),
      ('Uitwerkingen', (p) => _thousands(p.expansions)),
      ('Zoekopdrachten', (p) => _thousands(p.searches)),
      ('Gem. antwoordtijd AI', (p) => _duration(p.averageAnswerMs)),
      ('Kosten (API-equivalent)', (p) => '\$${p.costUsd.toStringAsFixed(2)}'),
      ('Mislukte AI-vragen', (p) => _thousands(p.failed)),
      ('Testverkeer (verzoeken)', (p) => _thousands(p.testRequests)),
      ('Bots (niet meegeteld)', (p) => _thousands(p.botRequests)),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gebruik', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Unieke bezoekers tellen per browser of ingelogde gebruiker; bots tellen niet mee, testverkeer wel.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const Key('admin-usage-table'),
                columnSpacing: 24,
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                dataTextStyle: const TextStyle(fontSize: 12),
                columns: const [
                  DataColumn(label: Text('')),
                  DataColumn(label: Text('Vandaag')),
                  DataColumn(label: Text('7 dagen')),
                  DataColumn(label: Text('30 dagen')),
                ],
                rows: [
                  for (final (label, value) in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(label)),
                        DataCell(Text(value(data.today))),
                        DataCell(Text(value(data.last7Days))),
                        DataCell(Text(value(data.last30Days))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'IP-adressen worden na ${data.retentionDays} dagen afgekapt; daarna kunnen bezoekers niet meer uniek worden geteld.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
