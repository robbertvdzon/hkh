import 'package:flutter/material.dart';

import '../theme/app_style.dart';
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
    final horizontal = isNarrowLayout(context) ? 16.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
          children: [
            if (canEdit) ...[
              Wrap(
                key: const Key('article-actions'),
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nieuw artikel'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _generate(context),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Laat AI schrijven'),
                  ),
                ],
              ),
              const SizedBox(height: appSectionGap),
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
              const SizedBox(height: 16),
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
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: appMutedText);
    return AppCard(
      key: Key('article-card-${article.id}'),
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.article_outlined, color: appGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: appGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Versie ${article.currentVersionNumber}',
                      style: metaStyle,
                    ),
                    Text(
                      'Gewijzigd ${formatDateTime(article.updatedAt)}',
                      style: metaStyle,
                    ),
                    if (proposal == 'READY')
                      const _ArticleChip(
                        label: 'AI-voorstel klaar',
                        background: appRoleResearcherBackground,
                      )
                    else if (proposal == 'RUNNING')
                      const _ArticleChip(
                        label: 'AI schrijft…',
                        background: appAccentBackground,
                        busy: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: appMutedText),
        ],
      ),
    );
  }
}

/// Statuschip bij een artikel, in de gedeelde vormgeving.
class _ArticleChip extends StatelessWidget {
  const _ArticleChip({
    required this.label,
    required this.background,
    this.busy = false,
  });

  final String label;
  final Color background;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(appControlRadius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: appGreen),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: appGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
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
    return AppDialog(
      title: generate ? 'Laat AI schrijven' : 'Nieuw artikel',
      maxWidth: 520,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 200,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Titel'),
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
              labelText: generate ? 'Opdracht voor de AI' : 'Tekst (optioneel)',
              hintText: generate
                  ? 'Bijv. Schrijf een artikel van circa 800 woorden over de bewoners van de Kerklaan.'
                  : 'Markdown; bronnen als [naam](hkh:collection/ident). Leeg laten mag.',
              helperText: generate
                  ? 'De AI schrijft versie 1 als voorstel op basis van het doel, de feitenlijst en de antwoorden.'
                  : null,
              alignLabelWithHint: true,
            ),
          ),
        ],
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
