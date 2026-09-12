import 'package:flutter/material.dart';

import 'article_page.dart';
import 'dossier.dart';
import 'dossier_format.dart';

/// Tabblad Artikelen: lijst plus knoppen om een artikel te maken of te laten schrijven.
class ArticlesTab extends StatelessWidget {
  const ArticlesTab({
    required this.source,
    required this.detail,
    required this.onChanged,
    super.key,
  });

  final DossierSource source;
  final DossierDetail detail;

  /// Wordt aangeroepen als de lijst opnieuw geladen moet worden.
  final Future<void> Function() onChanged;

  Future<void> _open(BuildContext context, String articleId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticlePage(source: source, articleId: articleId),
      ),
    );
    await onChanged();
  }

  Future<void> _create(BuildContext context) async {
    final input = await showDialog<_ArticleInput>(
      context: context,
      builder: (_) => const _ArticleDialog(generate: false),
    );
    if (input == null || !context.mounted) return;
    try {
      final article = await source.createArticle(
        detail.id,
        title: input.title,
        contentMarkdown: input.text,
      );
      if (context.mounted) await _open(context, article.id);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _generate(BuildContext context) async {
    final input = await showDialog<_ArticleInput>(
      context: context,
      builder: (_) => const _ArticleDialog(generate: true),
    );
    if (input == null || !context.mounted) return;
    try {
      final article = await source.generateArticle(
        detail.id,
        title: input.title,
        instruction: input.text,
      );
      if (context.mounted) await _open(context, article.id);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = detail.role.canEdit;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canEdit) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nieuw artikel'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _generate(context),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Laat AI schrijven'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (detail.articles.isEmpty)
              InfoCard(
                icon: Icons.article_outlined,
                text: canEdit
                    ? 'Nog geen artikelen. Schrijf er zelf een of laat de AI een eerste versie schrijven op basis van het doel, de feitenlijst en de antwoorden in dit dossier.'
                    : 'Dit dossier heeft nog geen artikelen.',
              ),
            for (final article in detail.articles) ...[
              _ArticleCard(
                article: article,
                onOpen: () => _open(context, article.id),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onOpen});

  final ArticleSummary article;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proposal = article.proposalState;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.article_outlined, color: theme.colorScheme.primary),
        title: Text(article.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Versie ${article.currentVersionNumber}'),
              Text('Gewijzigd ${formatDateTime(article.updatedAt)}'),
              if (proposal == 'READY')
                Chip(
                  label: const Text('AI-voorstel klaar'),
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  visualDensity: VisualDensity.compact,
                )
              else if (proposal == 'RUNNING')
                Chip(
                  avatar: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: const Text('AI schrijft…'),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}

class _ArticleInput {
  const _ArticleInput({required this.title, required this.text});
  final String title;
  final String text;
}

/// Dialoog voor "Nieuw artikel" (titel + optionele eigen tekst) of "Laat AI schrijven"
/// (titel + opdracht).
class _ArticleDialog extends StatefulWidget {
  const _ArticleDialog({required this.generate});
  final bool generate;

  @override
  State<_ArticleDialog> createState() => _ArticleDialogState();
}

class _ArticleDialogState extends State<_ArticleDialog> {
  final _title = TextEditingController();
  final _text = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final text = _text.text.trim();
    if (title.isEmpty) return;
    if (widget.generate && text.length < 3) return;
    Navigator.pop(context, _ArticleInput(title: title, text: text));
  }

  @override
  Widget build(BuildContext context) {
    final generate = widget.generate;
    return AlertDialog(
      title: Text(generate ? 'Laat AI schrijven' : 'Nieuw artikel'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 200,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: generate ? 3 : 6,
              maxLines: 14,
              style: generate
                  ? null
                  : const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                labelText: generate
                    ? 'Opdracht voor de AI'
                    : 'Tekst (optioneel)',
                hintText: generate
                    ? 'Bijv. Schrijf een artikel van circa 800 woorden over de bewoners van de Kerklaan.'
                    : 'Markdown; bronnen als [naam](hkh:collection/ident). Leeg laten mag.',
                helperText: generate
                    ? 'De AI schrijft versie 1 als voorstel op basis van het doel, de feitenlijst en de antwoorden.'
                    : null,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
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
          onPressed: _submit,
          child: Text(generate ? 'Laten schrijven' : 'Aanmaken'),
        ),
      ],
    );
  }
}
