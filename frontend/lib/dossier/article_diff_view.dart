import 'package:flutter/material.dart';

import 'dossier.dart';
import 'dossier_format.dart';

/// Regelverschil tussen twee versies: groen toegevoegd, rood verwijderd, grijs gelijk.
class ArticleDiffView extends StatelessWidget {
  const ArticleDiffView({required this.diff, super.key});

  final ArticleDiff diff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changed = diff.lines.where((line) => line.type != 'EQUAL').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          changed == 0
              ? 'Geen verschillen tussen versie ${diff.fromVersion} en ${diff.toVersion}.'
              : 'Verschil van versie ${diff.fromVersion} naar versie ${diff.toVersion}: $changed gewijzigde regels.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in diff.lines) _DiffLineRow(line: line),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});
  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, marker) = switch (line.type) {
      'INSERT' => (
        Colors.green.withValues(alpha: 0.18),
        Colors.green.shade900,
        '+',
      ),
      'DELETE' => (
        Colors.red.withValues(alpha: 0.16),
        Colors.red.shade900,
        '-',
      ),
      _ => (Colors.transparent, theme.colorScheme.onSurfaceVariant, ' '),
    };
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Text(
        '$marker ${line.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: foreground,
        ),
      ),
    );
  }
}

/// Haalt een verschil op en toont het, met laad- en foutstatus.
class ArticleDiffLoader extends StatefulWidget {
  const ArticleDiffLoader({
    required this.source,
    required this.articleId,
    required this.versionNumber,
    required this.against,
    super.key,
  });

  final DossierSource source;
  final String articleId;

  /// De versie waar het verschil naartoe loopt.
  final int versionNumber;

  /// De versie waar het verschil van uitgaat.
  final int against;

  @override
  State<ArticleDiffLoader> createState() => _ArticleDiffLoaderState();
}

class _ArticleDiffLoaderState extends State<ArticleDiffLoader> {
  late Future<ArticleDiff> _future = _load();

  Future<ArticleDiff> _load() => widget.source.loadDiff(
    widget.articleId,
    versionNumber: widget.versionNumber,
    against: widget.against,
  );

  @override
  void didUpdateWidget(covariant ArticleDiffLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.versionNumber != widget.versionNumber ||
        oldWidget.against != widget.against) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ArticleDiff>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text(
          errorText(snapshot.error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      }
      final diff = snapshot.data;
      if (diff == null) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ArticleDiffView(diff: diff);
    },
  );
}
