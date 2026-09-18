import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_style.dart';
import '../ai_search/ai_search.dart';
import '../ai_search/answer_pdf_saver.dart';
import '../collection/img_embed/img_embed.dart';
import '../navigation.dart';
import 'article_history_page.dart';
import 'article_proposal_card.dart';
import 'dossier.dart';
import 'dossier_format.dart';

enum _ArticleMenuItem { history, exportPdf, delete }

/// Eén artikel: gerenderde huidige versie, open AI-voorstel, editor en geschiedenis.
class ArticlePage extends StatefulWidget {
  const ArticlePage({
    required this.source,
    required this.articleId,
    AnswerPdfSaver? pdfSaver,
    super.key,
  }) : pdfSaver = pdfSaver ?? saveAnswerPdf;

  final DossierSource source;
  final String articleId;

  /// Biedt de PDF aan de gebruiker aan: downloaden op web, delen/opslaan op Android.
  /// Standaard het platformgedrag van het AI-antwoordscherm, in tests een fake.
  final AnswerPdfSaver pdfSaver;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  static const _pollInterval = Duration(seconds: 3);

  ArticleDetail? _article;
  String? _error;
  Timer? _pollTimer;
  bool _editing = false;
  bool _saving = false;
  bool _exporting = false;
  TextEditingController? _titleController;
  TextEditingController? _contentController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _titleController?.dispose();
    _contentController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final article = await widget.source.loadArticle(widget.articleId);
      if (!mounted) return;
      _apply(article);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
      _stopPolling();
    }
  }

  void _apply(ArticleDetail article) {
    setState(() {
      _article = article;
      _error = null;
    });
    if (article.proposal?.jobActive ?? false) {
      _pollTimer ??= Timer.periodic(_pollInterval, (_) => _load());
    } else {
      _stopPolling();
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _run(Future<ArticleDetail> Function() action) async {
    try {
      _apply(await action());
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  void _startEditing() {
    final article = _article!;
    _titleController?.dispose();
    _contentController?.dispose();
    setState(() {
      _titleController = TextEditingController(text: article.title);
      _contentController = TextEditingController(
        text: article.current.contentMarkdown,
      );
      _editing = true;
    });
  }

  void _cancelEditing() => setState(() => _editing = false);

  Future<void> _save() async {
    final article = _article!;
    final title = _titleController!.text.trim();
    if (title.isEmpty) {
      showError(context, 'Vul een titel in.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.source.saveArticle(
        article.id,
        title: title,
        contentMarkdown: _contentController!.text,
        basedOnVersionId: article.current.id,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      _apply(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, error);
      // Bij een verouderde basis (409) laat de melding zien wie er tussendoor heeft
      // opgeslagen; de nieuwste versie wordt herladen en de editor blijft open.
      await _load();
    }
  }

  Future<void> _proposeChange() async {
    final article = _article!;
    final instruction = await showDialog<String>(
      context: context,
      builder: (_) => const _InstructionDialog(),
    );
    if (instruction == null || !mounted) return;
    await _run(
      () => widget.source.proposeChange(
        article.id,
        instruction: instruction,
        basedOnVersionId: article.current.id,
      ),
    );
  }

  /// Eén exportpad voor web en Android: dezelfde aanroep, dezelfde foutafhandeling.
  /// Het artikel blijft staan; er wordt nooit een leeg of onvolledig bestand aangeboden.
  Future<void> _exportPdf() async {
    final article = _article;
    if (article == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await widget.source.exportArticlePdf(
        article.dossierId,
        article.id,
      );
      if (bytes.isEmpty) throw StateError('Lege PDF');
      await widget.pdfSaver(_pdfFileName(article.id), bytes);
      if (!mounted) return;
      setState(() => _exporting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF-export mislukt. Probeer het opnieuw.'),
          action: SnackBarAction(label: 'Opnieuw', onPressed: _exportPdf),
        ),
      );
    }
  }

  Future<void> _openHistory() async {
    final restored = await openAppPage<bool>(
      context,
      '/artikelen/${Uri.encodeComponent(widget.articleId)}/geschiedenis',
      () => ArticleHistoryPage(source: widget.source, article: _article!),
    );
    if (restored == true && mounted) await _load();
  }

  Future<void> _delete() async {
    final article = _article!;
    final ok = await confirm(
      context,
      title: 'Artikel verwijderen?',
      message:
          'Het artikel "${article.title}" wordt met alle versies definitief verwijderd.',
    );
    if (!ok || !mounted) return;
    try {
      await widget.source.deleteArticle(article.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    final canEdit = article?.role.canEdit ?? false;
    return Scaffold(
      appBar: HkhAppBar(
        context: context,
        title: Text(article?.title ?? 'Artikel'),
        actions: [
          if (article != null && !_editing)
            PopupMenuButton<_ArticleMenuItem>(
              tooltip: 'Artikelmenu',
              onSelected: (item) => switch (item) {
                _ArticleMenuItem.history => _openHistory(),
                _ArticleMenuItem.exportPdf => _exportPdf(),
                _ArticleMenuItem.delete => _delete(),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _ArticleMenuItem.history,
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Geschiedenis'),
                  ),
                ),
                const PopupMenuItem(
                  value: _ArticleMenuItem.exportPdf,
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Exporteren als PDF'),
                  ),
                ),
                if (canEdit)
                  const PopupMenuItem(
                    value: _ArticleMenuItem.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Artikel verwijderen'),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: article == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                  )
                : _editing
                ? _buildEditor(context)
                : _buildViewer(context, article, canEdit),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer(
    BuildContext context,
    ArticleDetail article,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final current = article.current;
    final hasProposal = article.proposal != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasProposal) ...[
          ArticleProposalCard(
            source: widget.source,
            article: article,
            canEdit: canEdit,
            onAccept: () => _run(
              () => widget.source.acceptProposal(
                article.id,
                article.proposal!.id,
              ),
            ),
            onReject: () => _run(
              () => widget.source.rejectProposal(
                article.id,
                article.proposal!.id,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Versie ${current.versionNumber} · '
          '${current.isAi ? 'AI' : (current.authorEmail ?? 'onbekend')} · '
          '${formatDateTime(current.createdAt)}'
          '${article.dossierTitle.isEmpty ? '' : ' · dossier ${article.dossierTitle}'}',
          style: theme.textTheme.bodySmall,
        ),
        if (canEdit) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Bewerken'),
              ),
              FilledButton.tonalIcon(
                onPressed: hasProposal ? null : _proposeChange,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Vraag AI om een wijziging'),
              ),
              TextButton.icon(
                onPressed: _openHistory,
                icon: const Icon(Icons.history),
                label: const Text('Geschiedenis'),
              ),
            ],
          ),
          if (hasProposal)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Beoordeel eerst het open AI-voorstel voordat je een nieuwe wijziging vraagt.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: current.contentMarkdown.trim().isEmpty
                ? Text(
                    'Dit artikel is nog leeg.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : RenderedHtml(current.contentHtml),
          ),
        ),
        if (current.unknownSources.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Onbekende bronnen (niet gevonden in het archief): '
                      '${current.unknownSources.join(', ')}. Deze zijn als gewone tekst weergegeven.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (current.sources.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Bronnen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final source in current.sources) _SourceTile(source: source),
        ],
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Schrijf in Markdown. Een archiefbron schrijf je als [naam](hkh:collection/ident), '
          'bijvoorbeeld [Kerklaan 12](hkh:beeldbank/12345). Onbekende bronnen worden als gewone tekst getoond.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Titel',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contentController,
          minLines: 18,
          maxLines: 60,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Inhoud',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Opslaan'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _saving ? null : _cancelEditing,
              child: const Text('Annuleren'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});
  final ArticleSource source;

  @override
  Widget build(BuildContext context) {
    final imageUrl = source.imageUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: imageUrl == null
              ? const Icon(Icons.description_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: buildNetworkImage(imageUrl, fit: BoxFit.cover),
                ),
        ),
        title: Text(
          source.title.isEmpty ? source.ref : source.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(source.ref),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: source.detailUrl.isEmpty
            ? null
            : () => launchUrl(
                Uri.parse(source.detailUrl),
                mode: LaunchMode.externalApplication,
              ),
      ),
    );
  }
}

/// Dialoog "Vraag AI om een wijziging".
class _InstructionDialog extends StatefulWidget {
  const _InstructionDialog();

  @override
  State<_InstructionDialog> createState() => _InstructionDialogState();
}

class _InstructionDialogState extends State<_InstructionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < 3) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Vraag AI om een wijziging'),
    content: SizedBox(
      width: 520,
      child: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 10,
        maxLength: 4000,
        decoration: const InputDecoration(
          labelText: 'Opdracht',
          hintText:
              'Bijv. Voeg een hoofdstuk toe over de school en noem alle bewoners van nummer 12.',
          helperText:
              'De AI maakt een voorstel dat je eerst kunt bekijken en dan accepteert of verwerpt.',
          helperMaxLines: 3,
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuleren'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Voorstel vragen')),
    ],
  );
}

/// Bestandsnaam `artikel-<id>.pdf`, ontdaan van tekens die in bestandsnamen
/// ongeldig zijn.
String _pdfFileName(String articleId) =>
    'artikel-${articleId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')}.pdf';
