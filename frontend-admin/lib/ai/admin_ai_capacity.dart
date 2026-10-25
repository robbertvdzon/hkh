import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';
import '../shell/admin_router.dart';

abstract interface class AdminAiCapacitySource {
  Future<Map<String, dynamic>> load(AdminIdentity identity);
  Future<Map<String, dynamic>> detail(AdminIdentity identity, String id);
  Future<Map<String, dynamic>> result(
    AdminIdentity identity,
    String campaignId,
    String runId,
  );
  Future<void> post(
    AdminIdentity identity,
    String path, [
    Map<String, dynamic>? body,
  ]);
}

class AdminAiCapacityClient implements AdminAiCapacitySource {
  AdminAiCapacityClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();
  final String apiBaseUrl;
  final http.Client _client;
  Uri _uri(String path) =>
      Uri.parse('$apiBaseUrl/api/admin/ai-search/capacity$path');

  Map<String, dynamic> _read(http.Response response) {
    if (response.statusCode != 200) {
      String message = 'Verzoek mislukt (${response.statusCode})';
      try {
        message =
            (jsonDecode(response.body) as Map<String, dynamic>)['message']
                as String? ??
            message;
      } catch (_) {}
      throw StateError(message);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> load(AdminIdentity identity) async => _read(
    await _client
        .get(_uri(''), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 30)),
  );
  @override
  Future<Map<String, dynamic>> detail(
    AdminIdentity identity,
    String id,
  ) async => _read(
    await _client
        .get(_uri('/campaigns/$id'), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 30)),
  );
  @override
  Future<Map<String, dynamic>> result(
    AdminIdentity identity,
    String campaignId,
    String runId,
  ) async => _read(
    await _client
        .get(
          _uri('/campaigns/$campaignId/runs/$runId/result'),
          headers: identity.requestHeaders,
        )
        .timeout(const Duration(seconds: 30)),
  );

  @override
  Future<void> post(
    AdminIdentity identity,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    _read(
      await _client
          .post(
            _uri(path),
            headers: {
              ...identity.requestHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body ?? {}),
          )
          .timeout(const Duration(seconds: 30)),
    );
  }
}

class AdminAiCapacityPage extends StatefulWidget {
  const AdminAiCapacityPage({
    required this.identity,
    required this.source,
    this.onNavigate,
    super.key,
  });
  final AdminIdentity identity;
  final AdminAiCapacitySource source;
  final void Function(String path)? onNavigate;
  @override
  State<AdminAiCapacityPage> createState() => _AdminAiCapacityPageState();
}

class _AdminAiCapacityPageState extends State<AdminAiCapacityPage> {
  Map<String, dynamic>? _state;
  Map<String, dynamic>? _detail;
  String? _selected;
  String? _error;
  bool _busy = false;
  Timer? _timer;
  int _runPage = 0;

  List<Map<String, dynamic>> _rows(Map<String, dynamic>? data, String key) =>
      (data?[key] as List? ?? []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final state = await widget.source.load(widget.identity);
      final selected = _selected;
      final detail = selected == null
          ? null
          : await widget.source.detail(widget.identity, selected);
      if (mounted) {
        setState(() {
          _state = state;
          if (_selected == selected) _detail = detail;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Capaciteitstests laden mislukt.',
        );
      }
    }
  }

