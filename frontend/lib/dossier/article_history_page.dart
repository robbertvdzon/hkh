import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'article_diff_view.dart';
import 'dossier.dart';
import 'dossier_format.dart';

/// Geschiedenis van een artikel: alle versies, met verschil ten opzichte van de huidige
/// versie en de mogelijkheid om terug te zetten.
class ArticleHistoryPage extends StatefulWidget {
  const ArticleHistoryPage({
    required this.source,
    required this.article,
    super.key,
  });

  final DossierSource source;
  final ArticleDetail article;

  @override
  State<ArticleHistoryPage> createState() => _ArticleHistoryPageState();
}

class _ArticleHistoryPageState extends State<ArticleHistoryPage> {
  List<VersionSummary>? _versions;
  String? _error;
  int? _selected;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final versions = await widget.source.listVersions(widget.article.id);
      if (!mounted) return;
      setState(() {
        _versions = versions.toList()
          ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    }
  }

  Future<void> _restore(VersionSummary version) async {
    final ok = await confirm(
      context,
      title: 'Versie ${version.versionNumber} terugzetten?',
      message:
          'De inhoud van versie ${version.versionNumber} wordt als nieuwe versie opgeslagen en wordt de huidige versie. De geschiedenis blijft bewaard.',
      confirmLabel: 'Terugzetten',
    );
    if (!ok || !mounted) return;
    try {
      await widget.source.restoreVersion(
        widget.article.id,
        version.versionNumber,
      );
      if (!mounted) return;
      _restored = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Versie ${version.versionNumber} is teruggezet.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final versions = _versions;
    final current = widget.article.current.versionNumber;
    final canEdit = widget.article.role.canEdit;
    return Scaffold(
      appBar: HkhAppBar(context: context, title: const Text('Geschiedenis')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: versions == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Text(_error!),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        widget.article.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tik op een versie om het verschil met de huidige versie ($current) te zien.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final version in versions) ...[
                        _VersionCard(
                          version: version,
                          selected: _selected == version.versionNumber,
                          currentVersion: current,
                          onTap: () => setState(
                            () => _selected = _selected == version.versionNumber
                                ? null
                                : version.versionNumber,
                          ),
                          onRestore:
                              canEdit &&
                                  !version.isCurrent &&
                                  version.state != 'PROPOSED' &&
                                  !_restored
                              ? () => _restore(version)
                              : null,
                          diff:
                              _selected == version.versionNumber &&
                                  version.versionNumber != current
                              ? ArticleDiffLoader(
                                  source: widget.source,
                                  articleId: widget.article.id,
                                  versionNumber: version.versionNumber,
                                  against: current,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.version,
    required this.selected,
    required this.currentVersion,
    required this.onTap,
    required this.onRestore,
    required this.diff,
  });

  final VersionSummary version;
  final bool selected;
  final int currentVersion;
  final VoidCallback onTap;
  final VoidCallback? onRestore;
  final Widget? diff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (stateLabel, stateColor) = switch (version.state) {
      'PROPOSED' => ('Voorstel', colorScheme.tertiaryContainer),
      'REJECTED' => ('Verworpen', colorScheme.errorContainer),
      _ => ('Geaccepteerd', colorScheme.secondaryContainer),
    };
    final author = version.isAi
        ? 'AI'
        : (version.authorEmail ?? 'Onbekende gebruiker');
    return Card(
      clipBehavior: Clip.antiAlias,
      color: version.isCurrent
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    version.isAi ? Icons.auto_awesome : Icons.person_outline,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Versie ${version.versionNumber}${version.isCurrent ? ' (huidig)' : ''}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(stateLabel),
                    backgroundColor: stateColor,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$author · ${formatDateTime(version.createdAt)}'
                '${version.basedOnVersionNumber == null ? '' : ' · op basis van versie ${version.basedOnVersionNumber}'}',
                style: theme.textTheme.bodySmall,
              ),
              if (version.changeSummary != null &&
                  version.changeSummary!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(version.changeSummary!),
              ],
              if (version.errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  version.errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              if (version.aiInstruction != null &&
                  version.aiInstruction!.trim().isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('AI-opdracht', style: theme.textTheme.bodySmall),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(version.aiInstruction!),
                      ),
                    ),
                  ],
                ),
              if (onRestore != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Terugzetten'),
                  ),
                ),
              ],
              if (selected && diff != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Wat er verandert als je van de huidige versie ($currentVersion) naar versie ${version.versionNumber} gaat:',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                diff!,
              ] else if (selected && version.isCurrent)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Dit is de huidige versie.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
