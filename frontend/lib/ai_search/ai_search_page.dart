import '../theme/app_style.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'answer_html.dart';
import 'answer_share_dialog.dart';
import 'answer_sharing.dart';
import 'ai_search.dart';
import 'ai_question_card.dart';
import 'answer_pdf_saver.dart';

/// Zet een afgeronde anonieme zoekopdracht in een dossier. Geeft de titel van het gekozen
/// dossier terug, of null als de gebruiker annuleert.
typedef AdoptSearchHandler =
    Future<String?> Function(BuildContext context, String sessionId);

class AiSearchPage extends StatefulWidget {
  const AiSearchPage({
    required this.source,
    this.initialQuestion,
    this.initialSessionId,
    this.title,
    this.overviewTitle = 'Mijn zoekopdrachten',
    this.emptyMessage = 'Je hebt in deze browser nog geen AI-zoekopdrachten.',
    this.introduction,
    this.embedded = false,
    this.canAsk = true,
    this.readOnlyMessage =
        'Je kunt in dit dossier meelezen, maar geen vragen stellen.',
    this.onAdopt,
    this.pdfSource,
    AnswerPdfSaver? pdfSaver,
    super.key,
  }) : pdfSaver = pdfSaver ?? saveAnswerPdf;

  final AiSearchSource source;
  final String? initialQuestion;
  final String? initialSessionId;

  /// Titel in de AppBar; standaard 'Vraag het archief'.
  final String? title;

  /// Kop boven de lijst met zoekopdrachten.
  final String overviewTitle;

  /// Tekst als er nog geen zoekopdrachten zijn.
  final String emptyMessage;

  /// Vervangt de standaardintroductie boven het overzicht.
  final Widget? introduction;

  /// Zonder eigen Scaffold en AppBar, voor gebruik in een tabblad.
  final bool embedded;

  /// Of de gebruiker vragen mag stellen en zoekopdrachten mag verwijderen.
  final bool canAsk;

  /// Melding in plaats van het invoerveld als [canAsk] false is.
  final String readOnlyMessage;

  /// Actie "In dossier zetten" per afgeronde zoekopdracht; alleen zichtbaar als gezet.
  final AdoptSearchHandler? onAdopt;

  /// Haalt het geladen antwoord op als PDF; zonder bron is er geen exportactie.
  final AiAnswerPdfSource? pdfSource;