  Future<void> _action(String path, [Map<String, dynamic>? body]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.source.post(widget.identity, path, body);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is StateError ? e.message : 'Actie mislukt.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final name = TextEditingController();
    final text = TextEditingController();
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vragenlijst importeren'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Naam / versie'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText:
                      'Eén vraag per regel, of een JSON-lijst met question, depth en category',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final content = text.text.trim();
                final questions = content.startsWith('[')
                    ? jsonDecode(content) as List
                    : content
                          .split('\n')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                Navigator.pop(context, {
                  'name': name.text,
                  'questions': questions,
                });
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('De JSON-lijst is ongeldig.')),
                );
              }
            },
            child: const Text('Als vaste versie opslaan'),
          ),
        ],
      ),
    );
    name.dispose();
    text.dispose();
    if (body != null) await _action('/datasets', body);
  }

  Future<void> _create() async {
    final state = _state!;
    final datasets = _rows(state, 'datasets');
    final options = _rows(state, 'options');
    if (datasets.isEmpty || options.isEmpty) return;
    var dataset = datasets.first['id'] as String;
    var option = 0;
    var repeat = false;
    var expand = false;
    final followUp = TextEditingController();
    String? error;
    final name = TextEditingController(text: 'Duurtest');
    final parallel = TextEditingController(text: '1');
    final maximum = TextEditingController(text: '1000');
    final hours = TextEditingController(text: '168');
    final alias = TextEditingController(text: 'default');
    final snapshot = TextEditingController(text: 'onbekend');
    final cost = TextEditingController();
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final execution =
              options[option]['execution'] as Map<String, dynamic>;
          final held = _rows(state, 'campaigns').any(
            (c) =>
                c['provider'] == execution['vendorId'] &&
                c['holds_provider'] == true,
          );
          return AlertDialog(
            title: const Text('Campagne voorbereiden'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Naam'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: dataset,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vaste vragenlijst',
                      ),
                      items: datasets
                          .map(
                            (d) => DropdownMenuItem(
                              value: d['id'] as String,
                              child: Text(
                                '${d['name']} (${d['count']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => update(() => dataset = v!),
                    ),
                    DropdownButtonFormField<int>(
                      key: const Key('capacity-provider'),
                      initialValue: option,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Provider / model / uitvoering',
                      ),
                      items: [
                        for (var i = 0; i < options.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              _execution(
                                    options[i]['execution']
                                        as Map<String, dynamic>,
                                  ) +
                                  (options[i]['available'] == true
                                      ? ''
                                      : ' (worker offline)'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() => option = v!),
                    ),
                    Text(
                      'Methode: ${state['method'] == 'PIPELINE' ? 'pijplijn' : 'agent'} · tekstbudget: ${state['writeBudgetChars']} tekens. Deze instellingen worden vastgezet. Iedere AI-fase gebruikt het gekozen model.',
                    ),
                    TextField(
                      controller: parallel,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText:
                            'Gelijktijdige volledige zoekopdrachten (1–50)',
                      ),
                    ),
                    TextField(
                      controller: maximum,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum zoekopdrachten',
                      ),
                    ),
                    TextField(
                      controller: hours,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximale looptijd in uren',
                      ),
                    ),
                    TextField(
                      controller: alias,
                      decoration: const InputDecoration(
                        labelText: 'Accountalias (geen credentials)',
                      ),
                    ),
                    TextField(
                      controller: snapshot,
                      decoration: const InputDecoration(
                        labelText: 'Collectie-/datasetversie',
                      ),
                    ),
                    TextField(
                      controller: cost,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Optioneel budget in USD (API-equivalent)',
                      ),
                    ),
                    if (state['method'] == 'PIPELINE')
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Volledig uitwerken wanneer beschikbaar',
                        ),
                        value: expand,
                        onChanged: (v) => update(() => expand = v),
                      ),
                    TextField(
                      controller: followUp,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Optionele vaste vervolgvraag per scenario',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Vragen herhalen na de eerste doorgang',
                      ),
                      value: repeat,
                      onChanged: (v) => update(() => repeat = v),
                    ),
                    const Text(
                      'Iedere vraag start een nieuw gesprek. Providercaching blijft actief; unieke vragen garanderen geen unieke bronnen. Beginquota en ander accountgebruik blijven van invloed.',
                    ),
                    if (held)
                      const Text(
                        'Deze provider heeft al een actieve campagne.',
                        style: TextStyle(color: Colors.red),
                      ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuleren'),
              ),
              FilledButton(
                onPressed: held
                    ? null
                    : () {
                        final p = int.tryParse(parallel.text),
                            m = int.tryParse(maximum.text),
                            h = int.tryParse(hours.text);
                        final budget = cost.text.trim().isEmpty
                            ? null
                            : double.tryParse(cost.text.replaceAll(',', '.'));
                        if (name.text.trim().isEmpty ||
                            p == null ||
                            p < 1 ||
                            p > 50 ||
                            m == null ||
                            m < 1 ||
                            m > 100000 ||
                            h == null ||
                            h < 1 ||
                            h > 8784 ||
                            (cost.text.trim().isNotEmpty &&
                                (budget == null || budget <= 0))) {
                          update(
                            () => error =
                                'Controleer de naam en numerieke grenzen.',
                          );
                          return;
                        }
                        Navigator.pop(context, {
                          'name': name.text.trim(),
                          'datasetId': dataset,
                          'execution': execution,
                          'parallelism': p,
                          'maxScenarios': m,
                          'hours': h,
                          'repeatQuestions': repeat,
                          'expandIfAvailable': expand,
                          'followUpQuestion': followUp.text.trim().isEmpty
                              ? null
                              : followUp.text.trim(),
                          'accountAlias': alias.text,
                          'datasetVersion': snapshot.text,
                          'maxCostUsd': budget,
                        });
                      },
                child: const Text('Instellingen controleren'),
              ),
            ],
          );
        },
      ),
    );
    for (final c in [
      name,
      parallel,
      maximum,
      hours,
      alias,
      snapshot,
      cost,
      followUp,
    ]) {
      c.dispose();
    }
    if (request == null || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duurtest starten'),
        content: Text(
          '${request['name']}\n${_execution(request['execution'] as Map<String, dynamic>)}\n${request['parallelism']} tegelijk · maximaal ${request['maxScenarios']} zoekopdrachten · ${request['hours']} uur\n\nDeze campagne voert echte HKH-zoekopdrachten uit met de ingestelde runtimeprovider. Verbruik begint na starten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Terug'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Campagne starten'),
          ),
        ],
      ),
    );
    if (confirm == true) await _action('/campaigns', request);
  }

  static String _execution(Map<String, dynamic> e) =>
      '${e['vendorId']} · ${e['model']} · ${e['mode']}';
  static String _status(dynamic value) =>
      const {
        'RUNNING': 'Bezig',
        'WAITING_LIMIT': 'Wacht op providerlimiet',
        'PAUSING': 'Lopende onderzoeken afronden',
        'PAUSED': 'Gepauzeerd',
        'STOPPING': 'Jobs stoppen',
        'STOPPED': 'Gestopt',
        'DRAINING': 'Campagne afronden',
        'LIMIT_REACHED': 'Lange providergrens bereikt',
        'COMPLETED': 'Afgerond',
        'SUCCEEDED': 'Geslaagd',
        'FAILED': 'Mislukt',
        'CANCELLED': 'Onderbroken',
        'RETRY': 'Wacht op herstel',
        'ACTIVE': 'Actief',
      }[value] ??
      '$value';

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Capaciteitstests',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _load,
              tooltip: 'Verversen',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Meet volledige HKH-zoekopdrachten per provider en model. Eén actieve campagne per provider; verschillende providers kunnen tegelijk draaien. Een bereikt aantal zonder waargenomen limiet is geen abonnementsgrens.',
        ),
        const SizedBox(height: 16),
        if (_error != null)
          SelectableText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (state == null)
          const LinearProgressIndicator()
        else ...[
          if ((state['catalogueError'] as String? ?? '').isNotEmpty)
            Text(state['catalogueError'] as String),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _action('/datasets/bundled'),
                child: const Text('1.000 HKH-vragen importeren'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _import,
                child: const Text('Eigen vragenlijst importeren'),
              ),
              FilledButton.icon(
                key: const Key('capacity-create'),
                onPressed:
                    _busy ||
                        _rows(state, 'datasets').isEmpty ||
                        _rows(state, 'options').isEmpty
                    ? null
                    : _create,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Nieuwe campagne'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final d in _rows(state, 'datasets'))
            Text(
              '${d['name']} · ${d['count']} vragen · SHA ${d['checksum'].toString().substring(0, 12)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          for (final c in _rows(state, 'campaigns'))
            Card(
              child: ListTile(
                selected: _selected == c['id'],
                title: Text(
                  '${c['name']} · ${_execution((c['config'] as Map<String, dynamic>)['execution'] as Map<String, dynamic>)}',
                ),
                subtitle: Text(
                  '${_status(c['status'])} · ${c['succeeded']} geslaagd · ${c['failed']} mislukt · ${c['active']} actief / wacht\n${c['reason'] ?? ''}${c['next_dispatch_at'] == null ? '' : '\nHervatten vanaf ${c['next_dispatch_at']}'}',
                ),
                isThreeLine: true,
                onTap: () {
                  setState(() {
                    _selected = c['id'] as String;
                    _detail = null;
                    _runPage = 0;
                  });
                  _load();
                },
              ),
            ),
          if (_rows(state, 'campaigns').isEmpty)
            const Text('Nog geen campagnes. Importeren start geen AI-runs.'),
          if (_detail != null) _details(),
        ],
      ],
    );
  }

  Widget _details() {
    final detail = _detail!;
    final c = detail['campaign'] as Map<String, dynamic>;
    final phases = _rows(detail, 'phases');
    final report = detail['report'] as Map<String, dynamic>? ?? {};
    final runs = _rows(detail, 'runs');
    final config = c['config'] as Map<String, dynamic>;
    final questions =
        (_rows(
                  _state,
                  'datasets',
                ).where((d) => d['id'] == c['dataset_id']).firstOrNull?['count']
                as num?)
            ?.toInt() ??
        runs.length;
    final metrics = <String, double>{};
    var attempts = 0;
    var missing = 0;
    double cost = 0;
    var knownCosts = 0;
    for (final p in phases) {
      final usage = p['usage'] as Map<String, dynamic>?;
      if (usage == null || usage['usageQuality'] == 'UNAVAILABLE') missing++;
      attempts += (usage?['attemptCount'] as num?)?.toInt() ?? 0;
      for (final m in (usage?['metrics'] as List? ?? [])) {
        final name = m['metric'] as String;
        metrics[name] =
            (metrics[name] ?? 0) + (double.tryParse('${m['quantity']}') ?? 0);
      }
      for (final v in (usage?['costs'] as List? ?? [])) {
        if (v['currency'] == 'USD') {
          knownCosts++;
          cost += double.tryParse('${v['amount']}') ?? 0;
        }
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${c['name']} — ${_status(c['status'])}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${config['method']} · ${config['parallelism']} parallel · account ${config['accountAlias']} · collectie ${config['datasetVersion']}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (['RUNNING', 'WAITING_LIMIT'].contains(c['status']))
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _action('/campaigns/$_selected/pause'),
                    child: const Text('Pauzeren'),
                  ),
                if (c['status'] == 'PAUSED')
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _action('/campaigns/$_selected/resume'),
                    child: const Text('Hervatten'),
                  ),
                if ([
                  'RUNNING',
                  'WAITING_LIMIT',
                  'PAUSING',
                  'PAUSED',
                ].contains(c['status']))
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _action('/campaigns/$_selected/stop'),
                    child: const Text('Stoppen en jobs annuleren'),
                  ),
                OutlinedButton(
                  onPressed: () => _export(
                    const JsonEncoder.withIndent('  ').convert(detail),
                  ),
                  child: const Text('JSON-export'),
                ),
                OutlinedButton(
                  onPressed: () => _export(_csv(runs)),
                  child: const Text('CSV-export'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${runs.length} gestart · ${runs.where((r) => r['status'] == 'SUCCEEDED').length} volledig geslaagd · ${runs.where((r) => r['status'] == 'FAILED').length} mislukt · ${runs.where((r) => r['status'] == 'CANCELLED').length} onderbroken',
            ),
            Text(
              'Doorvoer: ${_number(report['succeededPerHour'])} geslaagd/uur · mediaan ${_number(report['medianSeconds'])} sec · p95 ${_number(report['p95Seconds'])} sec',
            ),
            Text(
              '${phases.length} AI-jobs · $attempts attempts · $missing jobs met onbekend verbruik · API-equivalente waarde ${knownCosts == 0 ? 'onbekend' : '\$${cost.toStringAsFixed(2)}'} (geen rekening of resterend quotum)',
            ),
            Text(
              'Eerste doorgang: ${runs.take(questions).where((r) => r['status'] == 'SUCCEEDED').length} geslaagd · herhalingen: ${runs.skip(questions).where((r) => r['status'] == 'SUCCEEDED').length} geslaagd',
            ),
            Text(
              metrics.entries
                  .map((e) => '${e.key}: ${e.value.toStringAsFixed(0)}')
                  .join(' · '),
            ),
            const Text(
              'Cachemetingen volgen de runtime-teldefinitie. Ontbrekende cachecijfers zijn onbekend. Overlap kan ook ontstaan binnen één onderzoek.',
            ),
            const SizedBox(height: 16),
            Text(
              'Limietwaarnemingen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_rows(detail, 'limits').isEmpty)
              const Text('Nog geen providerlimiet waargenomen.'),
            for (final l in _rows(detail, 'limits'))
              SelectableText(
                '${l['recorded_at']} · ${l['observation']}\nTellerstand bij waarneming: ${l['counts']} · job ${l['job_id']} · attempt ${l['attempt_id'] ?? 'onbekend'}',
              ),
            const SizedBox(height: 16),
            Text(
              'Zoekopdrachten',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final r in runs.skip(_runPage * 25).take(25))
              ExpansionTile(
                title: Text(
                  '${r['ordinal']}. ${(r['question'] as Map<String, dynamic>)['question']}',
                ),
                subtitle: Text(
                  '${_status(r['status'])}${r['turn_error'] == null ? '' : ' · ${r['turn_error']}'}',
                ),
                trailing: widget.onNavigate == null
                    ? null
                    : IconButton(
                        tooltip: 'Resultaat bekijken',
                        icon: const Icon(Icons.article_outlined),
                        onPressed: () => widget.onNavigate!(
                          AdminPaths.capacityResult(
                            _selected!,
                            r['id'] as String,
                          ),
                        ),
                      ),
                children: [
                  if (widget.onNavigate != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => widget.onNavigate!(
                          AdminPaths.capacityResult(
                            _selected!,
                            r['id'] as String,
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Resultaat bekijken'),
                      ),
                    ),
                  for (final p in phases.where((p) => p['run_id'] == r['id']))
                    ListTile(
                      title: SelectableText(
                        '${p['phase_key']} · ${p['status']} · ${p['error_code'] ?? ''}',
                      ),
                      subtitle: SelectableText(
                        'Runtimejob: ${p['job_id'] ?? 'nog niet aangemaakt'}\n${p['error_message'] ?? ''}\nAttempts: ${p['attempts'] ?? 'onbekend'}',
                      ),
                    ),
                  SelectableText(
                    'Bronselectie en onderzoek: ${r['research_stats'] ?? 'nog niet afgerond'}',
                  ),
                ],
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _runPage > 0
                      ? () => setState(() => _runPage--)
                      : null,
                  child: const Text('Vorige'),
                ),
                Text('Pagina ${_runPage + 1}'),
                TextButton(
                  onPressed: (_runPage + 1) * 25 < runs.length
                      ? () => setState(() => _runPage++)
                      : null,
                  child: const Text('Volgende'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Tijdlijn', style: Theme.of(context).textTheme.titleMedium),
            for (final e in _rows(detail, 'events').reversed.take(100))
              Text('${e['created_at']} · ${e['message']}'),
          ],
        ),
      ),
    );
  }

  static String _number(dynamic value) =>
      value is num ? value.toStringAsFixed(1) : 'onbekend';

  String _csv(List<Map<String, dynamic>> runs) {
    String quote(dynamic v) => '"${'$v'.replaceAll('"', '""')}"';
    return [
      'ordinal,question,status,error,started,completed',
      ...runs.map(
        (r) => [
          r['ordinal'],
          (r['question'] as Map<String, dynamic>)['question'],
          r['status'],
          r['turn_error'] ?? '',
          r['started_at'],
          r['turn_completed_at'] ?? '',
        ].map(quote).join(','),
      ),
    ].join('\r\n');
  }

  Future<void> _export(String content) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Campagne-export'),
        content: SizedBox(
          width: 800,
          child: SingleChildScrollView(child: SelectableText(content)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
            },
            child: const Text('Kopiëren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }
}
