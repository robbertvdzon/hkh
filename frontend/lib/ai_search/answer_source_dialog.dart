import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../collection/collection_config.dart';
import '../collection/collection_search.dart';
import '../collection/img_embed/img_embed.dart';
import '../collection/pdf_source_preview.dart';
import '../theme/app_style.dart';
import 'answer_image_dialog.dart';
import 'source_preview/source_preview.dart';

/// Makes the existing collection client available in answers and source lists.
class AnswerSourceScope extends InheritedWidget {
  const AnswerSourceScope({
    required this.source,
    required super.child,
    super.key,
  });

  final CollectionSearchSource source;

  static CollectionSearchSource? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnswerSourceScope>()?.source;

  @override
  bool updateShouldNotify(AnswerSourceScope oldWidget) =>
      source != oldWidget.source;
}

/// Only genuine HKH record links may become requests to our collection API.
({String collection, String ident})? answerSourceRecord(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.userInfo.isNotEmpty) return null;
    if (uri.hasAuthority || uri.hasScheme) {
      final ownOrigin =
          const ['http', 'https'].contains(Uri.base.scheme) &&
          const ['http', 'https'].contains(uri.scheme) &&
          uri.origin == Uri.base.origin;
      final publicOrigin =
          uri.scheme == 'https' &&
          uri.host == 'hkh.vdzonsoftware.nl' &&
          uri.port == 443;
      if ((!ownOrigin && !publicOrigin) ||
          !const ['http', 'https'].contains(uri.scheme)) {
        return null;
      }
    }
    final route = uri.hasFragment ? Uri.parse(uri.fragment) : uri;
    if (route.hasAuthority || route.hasScheme) return null;
    final parts = route.pathSegments;
    final offset = parts.firstOrNull == 'zoeken' ? 1 : 0;
    if (parts.length != offset + 3 || parts[offset] != 'objecten') return null;
    final collection = parts[offset + 1], ident = parts[offset + 2];
    if (![
      ...collectionConfigs.map((config) => config.key),
      'transcripties',
    ].contains(collection)) {
      return null;
    }
    // The backend client currently interpolates identifiers in an API path.
    // Exclude path separators, extra URI syntax and nested percent encoding.
    if (ident.isEmpty ||
        ident == '.' ||
        ident == '..' ||
        RegExp(r'[/\\%?#\x00-\x1f]').hasMatch(ident)) {
      return null;
    }
    return (collection: collection, ident: ident);
  } on FormatException {
    return null;
  } on StateError {
    return null;
  }
}

Uri? _sourceUri(String url) {
  try {
    final uri = Uri.base.resolve(url);
    return const ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  } on FormatException {
    return null;
  }
}

Future<void> showAnswerSource(
  BuildContext context, {
  required String url,
  CollectionSearchSource? source,
}) => showDialog<void>(
  context: context,
  builder: (_) => AnswerSourceDialog(url: url, source: source),
);

class AnswerSourceDialog extends StatefulWidget {
  const AnswerSourceDialog({required this.url, this.source, super.key});

  final String url;
  final CollectionSearchSource? source;

  @override
  State<AnswerSourceDialog> createState() => _AnswerSourceDialogState();
}

class _AnswerSourceDialogState extends State<AnswerSourceDialog> {
  late final _record = answerSourceRecord(widget.url);
  late final _uri = _sourceUri(widget.url);
  Future<CollectionItemDetail>? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final record = _record, source = widget.source;
    if (record != null && source != null) {
      _detail = source.loadDetail(record.collection, record.ident);
    }
  }

  Future<void> _openFullPage() async {
    final uri = _uri;
    if (uri == null) return;
    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      // Keep the source and close control available after a browser failure.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('De pagina kon niet worden geopend.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: appPageTheme(context),
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          key: const Key('answer-source-dialog'),
          backgroundColor: appBackground,
          insetPadding: EdgeInsets.all(isNarrowLayout(context) ? 8 : 24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 920),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bron bekijken',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(color: appGreen),
                          ),
                        ),
                        IconButton(
                          key: const Key('answer-source-close'),
                          tooltip: 'Bron sluiten',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _body()),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('answer-source-open-page'),
                          onPressed: _uri == null ? null : _openFullPage,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open volledige pagina'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Sluiten'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _body() {
    if (_detail == null) {
      if (_record == null && _uri != null) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Wordt de bron niet getoond? Gebruik ‘Open volledige pagina’.',
                style: TextStyle(color: appMutedText),
              ),
            ),
            Expanded(child: buildSourcePreview(_uri.toString())),
          ],
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Deze bron kan hier niet worden weergegeven.'),
        ),
      );
    }
    return FutureBuilder<CollectionItemDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Deze bron kon niet worden geladen.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(_load),
                    child: const Text('Opnieuw proberen'),
                  ),
                ],
              ),
            ),
          );
        }
        return _SourceContent(detail: snapshot.requireData);
      },
    );
  }
}

class _SourceContent extends StatelessWidget {
  const _SourceContent({required this.detail});

  final CollectionItemDetail detail;

  @override
  Widget build(BuildContext context) {
    final config = collectionConfig(detail.collection);
    final title = collectionTitle(
      detail.title,
      detail.collection,
      detail.fields,
    );
    final documentText = detail.documentText?.trim().isNotEmpty == true
        ? detail.documentText!.trim()
        : detail.fields.entries
              .where(
                (entry) => documentFieldNames.any(
                  (name) => name.toLowerCase() == entry.key.toLowerCase(),
                ),
              )
              .map((entry) => entry.value)
              .where((value) => value.trim().isNotEmpty)
              .join('\n\n');
    final fields = {
      config.number: detail.ident,
      if (detail.year != null && detail.collection != 'bidprent')
        'Jaar': '${detail.year}',
      for (final entry in detail.fields.entries)
        if (entry.value.trim().isNotEmpty &&
            !documentFieldNames.any(
              (name) => name.toLowerCase() == entry.key.toLowerCase(),
            ))
          entry.key: entry.value,
    };
    return SelectionArea(
      child: ListView(
        key: const Key('answer-source-content'),
        padding: EdgeInsets.all(isNarrowLayout(context) ? 16 : 24),
        children: [
          Text(config.label, style: const TextStyle(color: appMutedText)),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'HkhSerif',
              color: appGreen,
            ),
          ),
          if (detail.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(detail.description),
          ],
          if (detail.imageUrl case final String imageUrl) ...[
            const SizedBox(height: 20),
            SelectionContainer.disabled(
              child: InkWell(
                mouseCursor: SystemMouseCursors.zoomIn,
                onTap: () => showAnswerImage(
                  context,
                  imageUrl: imageUrl,
                  description: title,
                ),
                child: SizedBox(
                  height: isNarrowLayout(context) ? 260 : 420,
                  child: buildNetworkImage(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Klik op de foto om te vergroten.',
              style: TextStyle(color: appMutedText),
            ),
          ],
          const SizedBox(height: 24),
          for (final entry in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: appMutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(entry.value),
                ],
              ),
            ),
          if (detail.pdfUrl case final String pdfUrl) ...[
            const SizedBox(height: 16),
            Text('Document', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            PdfSourcePreview(pdfUrl: pdfUrl, thumbnailUrl: detail.thumbnailUrl),
          ],
          if (documentText.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Documenttekst',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(documentText),
            const SizedBox(height: 8),
            const Text(
              'Herkende documenttekst kan fouten bevatten. Controleer de scan.',
              style: TextStyle(color: appMutedText),
            ),
          ],
        ],
      ),
    );
  }
}