  /// Biedt de PDF aan de gebruiker aan; standaard het platformgedrag, in tests een fake.
  final AnswerPdfSaver pdfSaver;

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  late final TextEditingController _questionController = TextEditingController(
    text: widget.initialQuestion,
  );
  final ScrollController _scrollController = ScrollController();
  AiSearchSession? _session;
  List<AiSearchSummary>? _searches;
  Timer? _pollTimer;
  bool _submitting = false;
  bool _loadingSearches = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final question = widget.initialQuestion?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialSessionId != null) {
        _openSearch(widget.initialSessionId!);
      } else if (question.isNotEmpty) {
        _submit();
      } else {
        _loadSearches(showLoading: true);
        _startOverviewPolling();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AiSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSessionId != oldWidget.initialSessionId &&
        widget.initialSessionId != _session?.id) {
      if (widget.initialSessionId case final id?) {
        _openSearch(id);
      } else {
        _showOverview();
      }
    }
  }

  void _syncLocation(String? id) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = router.routeInformationProvider.value.uri;
    if (uri.path != '/vragen' && !uri.path.startsWith('/dossiers/')) return;
    final key = widget.embedded ? 'vraag' : 'id';
    final params = Map<String, String>.of(uri.queryParameters)..remove(key);
    if (id != null) params[key] = id;
    final location = uri.replace(queryParameters: params).toString();
    if (location != uri.toString()) router.replace(location);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
      });
      _syncLocation(session.id);
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
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    final sessionId = _session?.id;
    if (sessionId == null) return;
    try {
      final session = await widget.source.loadAiSearch(sessionId);
      if (!mounted || _session?.id != sessionId) return;
      setState(() => _session = session);
      final isActive = session.turns.lastOrNull?.isActive ?? false;
      if (!isActive) {
        _pollTimer?.cancel();
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
    setState(() => _session = session);
  }

  Future<void> _loadSearches({bool showLoading = false}) async {
    if (showLoading && mounted) setState(() => _loadingSearches = true);
    try {
      final searches = await widget.source.listAiSearches();
      if (!mounted || _session != null) return;
      setState(() {
        _searches = searches;
        _loadingSearches = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || _session != null) return;
      setState(() {
        _loadingSearches = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _startOverviewPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadSearches(),
    );
  }

  Future<void> _showOverview() async {
    _pollTimer?.cancel();
    setState(() {
      _session = null;
      _error = null;
    });
    _questionController.clear();
    _syncLocation(null);
    _scrollToTop();
    await _loadSearches(showLoading: _searches == null);
    if (mounted && _session == null) _startOverviewPolling();
  }

  Future<void> _openSearch(String sessionId) async {
    _pollTimer?.cancel();
    setState(() => _error = null);
    try {
      final session = await widget.source.loadAiSearch(sessionId);
      if (!mounted) return;
      setState(() => _session = session);
      _syncLocation(session.id);
      _scrollToTop();
      if (session.turns.lastOrNull?.isActive ?? false) _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
      _startOverviewPolling();
    }
  }

  Future<void> _deleteSearch(AiSearchSummary search) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zoekopdracht verwijderen?'),
        content: Text(
          search.isActive
              ? 'Deze zoekopdracht loopt nog. Het onderzoek wordt gestopt en het resultaat wordt verwijderd.'
              : 'De vraag, het antwoord en de vervolgvragen worden verwijderd.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.source.deleteAiSearch(search.id);
      await _loadSearches();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _adoptSearch(AiSearchSummary search) async {
    final handler = widget.onAdopt;
    if (handler == null) return;
    try {
      final dossierTitle = await handler(context, search.id);
      if (!mounted || dossierTitle == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zoekopdracht toegevoegd aan dossier "$dossierTitle".'),
        ),
      );
      await _loadSearches();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  /// Het antwoord dat op dit moment op het scherm staat: het laatste geslaagde
  /// antwoord van de open zoekopdracht. Null zolang er niets te exporteren valt.
  AiSearchTurn? get _exportableAnswer {
    if (widget.pdfSource == null) return null;
    final turns = _session?.turns;
    if (turns == null) return null;
    for (final turn in turns.reversed) {
      if (turn.status == 'SUCCEEDED' &&
          (turn.answerHtml?.isNotEmpty ?? false)) {
        return turn;
      }
    }
    return null;
  }

  Future<void> _exportPdf(String answerId) async {
    final source = widget.pdfSource;
    if (source == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await source.exportAnswerPdf(answerId);
      await widget.pdfSaver(_pdfFileName(answerId), bytes);
      if (!mounted) return;
      setState(() => _exporting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      // Het antwoord blijft staan; alleen de melding met "Opnieuw" komt erbij.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF-export mislukt. Probeer het opnieuw.'),
          action: SnackBarAction(
            label: 'Opnieuw',
            onPressed: () => _exportPdf(answerId),
          ),
        ),
      );
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _scrollController.jumpTo(0);
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
    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              if (widget.embedded && session != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: TextButton.icon(
                      onPressed: _showOverview,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(widget.overviewTitle),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    if (session == null) ...[
                      if (widget.embedded)
                        widget.introduction ?? const _Introduction()
                      else if (widget.canAsk)
                        AiQuestionCard(
                          controller: _questionController,
                          enabled: !_submitting,
                          onSubmit: _submit,
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.overviewTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (_loadingSearches)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          else if (widget.embedded)
                            IconButton(
                              onPressed: () => _loadSearches(showLoading: true),
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Vernieuwen',
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!_loadingSearches && (_searches?.isEmpty ?? true))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(widget.emptyMessage),
                          ),
                        ),
                      for (final search in _searches ?? const []) ...[
                        _SearchSummaryCard(
                          search: search,
                          onOpen: () => _openSearch(search.id),
                          onDelete: widget.canAsk
                              ? () => _deleteSearch(search)
                              : null,
                          onAdopt:
                              widget.onAdopt != null &&
                                  search.status == 'SUCCEEDED'
                              ? () => _adoptSearch(search)
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (session != null)
                      for (final turn in session.turns) ...[
                        _QuestionCard(question: turn.question),
                        const SizedBox(height: 10),
                        _TurnCard(
                          turn: turn,
                          elapsed: _turnDurationLabel(turn),
                          onShare:
                              turn.status == 'SUCCEEDED' &&
                                  shareSourceFor(widget.source) != null
                              ? () => showAnswerShareDialog(
                                  context,
                                  shareSourceFor(widget.source)!,
                                  turn,
                                )
                              : null,
                          onCancel: turn.isActive && widget.canAsk
                              ? _cancel
                              : null,
                          onSuggestedQuestion: widget.canAsk ? _submit : null,
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
              if (widget.canAsk && (session != null || widget.embedded))
                _QuestionComposer(
                  controller: _questionController,
                  enabled:
                      !_submitting &&
                      !(session?.turns.lastOrNull?.isActive ?? false),
                  label: session == null
                      ? 'Start een nieuwe zoekopdracht'
                      : 'Stel een vervolgvraag',
                  onSubmit: _submit,
                )
              else if (!widget.canAsk)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.readOnlyMessage,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: HkhAppBar(
        context: context,
        title: Text(widget.title ?? 'Vraag het archief'),
        onBack: session != null ? _showOverview : null,
        backLabel: 'Terug naar Vraag het archief',
        actions: [
          if (session != null)
            IconButton(
              onPressed: _showOverview,
              icon: const Icon(Icons.history),
              tooltip: widget.overviewTitle,
            ),
          if (_exportableAnswer case final answer?)
            IconButton(
              onPressed: _exporting ? null : () => _exportPdf(answer.id),
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.picture_as_pdf),
              tooltip: 'Exporteer als PDF',
            ),
          if (session == null)
            IconButton(
              onPressed: () => _loadSearches(showLoading: true),
              icon: const Icon(Icons.refresh),
              tooltip: 'Vernieuwen',
            ),
        ],
      ),
      body: body,
    );
  }

  String _turnDurationLabel(AiSearchTurn turn) {
    if (turn.isActive) {
      return 'Al ${_formatDuration(turn.durationSeconds)} bezig';
    }
    final prefix = switch (turn.status) {
      'CANCELLED' => 'Gestopt na',
      'FAILED' => 'Mislukt na',
      _ => 'Afgerond in',
    };
    return '$prefix ${_formatDuration(turn.durationSeconds)}';
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
          'Iedere vraag wordt een aparte zoekopdracht. De archiefonderzoeker doorzoekt de collecties, opent relevante bronnen en maakt een antwoord met controleerbare links en beschikbare afbeeldingen.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.schedule),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Een uitgebreid onderzoek duurt vaak enkele minuten. Je mag deze pagina of tab sluiten: de opdracht blijft in de backend doorlopen en staat later weer in dit overzicht.',
                  ),
                ),
              ],
            ),
          ),
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

class _SearchSummaryCard extends StatelessWidget {
  const _SearchSummaryCard({
    required this.search,
    required this.onOpen,
    required this.onDelete,
    this.onAdopt,
  });

  final AiSearchSummary search;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onAdopt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusLabel = switch (search.status) {
      'SUBMITTING' || 'QUEUED' || 'RUNNING' => 'Bezig',
      'SUCCEEDED' => 'Afgerond',
      'CANCELLED' => 'Gestopt',
      _ => 'Mislukt',
    };
    final statusColor = search.isActive
        ? colorScheme.primaryContainer
        : search.status == 'SUCCEEDED'
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  search.isActive ? Icons.manage_search : Icons.history,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      search.title ?? search.question,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (search.title != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        search.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(statusLabel),
                          backgroundColor: statusColor,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(_formatDate(search.createdAt)),
                        Text(
                          search.isActive
                              ? '${_formatDuration(search.durationSeconds)} bezig'
                              : 'Duur: ${_formatDuration(search.durationSeconds)}',
                        ),
                        if (search.turnCount > 1)
                          Text('${search.turnCount} vragen'),
                      ],
                    ),
                    if (search.isActive && search.progressMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${search.progressMessage}${search.progressPercent == null ? '' : ' · ${search.progressPercent}%'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onAdopt != null)
                IconButton(
                  onPressed: onAdopt,
                  icon: const Icon(Icons.folder_open_outlined),
                  tooltip: 'In dossier zetten',
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Zoekopdracht verwijderen',
                ),
            ],
          ),
        ),
      ),
    );
  }
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
        child: SelectionArea(
          child: Text(question, style: Theme.of(context).textTheme.bodyLarge),
        ),
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
    this.onShare,
  });

  final AiSearchTurn turn;
  final String? elapsed;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onSuggestedQuestion;
  final VoidCallback? onShare;

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
                  if (onCancel != null)
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Stoppen'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Dit kan enkele minuten duren. Je kunt deze pagina sluiten; de zoekopdracht blijft doorlopen en verschijnt bij Mijn zoekopdrachten.',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              const SizedBox(height: 8),
              Text(elapsed ?? ''),
            ],
          ),
        ),
      );
    }
    return Card(
      child: SelectionArea(
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
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 7),
                  Text(elapsed ?? ''),
                ],
              ),
              if (onShare != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Antwoord delen'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AnswerHtml(turn.answerHtml ?? ''),
              if (turn.suggestedFollowUps.isNotEmpty &&
                  onSuggestedQuestion != null) ...[
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
                        onPressed: () => onSuggestedQuestion!(question),
                      ),
                  ],
                ),
              ],
            ],
          ),
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

/// Bestandsnaam `antwoord-<id>.pdf`, ontdaan van tekens die in bestandsnamen
/// ongeldig zijn.
String _pdfFileName(String answerId) =>
    'antwoord-${answerId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')}.pdf';

String _formatDuration(int totalSeconds) {
  final seconds = totalSeconds.clamp(0, 24 * 60 * 60 * 365);
  if (seconds < 60) return '$seconds sec';
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes < 60) {
    return '$minutes min ${remainingSeconds.toString().padLeft(2, '0')} sec';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours uur ${remainingMinutes.toString().padLeft(2, '0')} min';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (sameDay) return 'Vandaag $time';
  return '${local.day}-${local.month}-${local.year} $time';
}
