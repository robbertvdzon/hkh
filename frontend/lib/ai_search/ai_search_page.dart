import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../collection/img_embed/img_embed.dart';
import 'ai_search.dart';

class AiSearchPage extends StatefulWidget {
  const AiSearchPage({required this.source, this.initialQuestion, super.key});

  final AiSearchSource source;
  final String? initialQuestion;

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  late final TextEditingController _questionController = TextEditingController(
    text: widget.initialQuestion,
  );
  final ScrollController _scrollController = ScrollController();
  AiSearchSession? _session;
  Timer? _pollTimer;
  Timer? _clockTimer;
  DateTime? _activeSince;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final question = widget.initialQuestion?.trim() ?? '';
    if (question.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit([String? proposedQuestion]) async {
    final question = (proposedQuestion ?? _questionController.text).trim();
    if (question.length < 3 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = _session == null
          ? await widget.source.startAiSearch(question)
          : await widget.source.askFollowUp(_session!.id, question);
      if (!mounted) return;
      setState(() {
        _session = session;
        _submitting = false;
        _questionController.clear();
        _activeSince = DateTime.now();
      });
      _startPolling();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _poll();
  }

  Future<void> _poll() async {
    final sessionId = _session?.id;
    if (sessionId == null) return;
    try {
      final session = await widget.source.loadAiSearch(sessionId);
      if (!mounted) return;
      setState(() => _session = session);
      final isActive = session.turns.lastOrNull?.isActive ?? false;
      if (!isActive) {
        _pollTimer?.cancel();
        _clockTimer?.cancel();
        _activeSince = null;
      }
    } catch (_) {
      // Een tijdelijke pollfout beëindigt een lopend onderzoek niet.
    }
  }

  Future<void> _cancel() async {
    final sessionId = _session?.id;
    if (sessionId == null) return;
    final session = await widget.source.cancelAiSearch(sessionId);
    if (!mounted) return;
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    setState(() {
      _session = session;
      _activeSince = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Vraag het archief')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      if (session == null) const _Introduction(),
                      if (session != null)
                        for (final turn in session.turns) ...[
                          _QuestionCard(question: turn.question),
                          const SizedBox(height: 10),
                          _TurnCard(
                            turn: turn,
                            elapsed: turn.isActive ? _elapsedLabel() : null,
                            onCancel: turn.isActive ? _cancel : null,
                            onSuggestedQuestion: _submit,
                          ),
                          const SizedBox(height: 20),
                        ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _QuestionComposer(
                  controller: _questionController,
                  enabled:
                      !_submitting &&
                      !(session?.turns.lastOrNull?.isActive ?? false),
                  label: session == null
                      ? 'Stel je vraag'
                      : 'Stel een vervolgvraag',
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _elapsedLabel() {
    final elapsed = DateTime.now().difference(_activeSince ?? DateTime.now());
    if (elapsed.inSeconds < 15) return 'Net begonnen';
    if (elapsed.inMinutes < 1) return 'Al ${elapsed.inSeconds} seconden bezig';
    final seconds = elapsed.inSeconds % 60;
    return 'Al ${elapsed.inMinutes} min ${seconds.toString().padLeft(2, '0')} sec bezig';
  }
}

class _Introduction extends StatelessWidget {
  const _Introduction();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 54,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Stel een vrije vraag over historisch Heemskerk',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'De archiefonderzoeker doorzoekt de collecties, opent relevante bronnen en maakt een antwoord met controleerbare links en beschikbare afbeeldingen.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Bijvoorbeeld: Wat is er door de jaren heen gebeurd rond de Kerklaan?',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(question, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ),
  );
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turn,
    required this.elapsed,
    required this.onCancel,
    required this.onSuggestedQuestion,
  });

  final AiSearchTurn turn;
  final String? elapsed;
  final VoidCallback? onCancel;
  final ValueChanged<String> onSuggestedQuestion;

  @override
  Widget build(BuildContext context) {
    if (turn.isActive) {
      final progress = turn.progressPercent;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      turn.progressMessage ?? 'Het archiefonderzoek is bezig',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress == null ? null : progress / 100,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${elapsed ?? ''}${progress == null ? '' : ' · $progress%'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stoppen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (turn.status != 'SUCCEEDED') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  turn.errorMessage ??
                      'Het onderzoek kon niet worden afgerond.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (turn.title != null) ...[
              Text(
                turn.title!,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
            ],
            HtmlWidget(
              turn.answerHtml ?? '',
              customWidgetBuilder: (element) {
                if (element.localName != 'img') return null;
                final imageUrl = element.attributes['src'];
                if (imageUrl == null || imageUrl.isEmpty) return null;
                final linkUrl = element.parent?.localName == 'a'
                    ? element.parent?.attributes['href']
                    : null;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 640.0;
                    final height = (width * 0.72).clamp(220.0, 520.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildNetworkImage(
                            imageUrl,
                            fit: BoxFit.contain,
                            linkUrl: linkUrl,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              onTapUrl: (url) => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              textStyle: Theme.of(context).textTheme.bodyLarge,
            ),
            if (turn.suggestedFollowUps.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Misschien wil je ook weten:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final question in turn.suggestedFollowUps)
                    ActionChip(
                      label: Text(question),
                      onPressed: () => onSuggestedQuestion(question),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionComposer extends StatelessWidget {
  const _QuestionComposer({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 8,
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: label,
                hintText: 'Wat wil je weten?',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled ? onSubmit : null,
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Vraag stellen',
          ),
        ],
      ),
    ),
  );
}
