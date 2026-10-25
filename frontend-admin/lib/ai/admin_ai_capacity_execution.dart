import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../auth/admin_session.dart';
import '../shell/admin_router.dart';
import 'admin_ai_capacity.dart';
import 'capacity_metrics.dart';

class AdminAiCapacityExecutionPage extends StatefulWidget {
  const AdminAiCapacityExecutionPage({
    required this.identity,
    required this.source,
    required this.campaignId,
    required this.runId,
    required this.onNavigate,
    super.key,
  });
  final AdminIdentity identity;
  final AdminAiCapacitySource source;
  final String campaignId, runId;
  final void Function(String) onNavigate;
  @override
  State<AdminAiCapacityExecutionPage> createState() => _State();
}

class _State extends State<AdminAiCapacityExecutionPage> {
  Map<String, dynamic>? _data;
  String? _error;
  Timer? _poll;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (![
        'SUCCEEDED',
        'FAILED',
        'CANCELLED',
      ].contains((_data?['run'] as Map?)?['status'])) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = await widget.source.execution(
        widget.identity,
        widget.campaignId,
        widget.runId,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Uitvoeringsdetails laden mislukt.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data, run = data?['run'] as Map<String, dynamic>?;
    final metrics = CapacityMetrics(
      CapacityMetrics.rows(data?['phases']),
      CapacityMetrics.rows(data?['limits']),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Uitvoeringsdetails',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Verversen',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (data == null && _loading) const LinearProgressIndicator(),
        if (run != null) ...[
          Text('${run['campaign_name']} · zoekopdracht ${run['ordinal']}'),
          const SizedBox(height: 12),
          SelectableText(
            '${(run['question'] as Map)['question']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => widget.onNavigate(
                AdminPaths.capacityResult(widget.campaignId, widget.runId),
              ),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Resultaat bekijken'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${metrics.runsLabel} AI-runs · fouten: ${metrics.errorsLabel('${run['status']}')} · providerlimiet: ${metrics.limitLabel}',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                for (final label in [
                  'AI-run',
                  'Stap',
                  'Status',
                  'Start',
                  'Einde',
                  'Duur',
                  'Herpogingen',
                  'Fouten',
                  'Limiet',
                ])
                  DataColumn(label: Text(label)),
              ],
              rows: [
                for (final (index, key) in metrics.keys.indexed)
                  _row(index, key, metrics.phase(key)),
              ],
            ),
          ),
          const Text(
            'Duur is de som van gemeten uitvoeringstijd van de pogingen. Wachttijd tussen pogingen telt mee in de totale tijd van de zoekopdracht.',
          ),
          const SizedBox(height: 24),
          Text(
            'Fouten en limieten',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (run['status'] == 'FAILED')
            Text(
              '${run['turn_error'] ?? run['error_message'] ?? 'Deze zoekopdracht is mislukt.'}',
            ),
          if (metrics.errors == 0 &&
              metrics.limits.isEmpty &&
              run['status'] != 'FAILED')
            const Text('Geen fouten of providerlimieten waargenomen.'),
          for (final p in metrics.phases.where(
            (p) => p['error_message'] != null,
          ))
            ListTile(
              title: Text(CapacityMetrics.phaseName('${p['phase_key']}')),
              subtitle: Text('${p['error_message']}'),
            ),
          for (final a in metrics.attempts.where((a) => a['errorCode'] != null))
            ListTile(
              title: const Text('Mislukte poging'),
              subtitle: Text(
                '${a['errorCode']} · ${CapacityMetrics.date(a['completedAt'])}',
              ),
            ),
          for (final l in metrics.limits)
            ListTile(
              title: Text(
                (l['observation'] as Map?)?['blocked'] == false
                    ? 'Providerwaarschuwing (niet geblokkeerd)'
                    : CapacityMetrics([], [l]).limitLabel,
              ),
              subtitle: Text(
                'Waargenomen: ${CapacityMetrics.date((l['observation'] as Map?)?['observedAt'])}${(l['observation'] as Map?)?['resetsAt'] == null ? '' : ' · Reset: ${CapacityMetrics.date((l['observation'] as Map)['resetsAt'])}'}',
              ),
            ),
          const SizedBox(height: 24),
          ExpansionTile(
            key: const Key('capacity-technical-details'),
            title: const Text('Technische details'),
            subtitle: const Text(
              'Tokens, caching, kosten, runtime-ID’s en ruwe gegevens',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kosten zijn API-equivalent, geen resterend quotum. Ontbrekende verbruikscijfers zijn onbekend.',
                    ),
                    for (final p in metrics.phases)
                      ListTile(
                        title: SelectableText(
                          'Runtimejob: ${p['job_id'] ?? 'nog niet aangemaakt'}',
                        ),
                        subtitle: SelectableText(
                          'Fase: ${p['phase_key']} · generatie ${p['generation']}',
                        ),
                      ),
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(data),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  DataRow _row(int index, String key, CapacityMetrics m) {
    final status = m.phases.lastOrNull?['status'];
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(CapacityMetrics.phaseName(key))),
        DataCell(Text(CapacityMetrics.status(status))),
        DataCell(Text(CapacityMetrics.date(m.start?.toIso8601String()))),
        DataCell(
          Text(
            m.end == null
                ? (m.active ? 'Bezig' : 'Onbekend')
                : CapacityMetrics.date(m.end!.toIso8601String()),
          ),
        ),
        DataCell(Text(CapacityMetrics.duration(m.executionDuration))),
        DataCell(Text('${m.retries}')),
        DataCell(Text(m.errorsLabel('$status'))),
        DataCell(Text(m.limitLabel)),
      ],
    );
  }
}
