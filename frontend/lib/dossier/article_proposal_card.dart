import 'package:flutter/material.dart';

import 'article_diff_view.dart';
import 'dossier.dart';

/// Kaart bovenaan het artikel met het open AI-voorstel: lopend, mislukt of klaar.
class ArticleProposalCard extends StatefulWidget {
  const ArticleProposalCard({
    required this.source,
    required this.article,
    required this.canEdit,
    required this.onAccept,
    required this.onReject,
    super.key,
  });

  final DossierSource source;
  final ArticleDetail article;
  final bool canEdit;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  @override
  State<ArticleProposalCard> createState() => _ArticleProposalCardState();
}

class _ArticleProposalCardState extends State<ArticleProposalCard> {
  bool _showDiff = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.article.proposal!;
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'AI-voorstel (versie ${proposal.versionNumber})',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (proposal.jobActive)
              _Running(
                message: proposal.progressMessage,
                onStop: widget.canEdit && !_busy
                    ? () => _run(widget.onReject)
                    : null,
              )
            else if (proposal.jobFailed)
              _Failed(
                message: proposal.errorMessage,
                onDismiss: widget.canEdit && !_busy
                    ? () => _run(widget.onReject)
                    : null,
              )
            else
              _Ready(
                proposal: proposal,
                showDiff: _showDiff,
                onToggleDiff: () => setState(() => _showDiff = !_showDiff),
                onAccept: widget.canEdit && !_busy
                    ? () => _run(widget.onAccept)
                    : null,
                onReject: widget.canEdit && !_busy
                    ? () => _run(widget.onReject)
                    : null,
              ),
            if (_showDiff && !proposal.jobActive && !proposal.jobFailed) ...[
              const SizedBox(height: 12),
              ArticleDiffLoader(
                source: widget.source,
                articleId: widget.article.id,
                versionNumber: proposal.versionNumber,
                against: widget.article.current.versionNumber,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.message, required this.onStop});
  final String? message;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(message ?? 'De AI schrijft aan het voorstel…')),
      if (onStop != null)
        TextButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Stoppen'),
        ),
    ],
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onDismiss});
  final String? message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message ?? 'Het AI-voorstel kon niet worden gemaakt.'),
        ),
        if (onDismiss != null)
          TextButton(onPressed: onDismiss, child: const Text('Verwerpen')),
      ],
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.proposal,
    required this.showDiff,
    required this.onToggleDiff,
    required this.onAccept,
    required this.onReject,
  });

  final ArticleVersion proposal;
  final bool showDiff;
  final VoidCallback onToggleDiff;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (proposal.changeSummary != null &&
            proposal.changeSummary!.trim().isNotEmpty)
          Text(proposal.changeSummary!),
        if (proposal.aiInstruction != null &&
            proposal.aiInstruction!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Opdracht: ${proposal.aiInstruction}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (proposal.unknownSources.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Onbekende bronnen in dit voorstel: ${proposal.unknownSources.join(', ')}',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onToggleDiff,
              icon: Icon(showDiff ? Icons.visibility_off : Icons.difference),
              label: Text(showDiff ? 'Verschil verbergen' : 'Bekijk verschil'),
            ),
            if (onAccept != null)
              FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check),
                label: const Text('Accepteren'),
              ),
            if (onReject != null)
              TextButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close),
                label: const Text('Verwerpen'),
              ),
          ],
        ),
      ],
    );
  }
}
