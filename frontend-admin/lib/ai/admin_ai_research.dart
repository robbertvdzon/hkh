import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/admin_session.dart';

/// Eén beurt in het vergelijkingsoverzicht.
class AiTurnComparison {
  const AiTurnComparison({
    required this.id,
    required this.question,
    required this.title,
    required this.status,
    required this.depth,
    required this.method,
    required this.createdAt,
    required this.durationSeconds,
    required this.rounds,
    required this.sourceCount,
    required this.models,
    required this.jobs,
    required this.inputTokens,
    required this.outputTokens,
    required this.askedBy,
    required this.benchmarkQuestionId,
    required this.errorMessage,
    this.costUsd,
  });

  factory AiTurnComparison.fromJson(Map<String, dynamic> json) =>
      AiTurnComparison(
        id: json['id'] as String? ?? '',
        question: json['question'] as String? ?? '',
        title: json['title'] as String?,
        status: json['status'] as String? ?? '',
        depth: json['depth'] as String? ?? '',
        method: json['method'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        rounds: (json['rounds'] as num?)?.toInt() ?? 0,
        sourceCount: (json['sourceCount'] as num?)?.toInt() ?? 0,
        models: (json['models'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        jobs: (json['jobs'] as num?)?.toInt() ?? 0,
        inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
        costUsd: (json['costUsd'] as num?)?.toDouble(),
        askedBy: json['askedBy'] as String?,
        benchmarkQuestionId: (json['benchmarkQuestionId'] as num?)?.toInt(),
        errorMessage: json['errorMessage'] as String?,
      );

  final String id;
  final String question;
  final String? title;
  final String status;
  final String depth;
  final String method;
  final DateTime? createdAt;
  final int durationSeconds;
  final int rounds;
  final int sourceCount;
  final List<String> models;
  final int jobs;
  final int inputTokens;
  final int outputTokens;

  /// API-equivalente kosten in USD volgens de runtime; null als onbekend.
  final double? costUsd;
  final String? askedBy;
  final int? benchmarkQuestionId;
  final String? errorMessage;
}

class AiBenchmarkQuestion {
  const AiBenchmarkQuestion({
    required this.id,
    required this.question,
    required this.depth,
  });

  factory AiBenchmarkQuestion.fromJson(Map<String, dynamic> json) =>
      AiBenchmarkQuestion(
        id: (json['id'] as num).toInt(),
        question: json['question'] as String? ?? '',
        depth: json['depth'] as String? ?? 'FAST',
      );

  final int id;
  final String question;
  final String depth;
}

class AiBenchmarkState {
  const AiBenchmarkState({required this.questions, required this.running});

  factory AiBenchmarkState.fromJson(Map<String, dynamic> json) =>
      AiBenchmarkState(
        questions: (json['questions'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  AiBenchmarkQuestion.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        running: json['running'] as bool? ?? false,
      );

  final List<AiBenchmarkQuestion> questions;
  final bool running;
}

abstract interface class AdminAiResearchSource {
  Future<List<AiTurnComparison>> turns(AdminIdentity identity, {int limit});
  Future<AiBenchmarkState> benchmark(AdminIdentity identity);
  Future<AiBenchmarkState> addQuestion(
    AdminIdentity identity,
    String question,
    String depth,
  );
  Future<AiBenchmarkState> deleteQuestion(AdminIdentity identity, int id);
  Future<AiBenchmarkState> runBenchmark(AdminIdentity identity);
}

class AdminAiResearchClient implements AdminAiResearchSource {
  AdminAiResearchClient(this.apiBaseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$apiBaseUrl/api/admin/ai-search/$path');

  @override
  Future<List<AiTurnComparison>> turns(
    AdminIdentity identity, {
    int limit = 40,
  }) async {
    final response = await _client
        .get(_uri('turns?limit=$limit'), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20));
    _check(response, 'Overzicht laden mislukt');
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => AiTurnComparison.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<AiBenchmarkState> benchmark(AdminIdentity identity) async => _state(
    await _client
        .get(_uri('benchmark'), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20)),
    'Testset laden mislukt',
  );

  @override
  Future<AiBenchmarkState> addQuestion(
    AdminIdentity identity,
    String question,
    String depth,
  ) async => _state(
    await _client
        .post(
          _uri('benchmark'),
          headers: {
            ...identity.requestHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'question': question, 'depth': depth}),
        )
        .timeout(const Duration(seconds: 20)),
    'Vraag toevoegen mislukt',
  );

  @override
  Future<AiBenchmarkState> deleteQuestion(
    AdminIdentity identity,
    int id,
  ) async => _state(
    await _client
        .delete(_uri('benchmark/$id'), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20)),
    'Vraag verwijderen mislukt',
  );

  @override
  Future<AiBenchmarkState> runBenchmark(AdminIdentity identity) async => _state(
    await _client
        .post(_uri('benchmark/run'), headers: identity.requestHeaders)
        .timeout(const Duration(seconds: 20)),
    'Testset starten mislukt',
  );

  AiBenchmarkState _state(http.Response response, String failure) {
    _check(response, failure);
    return AiBenchmarkState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _check(http.Response response, String failure) {
    if (response.statusCode != 200) {
      String? detail;
      try {
        detail =
            (jsonDecode(response.body) as Map<String, dynamic>)['message']
                as String?;
      } catch (_) {}
      throw StateError(
        '$failure (${response.statusCode})${detail == null ? '' : ': $detail'}',
      );
    }
  }
}

/// Vergelijkingsoverzicht van onderzoeken en beheer van de testset.
class AdminAiResearchSection extends StatefulWidget {
  const AdminAiResearchSection({
    required this.identity,
    required this.source,
    super.key,
  });

  final AdminIdentity identity;
  final AdminAiResearchSource source;

  @override
  State<AdminAiResearchSection> createState() => _AdminAiResearchSectionState();
}

class _AdminAiResearchSectionState extends State<AdminAiResearchSection> {
  List<AiTurnComparison> _turns = const [];
  AiBenchmarkState? _benchmark;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;
  String _depth = 'FAST';
  final _question = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final turns = await widget.source.turns(widget.identity);
      final benchmark = await widget.source.benchmark(widget.identity);
      if (!mounted) return;
      setState(() {
        _turns = turns;
        _benchmark = benchmark;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is StateError
            ? error.message
            : 'Overzicht kon niet worden geladen.';
      });
    }
  }

  Future<void> _apply(
    Future<AiBenchmarkState> Function() action,
    String message,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final state = await action();
      if (!mounted) return;
      setState(() {
        _benchmark = state;
        _message = message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is StateError ? error.message : 'Actie mislukt.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final benchmark = _benchmark;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-onderzoek: vergelijken',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('ai-research-refresh'),
                  tooltip: 'Verversen',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Recente onderzoeken met methode, modellen, duur, rondes, bronnen, tokens en '
              'kosten (API-equivalent volgens de runtime; via het abonnement geen factuur, wel '
              'de maat om modellen te vergelijken). '
              'De testset stelt vaste vragen opnieuw met de nu ingestelde methode en modellen, '
              'één voor één; de antwoorden verschijnen hieronder.',
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text('Testset', style: theme.textTheme.titleSmall),
              if (benchmark != null && benchmark.questions.isEmpty)
                const Text('Nog geen vragen.', style: TextStyle(fontSize: 12)),
              if (benchmark != null)
                for (final question in benchmark.questions)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_depthLabel(question.depth)} · ${question.question}',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        key: Key('benchmark-delete-${question.id}'),
                        tooltip: 'Verwijderen',
                        onPressed: _busy
                            ? null
                            : () => _apply(
                                () => widget.source.deleteQuestion(
                                  widget.identity,
                                  question.id,
                                ),
                                'Vraag verwijderd.',
                              ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('benchmark-question'),
                controller: _question,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nieuwe testvraag',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    key: const Key('benchmark-depth'),
                    value: _depth,
                    items: const [
                      DropdownMenuItem(value: 'FAST', child: Text('Snel')),
                      DropdownMenuItem(
                        value: 'EXTENDED',
                        child: Text('Doorzoeken'),
                      ),
                      DropdownMenuItem(
                        value: 'THOROUGH',
                        child: Text('Uitgebreid'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _depth = value ?? 'FAST'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('benchmark-add'),
                    onPressed: _busy
                        ? null
                        : () {
                            final text = _question.text.trim();
                            if (text.length < 3) return;
                            _apply(() async {
                              final state = await widget.source.addQuestion(
                                widget.identity,
                                text,
                                _depth,
                              );
                              _question.clear();
                              return state;
                            }, 'Vraag toegevoegd.');
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Toevoegen'),
                  ),
                  FilledButton.icon(
                    key: const Key('benchmark-run'),
                    onPressed:
                        _busy ||
                            benchmark == null ||
                            benchmark.questions.isEmpty ||
                            benchmark.running
                        ? null
                        : () => _apply(
                            () => widget.source.runBenchmark(widget.identity),
                            'De testset is gestart; ververs het overzicht voor de voortgang.',
                          ),
                    icon: benchmark?.running ?? false
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      benchmark?.running ?? false
                          ? 'Testset draait…'
                          : 'Testset draaien',
                    ),
                  ),
                ],
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!, key: const Key('ai-research-message')),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              Text('Recente onderzoeken', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              if (_turns.isEmpty)
                const Text(
                  'Nog geen onderzoeken.',
                  style: TextStyle(fontSize: 12),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    key: const Key('ai-research-table'),
                    columnSpacing: 16,
                    headingTextStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    dataTextStyle: const TextStyle(fontSize: 12),
                    columns: const [
                      DataColumn(label: Text('Wanneer')),
                      DataColumn(label: Text('Vraag')),
                      DataColumn(label: Text('Methode')),
                      DataColumn(label: Text('Diepte')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Duur')),
                      DataColumn(label: Text('Rondes')),
                      DataColumn(label: Text('Bronnen')),
                      DataColumn(label: Text('Modellen')),
                      DataColumn(label: Text('Tokens in/uit')),
                      DataColumn(label: Text('Kosten')),
                      DataColumn(label: Text('Door')),
                    ],
                    rows: [
                      for (final turn in _turns)
                        DataRow(
                          cells: [
                            DataCell(Text(_when(turn.createdAt))),
                            DataCell(
                              Tooltip(
                                message: turn.question,
                                child: SizedBox(
                                  width: 260,
                                  child: Text(
                                    turn.title ?? turn.question,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${turn.method == 'PIPELINE' ? 'pijplijn' : 'agent'}'
                                '${turn.benchmarkQuestionId != null ? ' (testset)' : ''}',
                              ),
                            ),
                            DataCell(Text(_depthLabel(turn.depth))),
                            DataCell(
                              Tooltip(
                                message: turn.errorMessage ?? '',
                                child: Text(_statusLabel(turn.status)),
                              ),
                            ),
                            DataCell(Text(_duration(turn.durationSeconds))),
                            DataCell(Text('${turn.rounds}')),
                            DataCell(Text('${turn.sourceCount}')),
                            DataCell(
                              Text(
                                turn.models
                                    .map((m) => m.split('/').last)
                                    .join(', '),
                              ),
                            ),
                            DataCell(
                              Text(
                                turn.jobs == 0
                                    ? '–'
                                    : '${_thousands(turn.inputTokens)} / ${_thousands(turn.outputTokens)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                turn.costUsd == null
                                    ? '–'
                                    : '\$${turn.costUsd!.toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(Text(turn.askedBy ?? '')),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _depthLabel(String depth) => switch (depth) {
    'EXTENDED' => 'doorzoeken',
    'THOROUGH' => 'uitgebreid',
    _ => 'snel',
  };

  static String _statusLabel(String status) => switch (status) {
    'SUCCEEDED' => 'afgerond',
    'FAILED' => 'mislukt',
    'CANCELLED' => 'gestopt',
    'RUNNING' => 'bezig',
    'QUEUED' => 'wacht',
    _ => status.toLowerCase(),
  };

  static String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return minutes == 0 ? '$rest s' : '$minutes min $rest s';
  }

  static String _thousands(int value) =>
      value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value';

  static String _when(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}-${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
